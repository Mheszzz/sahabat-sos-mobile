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
    return TuyaDeviceModel(
      deviceId: json['device_id'] as String? ?? json['deviceId'] as String? ?? '',
      name: json['name'] as String? ?? 'Unknown Device',
      productId: json['product_id'] as String? ?? json['productId'] as String? ?? '',
      isOnline: json['is_online'] as bool? ?? json['isOnline'] as bool? ?? false,
      batteryLevel: json['battery'] as int?,
      signalStrength: json['signal_strength'] as String?,
      dps: json['dps'] is Map ? Map<String, dynamic>.from(json['dps'] as Map) : {},
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
