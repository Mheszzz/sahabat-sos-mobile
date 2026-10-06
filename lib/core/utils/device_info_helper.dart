import 'dart:io';
import 'package:battery_plus/battery_plus.dart';
import 'package:device_info_plus/device_info_plus.dart';

class DeviceInfoHelper {
  static final DeviceInfoPlugin _deviceInfo = DeviceInfoPlugin();
  static final Battery _battery = Battery();

  static Future<Map<String, dynamic>> getSosTelemetryData() async {
    int batteryLevel = 100;
    try {
      batteryLevel = await _battery.batteryLevel;
    } catch (e) {
      batteryLevel = -1; // Fallback
    }

    String brand = 'Unknown';
    String model = 'Unknown';

    try {
      if (Platform.isAndroid) {
        final androidInfo = await _deviceInfo.androidInfo;
        brand = androidInfo.brand;
        model = androidInfo.model;
      } else if (Platform.isIOS) {
        final iosInfo = await _deviceInfo.iosInfo;
        brand = 'Apple';
        model = iosInfo.utsname.machine;
      }
    } catch (e) {
      // Ignored
    }

    // Signal strength is hard to get natively without extra packages, fallback to Unknown
    String signalStrength = 'Unknown';

    return {
      'battery_level': batteryLevel,
      'signal_strength': signalStrength,
      'device_info': {
        'brand': brand,
        'model': model,
        'battery_level': batteryLevel,
        'signal_strength': signalStrength,
      },
    };
  }
}
