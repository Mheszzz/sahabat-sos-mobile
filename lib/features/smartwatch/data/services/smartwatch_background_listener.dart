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
    if (token == null || token.isEmpty) {
      debugPrint('SmartwatchBackgroundListener: Tidak ada auth_token, skip start');
      return;
    }

    try {
      manager.onSosDetected = (event) {
        debugPrint('🚨 SmartwatchBackgroundListener: SOS detected from ${event.deviceId}');
        onSosDetected?.call(event);
      };

      manager.onEmergencySent = (success, event) {
        debugPrint('📡 SmartwatchBackgroundListener: Emergency sent (success=$success)');
        onEmergencySent?.call(success, event);
      };

      manager.onEmergencyError = (err) {
        debugPrint('❌ SmartwatchBackgroundListener: Emergency error: $err');
        onEmergencyError?.call(err);
      };

      await manager.init();
      _isRunning = true;
      debugPrint('✅ SmartwatchBackgroundListener started successfully');
    } catch (e) {
      debugPrint('❌ Error starting SmartwatchBackgroundListener: $e');
    }
  }

  Future<void> stop() async {
    _isRunning = false;
    try {
      await manager.dispose();
    } catch (e) {
      debugPrint('Error stopping SmartwatchBackgroundListener: $e');
    }
  }
}
