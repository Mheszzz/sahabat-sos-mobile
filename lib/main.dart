import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:sahabat_sos_mobile/app.dart';
import 'package:sahabat_sos_mobile/core/di/injection.dart';
import 'package:sahabat_sos_mobile/core/services/background_service.dart';
import 'package:sahabat_sos_mobile/core/utils/global_event_bus.dart';
import 'package:sahabat_sos_mobile/core/widgets/permission_gate.dart';
import 'package:sahabat_sos_mobile/features/tuya_device/data/services/tuya_background_listener.dart';
import 'package:sahabat_sos_mobile/routing/app_router.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Meminta izin notifikasi untuk Android 13+ agar background service bisa tampil
  await Permission.notification.request();

  // Initialize Dependency Injection (GetIt)
  await initInjection();

  // Inisialisasi notifikasi untuk menangani klik notifikasi SOS
  final FlutterLocalNotificationsPlugin localNotif = FlutterLocalNotificationsPlugin();
  const AndroidInitializationSettings initializationSettingsAndroid =
      AndroidInitializationSettings('@mipmap/ic_launcher');
  const InitializationSettings initializationSettings =
      InitializationSettings(android: initializationSettingsAndroid);
      
  await localNotif.initialize(
    settings: initializationSettings,
    onDidReceiveNotificationResponse: (NotificationResponse response) {
      if (response.payload != null && response.payload!.isNotEmpty) {
        try {
          final sosData = jsonDecode(response.payload!);
          GlobalEventBus.showSosAssignmentPopup.value = sosData;
        } catch (e) {
          debugPrint('Error parsing notification payload: $e');
        }
      }
    },
  );

  // Cek apakah aplikasi diluncurkan (cold start) dari klik notifikasi
  final NotificationAppLaunchDetails? launchDetails =
      await localNotif.getNotificationAppLaunchDetails();
  if (launchDetails?.didNotificationLaunchApp ?? false) {
    final payload = launchDetails!.notificationResponse?.payload;
    if (payload != null && payload.isNotEmpty) {
      try {
        final sosData = jsonDecode(payload);
        // Delay sedikit agar frame pertama selesai dirender sebelum menampilkan popup
        Future.delayed(const Duration(seconds: 1), () {
          GlobalEventBus.showSosAssignmentPopup.value = sosData;
        });
      } catch (e) {
        debugPrint('Error parsing initial notification payload: $e');
      }
    }
  }

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
