import 'package:flutter_test/flutter_test.dart';
import 'package:sahabat_sos_mobile/features/smartwatch/data/models/smartwatch_device_model.dart';
import 'package:sahabat_sos_mobile/features/smartwatch/data/models/smartwatch_event_model.dart';

void main() {
  group('SmartwatchDeviceModel Tests', () {
    test('fromJson and toJson should properly serialize and deserialize', () {
      final json = {
        'device_identifier': 'hw_gt4_01',
        'device_model': 'Huawei Watch GT 4',
        'brand': 'huawei',
        'mac_address': 'AA:BB:CC:DD:EE:FF',
        'is_active': true,
        'last_battery_level': 85,
        'last_heart_rate': 72,
        'last_synced_at': '2026-10-19T00:00:00.000',
      };

      final device = SmartwatchDeviceModel.fromJson(json);

      expect(device.id, 'hw_gt4_01');
      expect(device.name, 'Huawei Watch GT 4');
      expect(device.brand, 'huawei');
      expect(device.brandDisplay, 'Huawei Wear');
      expect(device.isConnected, true);
      expect(device.batteryLevel, 85);
      expect(device.heartRate, 72);

      final output = device.toJson();
      expect(output['device_identifier'], 'hw_gt4_01');
      expect(output['brand'], 'huawei');
      expect(output['last_battery_level'], 85);
      expect(output['last_heart_rate'], 72);
    });
  });

  group('SmartwatchEventModel Tests', () {
    test('isEmergency should return true for SOS button and Fall Detection', () {
      final sosEvent = SmartwatchEventModel(
        deviceId: 'hw_gt4_01',
        eventType: SmartwatchEventType.sosButtonPressed,
        heartRate: 110,
        batteryLevel: 90,
        timestamp: DateTime.now(),
      );

      expect(sosEvent.isEmergency, true);
      expect(sosEvent.triggerSourceString, 'smartwatch_button');

      final fallEvent = SmartwatchEventModel(
        deviceId: 'hw_gt4_01',
        eventType: SmartwatchEventType.fallDetected,
        heartRate: 125,
        batteryLevel: 90,
        fallDetected: true,
        timestamp: DateTime.now(),
      );

      expect(fallEvent.isEmergency, true);
      expect(fallEvent.triggerSourceString, 'smartwatch_fall_detection');

      final telemetryMap = fallEvent.toTelemetryMap(
        brand: 'huawei',
        deviceModel: 'Huawei Watch GT 4',
        deviceName: 'Huawei Watch GT 4',
      );

      expect(telemetryMap['device_id'], 'hw_gt4_01');
      expect(telemetryMap['fall_detected'], true);
      expect(telemetryMap['heart_rate'], 125);
      expect(telemetryMap['brand'], 'huawei');
    });
  });
}
