import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/smartwatch_event_model.dart';
import 'smartwatch_manager.dart';

class SmartwatchBackgroundListener {
  final SmartwatchManager manager;
  final SharedPreferences prefs;

  bool _isRunning = false;

  void Function(SmartwatchEventModel event)? onSosDetected;
  void Function(bool success, SmartwatchEventModel event)? onEmergencySent;
  void Function(String errorMsg)? onEmergencyError;

  SmartwatchBackgroundListener({
    required this.manager,
    required this.prefs,
  });

  bool get isRunning => _isRunning;

  Future<void> start() async {
    if (_isRunning) return;

    final token = prefs.getString('auth_token');
    if (token == null || token.isEmpty) return;

    try {
      manager.onSosDetected = (event) {
        onSosDetected?.call(event);
      };

      manager.onEmergencySent = (success, event) {
        onEmergencySent?.call(success, event);
      };

      manager.onEmergencyError = (err) {
        onEmergencyError?.call(err);
      };

      await manager.init();
      _isRunning = true;
      debugPrint('SmartwatchBackgroundListener started successfully');
    } catch (e) {
      debugPrint('Error starting SmartwatchBackgroundListener: $e');
    }
  }

  void stop() {
    _isRunning = false;
    manager.dispose();
  }
}
