import 'dart:async';
import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/constants/api_constants.dart';
import '../../../tuya_device/data/services/emergency_trigger_service.dart';
import '../models/smartwatch_device_model.dart';
import '../models/smartwatch_event_model.dart';
import 'ble_smartwatch_service.dart';
import 'huawei_wear_service.dart';
import 'smartwatch_service.dart';

class SmartwatchManager {
  final Dio dio;
  final SharedPreferences prefs;
  final BleSmartwatchService bleService;
  final HuaweiWearService huaweiService;
  final EmergencyTriggerService emergencyTriggerService;

  final ValueNotifier<SmartwatchDeviceModel?> activeDevice = ValueNotifier(null);
  final ValueNotifier<int?> liveHeartRate = ValueNotifier(null);
  final ValueNotifier<bool> isConnecting = ValueNotifier(false);
  final ValueNotifier<List<SmartwatchDeviceModel>> pairedDevices = ValueNotifier([]);

  StreamSubscription? _bleEventSub;
  StreamSubscription? _huaweiEventSub;
  StreamSubscription? _bleHrSub;
  StreamSubscription? _huaweiHrSub;

  Function(SmartwatchEventModel)? onSosDetected;
  Function(bool success, SmartwatchEventModel event)? onEmergencySent;
  Function(String error)? onEmergencyError;

  static const String _prefKeyActiveDevice = 'active_smartwatch_device';

  SmartwatchManager({
    required this.dio,
    required this.prefs,
    required this.bleService,
    required this.huaweiService,
    required this.emergencyTriggerService,
  });

  Future<void> init() async {
    _loadCachedDevice();
    _setupListeners();
    await fetchPairedDevicesFromBackend();

    // Auto-connect to active device if cached
    if (activeDevice.value != null) {
      connectDevice(activeDevice.value!);
    }
  }

  void _loadCachedDevice() {
    final raw = prefs.getString(_prefKeyActiveDevice);
    if (raw != null && raw.isNotEmpty) {
      try {
        final map = jsonDecode(raw) as Map<String, dynamic>;
        activeDevice.value = SmartwatchDeviceModel.fromJson(map);
      } catch (e) {
        debugPrint('Error loading cached smartwatch: $e');
      }
    }
  }

  void _setupListeners() {
    _bleHrSub = bleService.heartRateStream.listen((bpm) {
      liveHeartRate.value = bpm;
    });

    _huaweiHrSub = huaweiService.heartRateStream.listen((bpm) {
      liveHeartRate.value = bpm;
    });

    _bleEventSub = bleService.eventStream.listen(_handleIncomingEvent);
    _huaweiEventSub = huaweiService.eventStream.listen(_handleIncomingEvent);
  }

  Future<void> _handleIncomingEvent(SmartwatchEventModel event) async {
    debugPrint('Smartwatch Event Received: ${event.eventType} from ${event.deviceId}');

    if (event.isEmergency) {
      onSosDetected?.call(event);
      try {
        final success = await emergencyTriggerService.triggerSmartwatchEmergency(
          event,
          smartwatchDevice: activeDevice.value,
        );

        onEmergencySent?.call(success, event);

        // Kirim getaran konfirmasi balik ke jam tangan
        if (success) {
          final service = _getServiceForBrand(activeDevice.value?.brand);
          await service.sendFeedbackAlert(
            event.deviceId,
            title: 'SOS Terkirim',
            message: 'Relawan sedang menuju lokasi Anda',
          );
        }
      } catch (e) {
        debugPrint('Failed to trigger smartwatch emergency: $e');
        onEmergencyError?.call(e.toString());
      }
    }
  }

  SmartwatchService _getServiceForBrand(String? brand) {
    if (brand?.toLowerCase() == 'huawei') {
      return huaweiService;
    }
    return bleService;
  }

