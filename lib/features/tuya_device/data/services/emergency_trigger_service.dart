import 'package:dio/dio.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:get_it/get_it.dart';

import '../../../../core/constants/api_constants.dart';
import '../../../../core/services/location_service.dart';
import '../../../../core/utils/device_info_helper.dart';
import '../models/tuya_dp_event_model.dart';
import 'tuya_channel_service.dart';

class EmergencyTriggerService {
  final Dio _dio;
  final SharedPreferences _prefs;
  final LocationService _locationService;

  static const int _maxRetries = 3;
  static const Duration _retryDelay = Duration(seconds: 2);

  EmergencyTriggerService({
    required this._dio,
    required SharedPreferences prefs,
    required this._locationService,
  })  : _prefs = prefs;

  Future<bool> triggerEmergency(TuyaDpEvent event) async {
    final token = _prefs.getString('auth_token');
    if (token == null || token.isEmpty) {
      throw const EmergencyTriggerException('User not authenticated');
    }

    double? latitude;
    double? longitude;
    try {
      final cachedPosition = _locationService.currentPosition.value;
      if (cachedPosition != null) {
        latitude = cachedPosition.latitude;
        longitude = cachedPosition.longitude;
      } else {
        final position = await Geolocator.getLastKnownPosition();
        if (position != null) {
          latitude = position.latitude;
          longitude = position.longitude;
        } else {
          final quickPosition = await Geolocator.getCurrentPosition(
            locationSettings: const LocationSettings(
              accuracy: LocationAccuracy.low,
            ),
          ).timeout(const Duration(seconds: 1));
          latitude = quickPosition.latitude;
          longitude = quickPosition.longitude;
        }
      }
    } catch (_) {}

    final telemetryData = await DeviceInfoHelper.getSosTelemetryData();

    Map<String, dynamic>? tuyaDeviceInfo;
    try {
      final tuyaService = GetIt.instance<TuyaChannelService>();
      final tuyaDevice = await tuyaService.getDeviceStatus(event.deviceId);
      tuyaDeviceInfo = {
        'battery_level': tuyaDevice.batteryLevel,
        'is_online': tuyaDevice.isOnline,
        'device_id': tuyaDevice.deviceId,
        'last_seen': tuyaDevice.lastEventAt?.toIso8601String() ??
            DateTime.now().toIso8601String(),
        'location_updated_at': DateTime.now().toIso8601String(),
      };
    } catch (_) {}

    final payload = <String, dynamic>{
      'device_id': event.deviceId,
      'timestamp': event.timestamp.toIso8601String(),
      'trigger_source': 'tuya_wifi',
      'dps': event.dps,
      'is_simulation': event.isSimulation,
      'latitude': latitude ?? 0.0,
      'longitude': longitude ?? 0.0,
      'lokasi_user': _locationService.lastGeocodedAddress,
      ...telemetryData,
      'device_info': ?tuyaDeviceInfo,
    };

    return _sendPayloadWithRetry(payload, token);
  }

  Future<bool> triggerSmartwatchEmergency(
    dynamic smartwatchEvent, {
    dynamic smartwatchDevice,
  }) async {
    final token = _prefs.getString('auth_token');
    if (token == null || token.isEmpty) {
      throw const EmergencyTriggerException('User not authenticated');
    }

    double? latitude;
    double? longitude;
    try {
      final cachedPosition = _locationService.currentPosition.value;
      if (cachedPosition != null) {
        latitude = cachedPosition.latitude;
        longitude = cachedPosition.longitude;
      } else {
        final position = await Geolocator.getLastKnownPosition();
        if (position != null) {
          latitude = position.latitude;
          longitude = position.longitude;
        } else {
          final quickPosition = await Geolocator.getCurrentPosition(
            locationSettings: const LocationSettings(
              accuracy: LocationAccuracy.low,
            ),
          ).timeout(const Duration(seconds: 1));
          latitude = quickPosition.latitude;
          longitude = quickPosition.longitude;
        }
      }
    } catch (_) {}

    final telemetryData = await DeviceInfoHelper.getSosTelemetryData();

    final smartwatchMap = smartwatchEvent.toTelemetryMap(
      brand: smartwatchDevice?.brand ?? 'generic_ble',
      deviceModel: smartwatchDevice?.deviceModel ?? 'Smartwatch',
      deviceName: smartwatchDevice?.name ?? 'Smartwatch',
    );

    final payload = <String, dynamic>{
      'device_id': smartwatchEvent.deviceId,
      'timestamp': smartwatchEvent.timestamp.toIso8601String(),
      'trigger_source': smartwatchEvent.triggerSourceString,
      'latitude': latitude ?? 0.0,
      'longitude': longitude ?? 0.0,
      'battery_level': telemetryData['battery_level'],
      'signal_strength': telemetryData['signal_strength'],
      'lokasi_user': _locationService.lastGeocodedAddress,
      ...telemetryData,
      'device_info': {
        'mobile': telemetryData,
        'smartwatch': smartwatchMap,
      },
    };

    return _sendPayloadWithRetry(payload, token);
  }

  Future<bool> _sendPayloadWithRetry(
      Map<String, dynamic> payload, String token) async {
    for (int attempt = 1; attempt <= _maxRetries; attempt++) {
      try {
        final response = await _dio.post(
          ApiConstants.emergencyTrigger,
          data: payload,
          options: Options(
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
              'Accept': 'application/json',
            },
            validateStatus: (status) =>
                status != null &&
                (status >= 200 && status < 300 || status == 422),
          ),
        );

        if (response.statusCode == 200 || response.statusCode == 201) {
          return true;
        } else if (response.statusCode == 422) {
          final message =
              response.data['message'] ?? 'Data tidak lengkap / Error 422';
          throw EmergencyTriggerException(message.toString());
        }
      } on DioException catch (e) {
        if (attempt == _maxRetries) {
          throw EmergencyTriggerException(
            'Gagal mengirim sinyal darurat: ${e.message}',
          );
        }
        await Future.delayed(_retryDelay * attempt);
      }
    }

    return false;
  }

  Future<bool> triggerTestEmergency(String deviceId) async {
    final testEvent = TuyaDpEvent(
      deviceId: deviceId,
      dps: {'1': true, 'sos_state': 'alarm'},
      timestamp: DateTime.now(),
      eventType: TuyaEventType.dpUpdate,
      isSimulation: true,
    );
    return triggerEmergency(testEvent);
  }
}

class EmergencyTriggerException implements Exception {
  final String message;
  const EmergencyTriggerException(this.message);

  @override
  String toString() => 'EmergencyTriggerException: $message';
}