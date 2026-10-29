import 'dart:async';
import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:health/health.dart';
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

  final Health _health = Health();

  final ValueNotifier<SmartwatchDeviceModel?> activeDevice = ValueNotifier(null);
  final ValueNotifier<int?> liveHeartRate = ValueNotifier(null);
  final ValueNotifier<int?> liveBatteryLevel = ValueNotifier(null);
  final ValueNotifier<bool> isConnecting = ValueNotifier(false);
  final ValueNotifier<String?> connectingDeviceId = ValueNotifier(null);
  final ValueNotifier<List<SmartwatchDeviceModel>> pairedDevices = ValueNotifier([]);
  final ValueNotifier<String?> connectionStatus = ValueNotifier(null);

  StreamSubscription? _bleEventSub;
  StreamSubscription? _huaweiEventSub;
  StreamSubscription? _bleHrSub;
  StreamSubscription? _bleBatterySub;
  StreamSubscription? _huaweiHrSub;
  Timer? _telemetrySyncTimer;
  Timer? _healthConnectPollTimer;

  Function(SmartwatchEventModel)? onSosDetected;
  Function(bool success, SmartwatchEventModel event)? onEmergencySent;
  Function(String error)? onEmergencyError;

  static const String _prefKeyActiveDevice = 'active_smartwatch_device';
  static const Duration _telemetrySyncInterval = Duration(minutes: 5);

  bool _initialized = false;
  bool _huaweiSupported = false;
  bool _healthConnectAuthorized = false;

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

    try {
      await _health.configure();
    } catch (e) {
      debugPrint('Health Connect configure info: $e');
    }

    _loadCachedDevice();
    _setupListeners();
    await fetchPairedDevicesFromBackend();

    if (activeDevice.value != null) {
      connectDevice(activeDevice.value!);
    }

    _startTelemetrySync();
    _initialized = true;
  }

  /// Mencoba mengambil Live BPM via Bluetooth (Solusi 1) terlebih dahulu,
  /// lalu fallback ke Health Connect (Solusi 2) jika belum ada
  Future<String> syncFromHealthConnect() async {
    // 1. COBA SOLUSI 1: Baca langsung via Bluetooth GATT (Heart Rate Broadcast)
    if (activeDevice.value != null) {
      connectionStatus.value = 'Membaca sensor detak jantung via Bluetooth...';
      final bleMsg = await bleService.scanAndReadLiveHeartRate(activeDevice.value!);
      if (bleService.currentBpm != null && bleService.currentBpm! > 0) {
        liveHeartRate.value = bleService.currentBpm;
        connectionStatus.value = 'Terhubung & Siaga';
        return bleMsg;
      }
      if (bleMsg.startsWith('Terhubung ke sensor HR')) {
        connectionStatus.value = 'Terhubung & Siaga';
        return bleMsg;
      }
    }

    // 2. COBA SOLUSI 2: Fallback ke Health Connect jika BLE dikunci Huawei Health
    try {
      await _health.configure();

      final status = await _health.getHealthConnectSdkStatus();
      if (status == HealthConnectSdkStatus.sdkUnavailable ||
          status == HealthConnectSdkStatus.sdkUnavailableProviderUpdateRequired) {
        await _health.installHealthConnect();
        return 'Bluetooth gelang terkunci Huawei Health & Health Connect belum aktif.';
      }

      final types = [HealthDataType.HEART_RATE];
      final permissions = [HealthDataAccess.READ];

      _healthConnectAuthorized = await _health.requestAuthorization(
        types,
        permissions: permissions,
      );

      final now = DateTime.now();
      final startTime = now.subtract(const Duration(days: 30));

      List<HealthDataPoint> data = await _health.getHealthDataFromTypes(
        types: types,
        startTime: startTime,
        endTime: now,
      );

      if (data.isNotEmpty) {
        data = _health.removeDuplicates(data);
        data.sort((a, b) => b.dateTo.compareTo(a.dateTo));
        final val = data.first.value;
        if (val is NumericHealthValue) {
          final bpm = val.numericValue.toInt();
          if (bpm > 0) {
            liveHeartRate.value = bpm;
            connectionStatus.value = 'Terhubung & Siaga';
            return 'Berhasil! Detak jantung terakhir: $bpm BPM';
          }
        }
      }

      connectionStatus.value = 'Terhubung & Siaga';
      return 'Gagal: Jalur Bluetooth gelang masih dikunci Huawei Health (ikon hati oranye di atas layar masih aktif). Paksa berhenti Huawei Health & nyalakan Siaran Detak Jantung di gelang.';
    } catch (e) {
      connectionStatus.value = 'Terhubung & Siaga';
      return 'Gagal membaca sensor: $e';
    }
  }

  void _startHealthConnectPolling() {
    _healthConnectPollTimer?.cancel();
    syncFromHealthConnect();
    _healthConnectPollTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      // Jika BLE tidak mengirimkan BPM, ambil dari Health Connect
      if (bleService.currentBpm == null || bleService.currentBpm == 0) {
        syncFromHealthConnect();
      }
    });
  }

  void _loadCachedDevice() {
    final raw = prefs.getString(_prefKeyActiveDevice);
    if (raw != null && raw.isNotEmpty) {
      try {
        final map = jsonDecode(raw) as Map<String, dynamic>;
        final dev = SmartwatchDeviceModel.fromJson(map);
        activeDevice.value = dev;
        liveBatteryLevel.value = dev.batteryLevel;
        liveHeartRate.value = dev.heartRate;
      } catch (e) {
        debugPrint('Error loading cached smartwatch: $e');
      }
    }
  }

  void _setupListeners() {
    _bleHrSub?.cancel();
    _bleBatterySub?.cancel();
    _huaweiHrSub?.cancel();
    _bleEventSub?.cancel();
    _huaweiEventSub?.cancel();

    _bleHrSub = bleService.heartRateStream.listen((bpm) {
      if (bpm > 0) {
        liveHeartRate.value = bpm;
      }
    });

    _bleBatterySub = bleService.batteryStream.listen((battery) {
      if (battery >= 0) {
        liveBatteryLevel.value = battery;
        if (activeDevice.value != null) {
          activeDevice.value = activeDevice.value!.copyWith(batteryLevel: battery);
        }
      }
    });

    _huaweiHrSub = huaweiService.heartRateStream.listen((bpm) {
      if (bpm > 0) {
        liveHeartRate.value = bpm;
      }
    });

    _bleEventSub = bleService.eventStream.listen(_handleIncomingEvent);
    _huaweiEventSub = huaweiService.eventStream.listen(_handleIncomingEvent);

    bleService.connectionState.removeListener(_onBleConnectionStateChanged);
    bleService.connectionState.addListener(_onBleConnectionStateChanged);
  }

  void _onBleConnectionStateChanged() {
    final isConnected = bleService.connectionState.value;
    final dev = activeDevice.value;

    if (dev != null) {
      if (isConnected && !dev.isConnected) {
        activeDevice.value = dev.copyWith(isConnected: true);
        connectionStatus.value = 'Terhubung & Siaga';
        _syncActiveStateToPairedList(dev.id, true);
      } else if (!isConnected && dev.isConnected) {
        activeDevice.value = dev.copyWith(isConnected: false);
        connectionStatus.value = 'Terputus: mencoba menyambung ulang...';
        _syncActiveStateToPairedList(dev.id, false);
      }
    }
  }

  void _syncActiveStateToPairedList(String deviceId, bool isConnected) {
    pairedDevices.value = pairedDevices.value.map((d) {
      if (d.id == deviceId) {
        return d.copyWith(isConnected: isConnected);
      }
      return isConnected ? d.copyWith(isConnected: false) : d;
    }).toList();
  }

  void _startTelemetrySync() {
    _telemetrySyncTimer?.cancel();
    _telemetrySyncTimer = Timer.periodic(_telemetrySyncInterval, (_) {
      _syncCurrentTelemetry();
    });
  }

  Future<void> _syncCurrentTelemetry() async {
    if (activeDevice.value == null) return;
    final bpm = liveHeartRate.value;
    final battery = liveBatteryLevel.value ?? bleService.currentBattery;
    if (bpm == null && battery == null) return;

    await syncTelemetryToBackend(battery: battery, heartRate: bpm);
  }

  Future<void> _handleIncomingEvent(SmartwatchEventModel event) async {
    if (event.isEmergency) {
      onSosDetected?.call(event);
      try {
        final success = await emergencyTriggerService.triggerSmartwatchEmergency(
          event,
          smartwatchDevice: activeDevice.value,
        );

        onEmergencySent?.call(success, event);

        if (success) {
          final service = _getServiceForBrand(activeDevice.value?.brand);
          await service.sendFeedbackAlert(
            event.deviceId,
            title: 'SOS Terkirim',
            message: 'Relawan sedang menuju lokasi Anda',
          );
          _syncCurrentTelemetry();
        }
      } catch (e) {
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
    if (token == null || token.isEmpty) return pairedDevices.value;

    try {
      final response = await dio.get(
        ApiConstants.smartwatchList,
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );

      if (response.statusCode == 200 && response.data['data'] is List) {
        final activeId = activeDevice.value?.id;
        final isCurrentlyConnected = activeDevice.value?.isConnected ?? false;

        final list = (response.data['data'] as List)
            .map((e) => SmartwatchDeviceModel.fromJson(e as Map<String, dynamic>))
            .where((model) => !BleSmartwatchService.isIgnoredDeviceName(model.name))
            .map((model) {
              if (model.id == activeId && isCurrentlyConnected) {
                return model.copyWith(isConnected: true);
              }
              return model;
            })
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
      final token = prefs.getString('auth_token');
      if (token != null && token.isNotEmpty) {
        await dio.post(
          ApiConstants.smartwatchRegister,
          data: device.toJson(),
          options: Options(headers: {'Authorization': 'Bearer $token'}),
        );
      }

      await prefs.setString(_prefKeyActiveDevice, jsonEncode(device.toJson()));
      await fetchPairedDevicesFromBackend();

      connectionStatus.value = 'Menghubungkan via Bluetooth...';
      final connected = await connectDevice(device);
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

        _syncActiveStateToPairedList(device.id, true);

        // Aktifkan juga pembacaan Health Connect (Metode 1) khususnya untuk Huawei
        _startHealthConnectPolling();

        Future.delayed(const Duration(seconds: 3), () => _syncCurrentTelemetry());
        return true;
      }
      connectionStatus.value = 'Gagal terhubung';
      return false;
    } catch (e) {
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
    _healthConnectPollTimer?.cancel();
    final service = _getServiceForBrand(dev.brand);
    await service.disconnect(dev.id);
    activeDevice.value = dev.copyWith(isConnected: false);
    liveHeartRate.value = null;
    connectionStatus.value = 'Terputus';
    _syncActiveStateToPairedList(dev.id, false);
  }

  Future<void> unpairDevice(String deviceId) async {
    await disconnectCurrentDevice();
    await prefs.remove(_prefKeyActiveDevice);
    activeDevice.value = null;
    connectionStatus.value = null;

    final token = prefs.getString('auth_token');
    if (token != null && token.isNotEmpty) {
      try {
        await dio.delete(
          ApiConstants.smartwatchDetail(deviceId),
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
    _telemetrySyncTimer?.cancel();
    _healthConnectPollTimer?.cancel();
    bleService.connectionState.removeListener(_onBleConnectionStateChanged);
    await _bleEventSub?.cancel();
    await _huaweiEventSub?.cancel();
    await _bleHrSub?.cancel();
    await _bleBatterySub?.cancel();
    await _huaweiHrSub?.cancel();
    _initialized = false;
  }
}