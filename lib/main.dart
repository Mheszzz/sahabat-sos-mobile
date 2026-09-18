import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:sahabat_sos_mobile/app.dart';
import 'package:sahabat_sos_mobile/core/di/injection.dart';
import 'package:sahabat_sos_mobile/features/tuya_device/data/services/tuya_background_listener.dart';
import 'package:sahabat_sos_mobile/routing/app_router.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Dependency Injection (GetIt)
  await initInjection();

  // Start Tuya background listener for SOS events
  // Will only activate if user is already authenticated
  final tuyaListener = GetIt.instance<TuyaBackgroundListener>();
  
  tuyaListener.onEmergencySent = (success, event) {
    if (success) {
      // Navigate to the SOS status page from anywhere in the app
      AppRouter.router.push('/sos-status');
    }
  };
  
  tuyaListener.onEmergencyError = (errorMsg) {
    debugPrint('SOS Trigger Error: $errorMsg');
  };
  
  await tuyaListener.start();
  
  runApp(const SahabatSosApp());
}
