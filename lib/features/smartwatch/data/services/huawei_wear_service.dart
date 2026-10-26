import 'dart:async';
import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import '../models/smartwatch_device_model.dart';
import '../models/smartwatch_event_model.dart';
import 'smartwatch_service.dart';

class HuaweiWearService implements SmartwatchService {
  @override
  String get protocolName => 'Huawei Wear Engine';

  static const MethodChannel _methodChannel =
      MethodChannel('com.sahabatsos.app/huawei_wear');
  static const EventChannel _eventChannel =
      EventChannel('com.sahabatsos.app/huawei_wear_events');

  final _eventController = StreamController<SmartwatchEventModel>.broadcast();
  final _heartRateController = StreamController<int>.broadcast();
  final _scanResultsController = StreamController<List<SmartwatchDeviceModel>>.broadcast();

  StreamSubscription? _nativeEventSub;

  HuaweiWearService() {
    _initEventListener();
  }

  void _initEventListener() {
    try {
      _nativeEventSub = _eventChannel.receiveBroadcastStream().listen((dynamic raw) {
        if (raw is String) {
          try {
            final data = jsonDecode(raw) as Map<String, dynamic>;
            final eventTypeStr = data['event'] ?? data['event_type'] ?? '';
            final deviceId = data['device_id'] ?? 'huawei_watch_default';
            final hr = data['heart_rate'] as int?;
            final battery = data['battery_level'] as int?;

            if (hr != null) {
              _heartRateController.add(hr);
            }

            if (eventTypeStr == 'SOS_TRIGGER' || eventTypeStr == 'sos_button_pressed') {
              _eventController.add(SmartwatchEventModel(
                deviceId: deviceId,
                eventType: SmartwatchEventType.sosButtonPressed,
                heartRate: hr,
                batteryLevel: battery,
                timestamp: DateTime.now(),
                triggerType: 'Tombol SOS Huawei Watch',
                rawPayload: data,
              ));
            } else if (eventTypeStr == 'FALL_DETECTED' || eventTypeStr == 'fall_detected') {
              _eventController.add(SmartwatchEventModel(
                deviceId: deviceId,
                eventType: SmartwatchEventType.fallDetected,
                heartRate: hr,
                batteryLevel: battery,
                fallDetected: true,
                timestamp: DateTime.now(),
                triggerType: 'Deteksi Jatuh Huawei Watch',
                rawPayload: data,
              ));
            }
          } catch (e) {
            debugPrint('Error parsing Huawei Wear native event: $e');
          }
        }
      }, onError: (err) {
        debugPrint('Huawei Wear event stream error: $err');
      });
    } catch (e) {
      debugPrint('Huawei Wear event channel not available: $e');
    }
  }

  @override
  Future<bool> isSupported() async {
    try {
      final res = await _methodChannel.invokeMethod<bool>('isWearEngineSupported');
      return res ?? false;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<void> startScan({Duration timeout = const Duration(seconds: 10)}) async {
    try {
      final List<dynamic>? devices =
          await _methodChannel.invokeMethod<List<dynamic>>('getBondedHuaweiDevices');
      final list = <SmartwatchDeviceModel>[];
      if (devices != null) {
        for (final item in devices) {
          if (item is Map) {
            list.add(SmartwatchDeviceModel(
              id: item['device_id']?.toString() ?? 'hw_device',
              name: item['device_name']?.toString() ?? 'Huawei Watch',
              brand: 'huawei',
              deviceModel: item['device_name']?.toString() ?? 'Huawei Watch GT',
              isConnected: item['is_connected'] == true,
              batteryLevel: item['battery_level'] as int?,
            ));
          }
        }
      }
      _scanResultsController.add(list);
    } catch (e) {
      debugPrint('Error scanning Huawei Wear devices: $e');
      _scanResultsController.add([]);
    }
  }

  @override
  Future<void> stopScan() async {
    // Huawei Wear Engine uses bonded list from Huawei Health, no active BLE scan needed
  }

  @override
  Stream<List<SmartwatchDeviceModel>> get scanResultsStream =>
      _scanResultsController.stream;

  @override
  Future<bool> connect(SmartwatchDeviceModel device) async {
    try {
      final res = await _methodChannel.invokeMethod<bool>('connectDevice', {
        'device_id': device.id,
      });
      return res ?? true;
    } catch (e) {
      debugPrint('Error connecting to Huawei device: $e');
      return false;
    }
  }

  @override
  Future<void> disconnect(String deviceId) async {
    try {
      await _methodChannel.invokeMethod<void>('disconnectDevice', {
        'device_id': deviceId,
      });
    } catch (e) {
      debugPrint('Error disconnecting Huawei device: $e');
    }
  }

  @override
  Stream<SmartwatchEventModel> get eventStream => _eventController.stream;

  @override
  Stream<int> get heartRateStream => _heartRateController.stream;

  @override
  Future<void> sendFeedbackAlert(
    String deviceId, {
    required String title,
    required String message,
  }) async {
    try {
      await _methodChannel.invokeMethod<void>('sendFeedbackAlert', {
        'device_id': deviceId,
        'title': title,
        'message': message,
      });
    } catch (e) {
      debugPrint('Error sending feedback to Huawei watch: $e');
    }
  }

  @override
  Future<void> dispose() async {
    await _nativeEventSub?.cancel();
    await _eventController.close();
    await _heartRateController.close();
    await _scanResultsController.close();
  }
}
