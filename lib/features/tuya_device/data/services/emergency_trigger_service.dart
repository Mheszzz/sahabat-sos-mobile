

import 'package:dio/dio.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/constants/api_constants.dart';
import '../../../../core/services/location_service.dart';
import '../models/tuya_dp_event_model.dart';

/// Service responsible for sending emergency trigger events to the Laravel backend.
/// 
/// When an SOS event is detected from a Tuya device, this service:
/// 1. Fetches the current GPS location
/// 2. Sends HTTP POST to /emergency/trigger
/// 3. Handles retry logic for failed requests
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

  /// Trigger emergency alert to Laravel backend
  /// 
  /// Returns true if the trigger was sent successfully
  Future<bool> triggerEmergency(TuyaDpEvent event) async {
    final token = _prefs.getString('auth_token');
    if (token == null || token.isEmpty) {
      throw EmergencyTriggerException('User not authenticated');
    }

    // Try to get current location from cached position or Geolocator
    double? latitude;
    double? longitude;
    try {
      // First try cached position from LocationService
      final cachedPosition = _locationService.currentPosition.value;
      if (cachedPosition != null) {
        latitude = cachedPosition.latitude;
        longitude = cachedPosition.longitude;
      } else {
        // Fallback to direct Geolocator call
        final position = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
        ).timeout(const Duration(seconds: 5));
        latitude = position.latitude;
        longitude = position.longitude;
      }
    } catch (e) {
      // Continue without location if GPS fails
      // Location is optional but highly recommended
    }

    final payload = {
      'device_id': event.deviceId,
      'timestamp': event.timestamp.toIso8601String(),
      'trigger_source': 'ble_button',
      'dps': event.dps,
      'is_simulation': event.isSimulation,
      'latitude': latitude,
      'longitude': longitude,
    };

    // Attempt to send with retries
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
          ),
        );

        if (response.statusCode == 200 || response.statusCode == 201) {
          return true;
        }
      } on DioException catch (e) {
        if (attempt == _maxRetries) {
          throw EmergencyTriggerException(
            'Failed to send emergency after $_maxRetries attempts: ${e.message}',
          );
        }
        // Wait before retrying
        await Future.delayed(_retryDelay * attempt);
      }
    }

    return false;
  }

  /// Send a test/simulation trigger (does not trigger real emergency)
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

/// Custom exception for emergency trigger errors
class EmergencyTriggerException implements Exception {
  final String message;
  const EmergencyTriggerException(this.message);

  @override
  String toString() => 'EmergencyTriggerException: $message';
}