  Future<List<SmartwatchDeviceModel>> fetchPairedDevicesFromBackend() async {
    final token = prefs.getString('auth_token');
    if (token == null || token.isEmpty) return [];

    try {
      final response = await dio.get(
        ApiConstants.smartwatchList,
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );

      if (response.statusCode == 200 && response.data['data'] is List) {
        final list = (response.data['data'] as List)
            .map((e) => SmartwatchDeviceModel.fromJson(e as Map<String, dynamic>))
            .toList();
        pairedDevices.value = list;
        return list;
      }
    } catch (e) {
      debugPrint('Error fetching paired smartwatches from backend: $e');
    }
    return pairedDevices.value;
  }

  Future<bool> pairAndConnectDevice(SmartwatchDeviceModel device) async {
    isConnecting.value = true;
    try {
      // 1. Simpan ke Backend
      final token = prefs.getString('auth_token');
      if (token != null && token.isNotEmpty) {
        await dio.post(
          ApiConstants.smartwatchRegister,
          data: device.toJson(),
          options: Options(headers: {'Authorization': 'Bearer $token'}),
        );
      }

      // 2. Simpan lokal
      await prefs.setString(_prefKeyActiveDevice, jsonEncode(device.toJson()));

      // 3. Sambungkan via service
      final connected = await connectDevice(device);
      await fetchPairedDevicesFromBackend();
      return connected;
    } catch (e) {
      debugPrint('Error pairing device: $e');
      return false;
    } finally {
      isConnecting.value = false;
    }
  }

  Future<bool> connectDevice(SmartwatchDeviceModel device) async {
    isConnecting.value = true;
    try {
      final service = _getServiceForBrand(device.brand);
      final ok = await service.connect(device);
      if (ok) {
        activeDevice.value = device.copyWith(isConnected: true);
        await prefs.setString(
          _prefKeyActiveDevice,
          jsonEncode(activeDevice.value!.toJson()),
        );
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('Error connecting device: $e');
      return false;
    } finally {
      isConnecting.value = false;
    }
  }

  Future<void> disconnectCurrentDevice() async {
    if (activeDevice.value == null) return;
    final dev = activeDevice.value!;
    final service = _getServiceForBrand(dev.brand);
    await service.disconnect(dev.id);
    activeDevice.value = dev.copyWith(isConnected: false);
    liveHeartRate.value = null;
  }

  Future<void> unpairDevice(String deviceId) async {
    await disconnectCurrentDevice();
    await prefs.remove(_prefKeyActiveDevice);
    activeDevice.value = null;

    final token = prefs.getString('auth_token');
    if (token != null && token.isNotEmpty) {
      try {
        final dev = pairedDevices.value.firstWhere((e) => e.id == deviceId);
        await dio.delete(
          ApiConstants.smartwatchDetail(dev.id),
          options: Options(headers: {'Authorization': 'Bearer $token'}),
        );
      } catch (_) {}
    }

    await fetchPairedDevicesFromBackend();
  }

  Future<void> syncTelemetryToBackend({int? battery, int? heartRate}) async {
    if (activeDevice.value == null) return;
    final token = prefs.getString('auth_token');
    if (token == null || token.isEmpty) return;

    try {
      await dio.post(
        ApiConstants.smartwatchTelemetry(activeDevice.value!.id),
        data: {
          'battery_level': battery,
          'heart_rate': heartRate,
        },
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
    } catch (e) {
      debugPrint('Error syncing smartwatch telemetry: $e');
    }
  }

  void simulateTestSos() {
    if (activeDevice.value != null) {
      bleService.simulateWatchSosTrigger(activeDevice.value!.id);
    }
  }

  void simulateTestFall() {
    if (activeDevice.value != null) {
      bleService.simulateFallDetection(activeDevice.value!.id);
    }
  }

  Future<void> dispose() async {
    await _bleEventSub?.cancel();
    await _huaweiEventSub?.cancel();
    await _bleHrSub?.cancel();
    await _huaweiHrSub?.cancel();
  }
}
