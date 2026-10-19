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
  final ValueNotifier<String?> connectingDeviceId = ValueNotifier(null);
  final ValueNotifier<List<SmartwatchDeviceModel>> pairedDevices = ValueNotifier([]);
  final ValueNotifier<String?> connectionStatus = ValueNotifier(null);

  StreamSubscription? _bleEventSub;
  StreamSubscription? _huaweiEventSub;
  StreamSubscription? _bleHrSub;
  StreamSubscription? _huaweiHrSub;
  Timer? _telemetrySyncTimer;

  Function(SmartwatchEventModel)? onSosDetected;
  Function(bool success, SmartwatchEventModel event)? onEmergencySent;
  Function(String error)? onEmergencyError;

  static const String _prefKeyActiveDevice = 'active_smartwatch_device';
  static const Duration _telemetrySyncInterval = Duration(minutes: 5);

  bool _initialized = false;
  bool _huaweiSupported = false;

  SmartwatchManager({
    required this.dio,
    required this.prefs,
    required this.bleService,
    required this.huaweiService,
    required this.emergencyTriggerService,
  });

  Future<void> init() async {
    if (_initialized) return;

    try {
      _huaweiSupported = await huaweiService.isSupported();
    } catch (_) {
      _huaweiSupported = false;
    }

    _loadCachedDevice();
    _setupListeners();
    await fetchPairedDevicesFromBackend();

    // Auto-connect to active device if cached
    if (activeDevice.value != null) {
      connectDevice(activeDevice.value!);
    }

    // Start periodic telemetry sync
    _startTelemetrySync();

    _initialized = true;
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
    _bleHrSub?.cancel();
    _huaweiHrSub?.cancel();
    _bleEventSub?.cancel();
    _huaweiEventSub?.cancel();

    _bleHrSub = bleService.heartRateStream.listen((bpm) {
      if (bpm > 0) {
        liveHeartRate.value = bpm;
      } else {
        // bpm == 0 means disconnected/unavailable
        liveHeartRate.value = null;
      }
    });

    _huaweiHrSub = huaweiService.heartRateStream.listen((bpm) {
      liveHeartRate.value = bpm;
    });

    _bleEventSub = bleService.eventStream.listen(_handleIncomingEvent);
    _huaweiEventSub = huaweiService.eventStream.listen(_handleIncomingEvent);

    // Monitor BLE connection state changes
    bleService.connectionState.addListener(_onBleConnectionStateChanged);
  }

  void _onBleConnectionStateChanged() {
    final isConnected = bleService.connectionState.value;
    final dev = activeDevice.value;

    if (dev != null && dev.brand.toLowerCase() != 'huawei') {
      if (isConnected && !dev.isConnected) {
        activeDevice.value = dev.copyWith(isConnected: true);
        connectionStatus.value = 'Terhubung & Siaga';
        debugPrint('✅ Smartwatch reconnected: ${dev.name}');
      } else if (!isConnected && dev.isConnected) {
        activeDevice.value = dev.copyWith(isConnected: false);
        liveHeartRate.value = null;
        connectionStatus.value = 'Terputus — mencoba menyambung ulang...';
        debugPrint('⚠️ Smartwatch disconnected: ${dev.name}');
      }
    }
  }

  /// Periodic sync data telemetry (BPM & baterai) ke backend
  void _startTelemetrySync() {
    _telemetrySyncTimer?.cancel();
    _telemetrySyncTimer = Timer.periodic(_telemetrySyncInterval, (_) {
      _syncCurrentTelemetry();
    });
  }

  Future<void> _syncCurrentTelemetry() async {
    if (activeDevice.value == null) return;
    final bpm = liveHeartRate.value;
    final battery = bleService.currentBattery;
    if (bpm == null && battery == null) return;

    await syncTelemetryToBackend(battery: battery, heartRate: bpm);
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

          // Sync telemetry setelah emergency
          _syncCurrentTelemetry();
        }
      } catch (e) {
        debugPrint('Failed to trigger smartwatch emergency: $e');
        onEmergencyError?.call(e.toString());
      }
    }
  }

  SmartwatchService _getServiceForBrand(String? brand) {
    if (brand?.toLowerCase() == 'huawei' && _huaweiSupported) {
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
    connectingDeviceId.value = device.id;
    connectionStatus.value = 'Menyimpan perangkat...';
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
      connectionStatus.value = 'Menghubungkan via Bluetooth...';
      final connected = await connectDevice(device);
      await fetchPairedDevicesFromBackend();
      return connected;
    } catch (e) {
      debugPrint('Error pairing device: $e');
      connectionStatus.value = 'Gagal menyimpan perangkat';
      return false;
    } finally {
      isConnecting.value = false;
      connectingDeviceId.value = null;
    }
  }

  Future<bool> connectDevice(SmartwatchDeviceModel device) async {
    isConnecting.value = true;
    connectingDeviceId.value = device.id;
    connectionStatus.value = 'Menghubungkan ke ${device.name}...';
    try {
      final service = _getServiceForBrand(device.brand);
      final ok = await service.connect(device);
      if (ok) {
        activeDevice.value = device.copyWith(isConnected: true);
        connectionStatus.value = 'Terhubung & Siaga';
        await prefs.setString(
          _prefKeyActiveDevice,
          jsonEncode(activeDevice.value!.toJson()),
        );

        // Update list pairedDevices agar isConnected langsung sinkron di UI
        final updatedList = pairedDevices.value.map((d) {
          if (d.id == device.id) {
            return d.copyWith(isConnected: true);
          } else {
            return d.copyWith(isConnected: false);
          }
        }).toList();
        pairedDevices.value = updatedList;

        // Sync telemetry segera setelah connect
        Future.delayed(const Duration(seconds: 3), () => _syncCurrentTelemetry());

        return true;
      }
      connectionStatus.value = 'Gagal terhubung';
      return false;
    } catch (e) {
      debugPrint('Error connecting device: $e');
      connectionStatus.value = 'Error: $e';
      return false;
    } finally {
      isConnecting.value = false;
      connectingDeviceId.value = null;
    }
  }

  Future<void> disconnectCurrentDevice() async {
    if (activeDevice.value == null) return;
    final dev = activeDevice.value!;
    final service = _getServiceForBrand(dev.brand);
    await service.disconnect(dev.id);
    activeDevice.value = dev.copyWith(isConnected: false);
    liveHeartRate.value = null;
    connectionStatus.value = 'Terputus';

    final updatedList = pairedDevices.value.map((d) {
      if (d.id == dev.id) {
        return d.copyWith(isConnected: false);
      }
      return d;
    }).toList();
    pairedDevices.value = updatedList;
  }

  Future<void> unpairDevice(String deviceId) async {
    await disconnectCurrentDevice();
    await prefs.remove(_prefKeyActiveDevice);
    activeDevice.value = null;
    connectionStatus.value = null;

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
      debugPrint('📡 Telemetry synced: HR=$heartRate, Battery=$battery');
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
    _telemetrySyncTimer?.cancel();
    bleService.connectionState.removeListener(_onBleConnectionStateChanged);
    await _bleEventSub?.cancel();
    await _huaweiEventSub?.cancel();
    await _bleHrSub?.cancel();
    await _huaweiHrSub?.cancel();
    _initialized = false;
  }
}
