import 'dart:async';

import 'package:flutter/services.dart';

import '../models/tuya_device_model.dart';
import '../models/tuya_dp_event_model.dart';

/// Service that bridges Flutter with native Tuya SDK via Platform Channels.
/// 
/// Uses MethodChannel for command/response operations (init, scan, pair, etc.)
/// and EventChannel for streaming real-time DP updates from Tuya devices.
class TuyaChannelService {
  static const MethodChannel _methodChannel =
      MethodChannel('com.sahabatsos.app/tuya_method');
  static const EventChannel _eventChannel =
      EventChannel('com.sahabatsos.app/tuya_events');

  StreamSubscription<dynamic>? _eventSubscription;
  final StreamController<TuyaDpEvent> _dpEventController =
      StreamController<TuyaDpEvent>.broadcast();
  final StreamController<TuyaDpEvent> _bleDeviceController =
      StreamController<TuyaDpEvent>.broadcast();

  /// Stream of DP events from Tuya devices
  Stream<TuyaDpEvent> get dpEventStream => _dpEventController.stream;

  /// Stream of BLE device discovery events (during scanning)
  Stream<TuyaDpEvent> get bleDeviceStream => _bleDeviceController.stream;

  bool _isListening = false;
  bool get isListening => _isListening;

  /// Initialize the Tuya SDK on native side
  Future<Map<String, dynamic>> initTuya() async {
    try {
      final result = await _methodChannel.invokeMethod('initTuya');
      return Map<String, dynamic>.from(result as Map);
    } on PlatformException catch (e) {
      throw TuyaServiceException('Failed to init Tuya SDK: ${e.message}');
    }
  }

  /// Login anonymously with a unique user identifier
  Future<Map<String, dynamic>> loginAnonymous(String uid) async {
    try {
      final result = await _methodChannel.invokeMethod('loginAnonymous', {
        'uid': uid,
      });
      return Map<String, dynamic>.from(result as Map);
    } on PlatformException catch (e) {
      throw TuyaServiceException('Failed to login: ${e.message}');
    }
  }

  /// Start scanning for nearby BLE Tuya devices
  Future<Map<String, dynamic>> startBLEScan() async {
    try {
      final result = await _methodChannel.invokeMethod('startBLEScan');
      return Map<String, dynamic>.from(result as Map);
    } on PlatformException catch (e) {
      throw TuyaServiceException('Failed to start BLE scan: ${e.message}');
    }
  }

  /// Start Wi-Fi EZ Mode pairing
  Future<Map<String, dynamic>> startWifiPairing(String ssid, String password) async {
    try {
      final result = await _methodChannel.invokeMethod('startWifiPairing', {
        'ssid': ssid,
        'password': password,
      });
      return Map<String, dynamic>.from(result as Map);
    } on PlatformException catch (e) {
      throw TuyaServiceException('Failed to start Wi-Fi pairing: ${e.message}');
    }
  }

  /// Start Wi-Fi AP Mode pairing (more reliable than EZ Mode)
  Future<Map<String, dynamic>> startWifiPairingAP(String ssid, String password) async {
    try {
      final result = await _methodChannel.invokeMethod('startWifiPairingAP', {
        'ssid': ssid,
        'password': password,
      });
      return Map<String, dynamic>.from(result as Map);
    } on PlatformException catch (e) {
      throw TuyaServiceException('Failed to start Wi-Fi AP pairing: ${e.message}');
    }
  }

  /// Step 1 AP Mode: Get pairing token (requires internet)
  Future<Map<String, dynamic>> getWifiToken() async {
    try {
      final result = await _methodChannel.invokeMethod('getWifiToken');
      return Map<String, dynamic>.from(result as Map);
    } on PlatformException catch (e) {
      throw TuyaServiceException('Failed to get Wi-Fi token: ${e.message}');
    }
  }

  /// Step 2 AP Mode: Start AP pairing with pre-fetched token (no internet needed)
  Future<Map<String, dynamic>> startApPairingWithToken(String ssid, String password, String token) async {
    try {
      final result = await _methodChannel.invokeMethod('startApPairingWithToken', {
        'ssid': ssid,
        'password': password,
        'token': token,
      });
      return Map<String, dynamic>.from(result as Map);
    } on PlatformException catch (e) {
      throw TuyaServiceException('Failed to start AP pairing: ${e.message}');
    }
  }

  /// Stop Wi-Fi pairing
  Future<void> stopWifiPairing() async {
    try {
      await _methodChannel.invokeMethod('stopWifiPairing');
    } on PlatformException catch (e) {
      throw TuyaServiceException('Failed to stop Wi-Fi pairing: ${e.message}');
    }
  }

