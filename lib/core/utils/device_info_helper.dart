import 'dart:io';
import 'package:battery_plus/battery_plus.dart';
import 'package:device_info_plus/device_info_plus.dart';

class DeviceInfoHelper {
  static final DeviceInfoPlugin _deviceInfo = DeviceInfoPlugin();
  static final Battery _battery = Battery();

  static Future<Map<String, dynamic>> getSosTelemetryData({double? gpsAccuracy}) async {
    int batteryLevel = 100;
    String batteryState = 'discharging';
    bool isCharging = false;

    try {
      batteryLevel = await _battery.batteryLevel;
    } catch (e) {
      batteryLevel = -1; // Fallback
    }

    try {
      final state = await _battery.batteryState;
      switch (state) {
        case BatteryState.charging:
          batteryState = 'charging';
          isCharging = true;
          break;
        case BatteryState.discharging:
          batteryState = 'discharging';
          isCharging = false;
          break;
        case BatteryState.full:
          batteryState = 'full';
          isCharging = true;
          break;
        case BatteryState.unknown:
        default:
          batteryState = 'unknown';
          isCharging = false;
          break;
      }
    } catch (_) {}

    String brand = 'Unknown';
    String model = 'Unknown';
    String osVersion = 'Unknown';

    try {
      if (Platform.isAndroid) {
        final androidInfo = await _deviceInfo.androidInfo;
        brand = androidInfo.brand;
        model = androidInfo.model;
        osVersion = 'Android ${androidInfo.version.release} (SDK ${androidInfo.version.sdkInt})';
      } else if (Platform.isIOS) {
        final iosInfo = await _deviceInfo.iosInfo;
        brand = 'Apple';
        model = iosInfo.utsname.machine;
        osVersion = 'iOS ${iosInfo.systemVersion}';
      }
    } catch (e) {
      // Ignored
    }

    const String signalStrength = '4G / Wi-Fi';

    final mobileMap = {
      'brand': brand,
      'model': model,
      'os_version': osVersion,
      'battery_level': batteryLevel,
      'is_charging': isCharging,
      'battery_state': batteryState,
      'signal_strength': signalStrength,
      'gps_accuracy': ?gpsAccuracy,
      'updated_at': DateTime.now().toIso8601String(),
    };

    return {
      'battery_level': batteryLevel,
      'signal_strength': signalStrength,
      'device_info': mobileMap,
    };
  }
}
