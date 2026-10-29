class SmartwatchDeviceModel {
  final String id;
  final String name;
  final String brand; // 'huawei', 'wearos', 'generic_ble'
  final String deviceModel;
  final String? macAddress;
  final int? rssi;
  final bool isConnected;
  final int? batteryLevel;
  final int? heartRate;
  final DateTime? lastSyncedAt;

  const SmartwatchDeviceModel({
    required this.id,
    required this.name,
    this.brand = 'generic_ble',
    this.deviceModel = 'Smartwatch',
    this.macAddress,
    this.rssi,
    this.isConnected = false,
    this.batteryLevel,
    this.heartRate,
    this.lastSyncedAt,
  });

  SmartwatchDeviceModel copyWith({
    String? id,
    String? name,
    String? brand,
    String? deviceModel,
    String? macAddress,
    int? rssi,
    bool? isConnected,
    int? batteryLevel,
    int? heartRate,
    DateTime? lastSyncedAt,
  }) {
    return SmartwatchDeviceModel(
      id: id ?? this.id,
      name: name ?? this.name,
      brand: brand ?? this.brand,
      deviceModel: deviceModel ?? this.deviceModel,
      macAddress: macAddress ?? this.macAddress,
      rssi: rssi ?? this.rssi,
      isConnected: isConnected ?? this.isConnected,
      batteryLevel: batteryLevel ?? this.batteryLevel,
      heartRate: heartRate ?? this.heartRate,
      lastSyncedAt: lastSyncedAt ?? this.lastSyncedAt,
    );
  }

  factory SmartwatchDeviceModel.fromJson(Map<String, dynamic> json) {
    return SmartwatchDeviceModel(
      id: json['device_identifier'] ?? json['id'] ?? '',
      name: json['device_model'] ?? json['name'] ?? 'Smartwatch',
      brand: json['brand'] ?? 'generic_ble',
      deviceModel: json['device_model'] ?? json['name'] ?? 'Smartwatch',
      macAddress: json['mac_address'],
      rssi: json['rssi'],
      isConnected: json['is_active'] ?? json['is_connected'] ?? false,
      batteryLevel: json['last_battery_level'] ?? json['battery_level'],
      heartRate: json['last_heart_rate'] ?? json['heart_rate'],
      lastSyncedAt: json['last_synced_at'] != null
          ? DateTime.tryParse(json['last_synced_at'].toString())
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'device_identifier': id,
      'brand': brand,
      'device_model': deviceModel,
      'mac_address': macAddress,
      'last_battery_level': batteryLevel,
      'last_heart_rate': heartRate,
      'last_synced_at': lastSyncedAt?.toIso8601String(),
    };
  }

  String get brandDisplay {
    switch (brand.toLowerCase()) {
      case 'huawei':
        return 'Huawei Wear';
      case 'wearos':
        return 'Wear OS by Google';
      case 'apple':
        return 'Apple Watch';
      default:
        return 'Bluetooth Smartwatch';
    }
  }
}
