import 'dart:convert';

enum TuyaEventType {
  dpUpdate,
  statusChanged,
  deviceRemoved,
  bleDeviceFound,
  wifiPairingSuccess,
  wifiPairingError,
  unknown,
}

class TuyaDpEvent {
  final String deviceId;
  final Map<String, dynamic> dps;
  final DateTime timestamp;
  final TuyaEventType eventType;
  final bool isOnline;
  final bool isSimulation;

  const TuyaDpEvent({
    required this.deviceId,
    required this.dps,
    required this.timestamp,
    this.eventType = TuyaEventType.dpUpdate,
    this.isOnline = true,
    this.isSimulation = false,
  });

  /// Parse raw event string from native EventChannel
  factory TuyaDpEvent.fromRawEvent(String rawEvent) {
    final json = jsonDecode(rawEvent) as Map<String, dynamic>;
    
    // Parse DPs - can be a JSON string or a Map
    Map<String, dynamic> parsedDps = {};
    if (json['dps'] != null) {
      if (json['dps'] is String) {
        parsedDps = Map<String, dynamic>.from(
          jsonDecode(json['dps'] as String) as Map,
        );
      } else if (json['dps'] is Map) {
        parsedDps = Map<String, dynamic>.from(json['dps'] as Map);
      }
    }

    // Parse event type
    TuyaEventType type = TuyaEventType.unknown;
    switch (json['type'] as String? ?? '') {
      case 'dp_update':
        type = TuyaEventType.dpUpdate;
        break;
      case 'status_changed':
        type = TuyaEventType.statusChanged;
        break;
      case 'device_removed':
        type = TuyaEventType.deviceRemoved;
        break;
      case 'ble_device_found':
        type = TuyaEventType.bleDeviceFound;
        break;
      case 'wifi_pairing_success':
        type = TuyaEventType.wifiPairingSuccess;
        break;
      case 'wifi_pairing_error':
        type = TuyaEventType.wifiPairingError;
        break;
    }

    // For BLE device found events, map the device info fields into dps
    if (type == TuyaEventType.bleDeviceFound || type == TuyaEventType.wifiPairingSuccess) {
      parsedDps = {
        'name': json['name'] as String? ?? 'Tuya Device',
        'error_msg': json['error_msg'] as String? ?? '',
      };
    }

    return TuyaDpEvent(
      deviceId: json['device_id'] as String? ?? json['id'] as String? ?? '',
      dps: parsedDps,
      timestamp: json['timestamp'] != null
          ? DateTime.fromMillisecondsSinceEpoch(json['timestamp'] as int)
          : DateTime.now(),
      eventType: type,
      isOnline: json['is_online'] as bool? ?? true,
      isSimulation: json['is_simulation'] as bool? ?? false,
    );
  }

  /// Check if this event represents an SOS button press
  bool get isSosTriggered {
    // Check common Tuya SOS Data Point codes
    // DP "1" with value true = standard SOS button
    // DP "sos_state" with value "alarm" = SOS alarm state
    if (eventType != TuyaEventType.dpUpdate) return false;

    if (dps.containsKey('1') && dps['1'] == true) return true;
    if (dps.containsKey('sos_state') && dps['sos_state'] == 'alarm') return true;
    if (dps.containsKey('1') && dps['1'] == 'alarm') return true;

    return false;
  }

  Map<String, dynamic> toJson() {
    return {
      'device_id': deviceId,
      'dps': dps,
      'timestamp': timestamp.toIso8601String(),
      'event_type': eventType.name,
      'is_online': isOnline,
      'is_simulation': isSimulation,
      'is_sos_triggered': isSosTriggered,
    };
  }

  @override
  String toString() =>
      'TuyaDpEvent(device: $deviceId, type: ${eventType.name}, sos: $isSosTriggered, dps: $dps)';
}
