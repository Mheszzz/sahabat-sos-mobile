import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:sahabat_sos_mobile/app.dart';
import 'package:sahabat_sos_mobile/core/di/injection.dart';
import 'package:sahabat_sos_mobile/core/services/background_service.dart';
import 'package:sahabat_sos_mobile/core/widgets/permission_gate.dart';
import 'package:sahabat_sos_mobile/features/tuya_device/data/services/tuya_background_listener.dart';
import 'package:sahabat_sos_mobile/routing/app_router.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Meminta izin notifikasi untuk Android 13+ agar background service bisa tampil
  await Permission.notification.request();

  // Initialize Dependency Injection (GetIt)
  await initInjection();

  // Listen to Tuya in UI (foreground) to navigate when app is open
  final tuyaListener = GetIt.instance<TuyaBackgroundListener>();
  
  tuyaListener.onSosDetected = (event) {
    AppRouter.router.push('/sos-status');
  };

  // Start Background Service
  // (This will also start Tuya and WebSockets in the background isolate)
  await initializeBackgroundService();

  runApp(const PermissionGate(child: SahabatSosApp()));
}
