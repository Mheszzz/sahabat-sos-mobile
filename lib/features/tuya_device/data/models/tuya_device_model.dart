class TuyaDeviceModel {
  final String deviceId;
  final String name;
  final String productId;
  final bool isOnline;
  final int? batteryLevel;
  final String? signalStrength;
  final Map<String, dynamic> dps;
  final DateTime? lastEventAt;

  const TuyaDeviceModel({
    required this.deviceId,
    required this.name,
    this.productId = '',
    this.isOnline = false,
    this.batteryLevel,
    this.signalStrength,
    this.dps = const {},
    this.lastEventAt,
  });

  factory TuyaDeviceModel.fromJson(Map<String, dynamic> json) {
    final dpsMap = json['dps'] is Map ? Map<String, dynamic>.from(json['dps'] as Map) : <String, dynamic>{};
    
    // Parse battery from common Tuya DPs if missing from root
    int? parsedBattery = json['battery'] as int?;
    if (parsedBattery == null || parsedBattery < 0) {
      if (dpsMap.containsKey('battery_percentage')) {
        parsedBattery = (dpsMap['battery_percentage'] as num).toInt();
      } else if (dpsMap.containsKey('3')) {
        parsedBattery = (dpsMap['3'] as num).toInt(); // Common for some BLE/Wi-Fi devices
      } else if (dpsMap.containsKey('104')) {
        parsedBattery = (dpsMap['104'] as num).toInt();
      }
    }

    return TuyaDeviceModel(
      deviceId: json['device_id'] as String? ?? json['deviceId'] as String? ?? '',
      name: json['name'] as String? ?? 'Unknown Device',
      productId: json['product_id'] as String? ?? json['productId'] as String? ?? '',
      isOnline: json['is_online'] as bool? ?? json['isOnline'] as bool? ?? false,
      batteryLevel: parsedBattery,
      signalStrength: json['signal_strength'] as String?,
      dps: dpsMap,
      lastEventAt: json['last_event_at'] != null
          ? DateTime.tryParse(json['last_event_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'device_id': deviceId,
      'name': name,
      'product_id': productId,
      'is_online': isOnline,
      'battery': batteryLevel,
      'signal_strength': signalStrength,
      'dps': dps,
      'last_event_at': lastEventAt?.toIso8601String(),
    };
  }

  TuyaDeviceModel copyWith({
    String? deviceId,
    String? name,
    String? productId,
    bool? isOnline,
    int? batteryLevel,
    String? signalStrength,
    Map<String, dynamic>? dps,
    DateTime? lastEventAt,
  }) {
    return TuyaDeviceModel(
      deviceId: deviceId ?? this.deviceId,
      name: name ?? this.name,
      productId: productId ?? this.productId,
      isOnline: isOnline ?? this.isOnline,
      batteryLevel: batteryLevel ?? this.batteryLevel,
      signalStrength: signalStrength ?? this.signalStrength,
      dps: dps ?? this.dps,
      lastEventAt: lastEventAt ?? this.lastEventAt,
    );
  }

  @override
  String toString() => 'TuyaDeviceModel(id: $deviceId, name: $name, online: $isOnline)';
}
