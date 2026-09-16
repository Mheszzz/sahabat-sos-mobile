import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:sahabat_sos_mobile/app.dart';
import 'package:sahabat_sos_mobile/core/di/injection.dart';
import 'package:sahabat_sos_mobile/features/tuya_device/data/services/tuya_background_listener.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Dependency Injection (GetIt)
  await initInjection();

  // Start Tuya background listener for SOS events
  // Will only activate if user is already authenticated
  final tuyaListener = GetIt.instance<TuyaBackgroundListener>();
  await tuyaListener.start();
  
  runApp(const SahabatSosApp());
}