  /// Stop BLE scanning
  Future<Map<String, dynamic>> stopBLEScan() async {
    try {
      final result = await _methodChannel.invokeMethod('stopBLEScan');
      return Map<String, dynamic>.from(result as Map);
    } on PlatformException catch (e) {
      throw TuyaServiceException('Failed to stop BLE scan: ${e.message}');
    }
  }

  /// Pair a discovered BLE device
  Future<Map<String, dynamic>> pairDevice(String deviceInfo) async {
    try {
      final result = await _methodChannel.invokeMethod('pairDevice', {
        'deviceInfo': deviceInfo,
      });
      return Map<String, dynamic>.from(result as Map);
    } on PlatformException catch (e) {
      throw TuyaServiceException('Failed to pair device: ${e.message}');
    }
  }

  /// Get list of paired Tuya devices
  Future<List<TuyaDeviceModel>> getDeviceList() async {
    try {
      final result = await _methodChannel.invokeMethod('getDeviceList');
      final list = result as List<dynamic>;
      return list
          .map((item) =>
              TuyaDeviceModel.fromJson(Map<String, dynamic>.from(item as Map)))
          .toList();
    } on PlatformException catch (e) {
      throw TuyaServiceException('Failed to get device list: ${e.message}');
    }
  }

  /// Remove a device from Tuya Cloud
  Future<void> removeDevice(String deviceId) async {
    try {
      await _methodChannel.invokeMethod('removeDevice', {
        'deviceId': deviceId,
      });
    } on PlatformException catch (e) {
      throw TuyaServiceException('Failed to remove device: ${e.message}');
    }
  }

  /// Start listening to DP updates from a specific device
  Future<void> listenDevice(String deviceId) async {
    try {
      await _methodChannel.invokeMethod('listenDevice', {
        'deviceId': deviceId,
      });
    } on PlatformException catch (e) {
      throw TuyaServiceException('Failed to listen device: ${e.message}');
    }
  }

  /// Stop listening to a specific device
  Future<void> stopListenDevice(String deviceId) async {
    try {
      await _methodChannel.invokeMethod('stopListenDevice', {
        'deviceId': deviceId,
      });
    } on PlatformException catch (e) {
      throw TuyaServiceException('Failed to stop listening: ${e.message}');
    }
  }

  /// Get device status (battery, signal, online state)
  Future<TuyaDeviceModel> getDeviceStatus(String deviceId) async {
    try {
      final result = await _methodChannel.invokeMethod('getDeviceStatus', {
        'deviceId': deviceId,
      });
      return TuyaDeviceModel.fromJson(Map<String, dynamic>.from(result as Map));
    } on PlatformException catch (e) {
      throw TuyaServiceException('Failed to get device status: ${e.message}');
    }
  }

  /// Simulate an SOS event for testing without physical hardware
  Future<void> simulateSosEvent({String deviceId = 'sim_device_001'}) async {
    try {
      await _methodChannel.invokeMethod('simulateSosEvent', {
        'deviceId': deviceId,
      });
    } on PlatformException catch (e) {
      throw TuyaServiceException('Failed to simulate SOS: ${e.message}');
    }
  }

  /// Start listening to the EventChannel for real-time DP updates
  void startEventListening() {
    if (_isListening) return;

    _eventSubscription = _eventChannel.receiveBroadcastStream().listen(
      (dynamic event) {
        try {
          final dpEvent = TuyaDpEvent.fromRawEvent(event.toString());
          // Route BLE device discovery events to separate stream
          if (dpEvent.eventType == TuyaEventType.bleDeviceFound) {
            _bleDeviceController.add(dpEvent);
          } else {
            _dpEventController.add(dpEvent);
          }
        } catch (e) {
          _dpEventController.addError(
            TuyaServiceException('Failed to parse DP event: $e'),
          );
        }
      },
      onError: (dynamic error) {
        _dpEventController.addError(
          TuyaServiceException('EventChannel error: $error'),
        );
      },
    );
    _isListening = true;
  }

  /// Stop listening to the EventChannel
  void stopEventListening() {
    _eventSubscription?.cancel();
    _eventSubscription = null;
    _isListening = false;
  }

  /// Dispose all resources
  void dispose() {
    stopEventListening();
    _dpEventController.close();
    _bleDeviceController.close();
  }
}

/// Custom exception for Tuya service errors
class TuyaServiceException implements Exception {
  final String message;
  const TuyaServiceException(this.message);

  @override
  String toString() => 'TuyaServiceException: $message';
}
