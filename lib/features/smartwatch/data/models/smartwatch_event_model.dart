enum SmartwatchEventType {
  sosButtonPressed,
  fallDetected,
  heartRateAnomaly,
  periodicTelemetry,
}

class SmartwatchEventModel {
  final String deviceId;
  final SmartwatchEventType eventType;
  final int? heartRate;
  final int? batteryLevel;
  final bool fallDetected;
  final DateTime timestamp;
  final String? triggerType;
  final Map<String, dynamic>? rawPayload;

  const SmartwatchEventModel({
    required this.deviceId,
    required this.eventType,
    this.heartRate,
    this.batteryLevel,
    this.fallDetected = false,
    required this.timestamp,
    this.triggerType,
    this.rawPayload,
  });

  bool get isEmergency =>
      eventType == SmartwatchEventType.sosButtonPressed ||
      eventType == SmartwatchEventType.fallDetected ||
      eventType == SmartwatchEventType.heartRateAnomaly;

  String get triggerSourceString {
    switch (eventType) {
      case SmartwatchEventType.fallDetected:
        return 'smartwatch_fall_detection';
      case SmartwatchEventType.heartRateAnomaly:
        return 'smartwatch_heart_rate_anomaly';
      case SmartwatchEventType.sosButtonPressed:
      default:
        return 'smartwatch_button';
    }
  }

  Map<String, dynamic> toTelemetryMap({
    required String brand,
    required String deviceModel,
    required String deviceName,
  }) {
    return {
      'device_id': deviceId,
      'device_name': deviceName,
      'brand': brand,
      'device_model': deviceModel,
      'is_online': true,
      'battery_level': batteryLevel,
      'heart_rate': heartRate,
      'fall_detected': fallDetected || (eventType == SmartwatchEventType.fallDetected),
      'trigger_type': triggerType ??
          (eventType == SmartwatchEventType.fallDetected
              ? 'Deteksi Jatuh Jam'
              : (eventType == SmartwatchEventType.heartRateAnomaly
                  ? 'Anomali Detak Jantung Jam'
                  : 'Tombol SOS Jam')),
      'last_seen': timestamp.toIso8601String(),
    };
  }
}
