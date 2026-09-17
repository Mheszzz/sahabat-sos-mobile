import 'dart:async';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/tuya_dp_event_model.dart';
import 'tuya_channel_service.dart';
import 'emergency_trigger_service.dart';

/// Background listener that automatically monitors all paired Tuya devices
/// for SOS events and triggers emergency alerts.
///
/// This service should be initialized once when the app starts (after login)
/// and runs for the entire app lifecycle.
class TuyaBackgroundListener {
  final TuyaChannelService _tuyaService;
  final EmergencyTriggerService _emergencyService;
  final SharedPreferences _prefs;

  StreamSubscription<TuyaDpEvent>? _subscription;
  bool _isRunning = false;

  /// Callback invoked when an SOS event is detected
  void Function(TuyaDpEvent event)? onSosDetected;

  /// Callback invoked when an emergency trigger is sent to server
  void Function(bool success, TuyaDpEvent event)? onEmergencySent;

  TuyaBackgroundListener({
    required this._tuyaService,
    required EmergencyTriggerService emergencyService,
    required this._prefs,
  })  : _emergencyService = emergencyService;

  bool get isRunning => _isRunning;

  /// Start the background listener
  ///
  /// Should be called after user login and Tuya SDK initialization.
  /// Automatically listens to EventChannel and processes SOS events.
  Future<void> start() async {
    if (_isRunning) return;

    // Check if user is authenticated
    final token = _prefs.getString('auth_token');
    if (token == null || token.isEmpty) return;

    // Initialize Tuya SDK
    try {
      await _tuyaService.initTuya();
    } catch (_) {
      // SDK may already be initialized
    }

    // Start EventChannel listening
    _tuyaService.startEventListening();

    // Subscribe to DP events
    _subscription = _tuyaService.dpEventStream.listen(
      _handleEvent,
      onError: (error) {
        // Log error but keep listener alive
      },
    );

    _isRunning = true;
  }

  /// Stop the background listener
  void stop() {
    _subscription?.cancel();
    _subscription = null;
    _tuyaService.stopEventListening();
    _isRunning = false;
  }

  /// Handle incoming DP events
  Future<void> _handleEvent(TuyaDpEvent event) async {
    if (!event.isSosTriggered) return;

    // Notify callback
    onSosDetected?.call(event);

    // Send emergency to Laravel
    try {
      final success = await _emergencyService.triggerEmergency(event);
      onEmergencySent?.call(success, event);
    } catch (e) {
      onEmergencySent?.call(false, event);
    }
  }

  /// Dispose resources
  void dispose() {
    stop();
  }
}
