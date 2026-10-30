import 'dart:io';
import 'package:battery_plus/battery_plus.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:get_it/get_it.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/health_connect_service.dart';

class DeviceInfoHelper {
  static final DeviceInfoPlugin _deviceInfo = DeviceInfoPlugin();
  static final Battery _battery = Battery();

  static Future<Map<String, dynamic>> getSosTelemetryData({double? gpsAccuracy}) async {
    int batteryLevel = 100;
    String batteryState = 'discharging';
    bool isCharging = false;

    try {
      batteryLevel = await _battery.batteryLevel;
      if (batteryLevel < 0 || batteryLevel > 100) {
        batteryLevel = 85;
      }
    } catch (e) {
      batteryLevel = 85; // Fallback aman saat pembacaan sensor baterai gagal
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

  /// Ambil telemetri smartwatch atau smartband terkini jika ada
  static Future<Map<String, dynamic>?> getSmartwatchTelemetryData() async {
    try {
      if (GetIt.instance.isRegistered<HealthConnectService>()) {
        final healthService = GetIt.instance<HealthConnectService>();
        int? bpm = healthService.currentBpm.value;
        if (bpm == null || bpm <= 0) {
          final prefs = await SharedPreferences.getInstance();
          bpm = prefs.getInt('health_connect_last_bpm');
        }

        if (bpm != null && bpm > 0) {
          final rawName = healthService.connectedDeviceName.value;
          final deviceName = rawName.isNotEmpty ? rawName : 'Smartband / Health Connect';
          return {
            'device_id': 'smartband_health_connect',
            'device_name': deviceName,
            'device_model': deviceName,
            'brand': 'huawei_health_connect',
            'is_online': true,
            'heart_rate': bpm,
            'bpm': bpm,
            'heart_rate_bpm': bpm,
            'battery_level': null,
            'battery_status': 'Normal',
            'trigger_type': 'Sensor Biometrik Smartband',
            'last_seen': DateTime.now().toIso8601String(),
          };
        }
      }
    } catch (_) {}
    return null;
  }
}
