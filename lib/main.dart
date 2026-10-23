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
import 'package:sahabat_sos_mobile/features/tuya_device/data/services/emergency_trigger_service.dart';
import 'package:sahabat_sos_mobile/core/services/health_connect_service.dart';
import 'package:sahabat_sos_mobile/features/device/presentation/widgets/heart_rate_sos_dialog.dart';
import 'package:sahabat_sos_mobile/core/services/notification_service.dart';
import 'package:sahabat_sos_mobile/routing/app_router.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Meminta izin notifikasi untuk Android 13+ agar background service bisa tampil
  await Permission.notification.request();

  // Initialize Dependency Injection (GetIt)
  await initInjection();

  // Inisialisasi notifikasi untuk menangani banner alert dan klik notifikasi SOS
  final notificationService = NotificationService();
  await notificationService.init();
  final FlutterLocalNotificationsPlugin localNotif = FlutterLocalNotificationsPlugin();

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

  // Listen to Critical Heart Rate events from Health Connect (Huawei Band 7)
  final healthService = sl<HealthConnectService>();
  await healthService.init();

  healthService.onCriticalHeartRate = (record) {
    debugPrint('🚨 [Global] Critical Heart Rate triggered: ${record.bpm} BPM');
    final context = AppRouter.navigatorKey.currentContext;
    if (context != null) {
      HeartRateSosDialog.show(
        context,
        record: record,
        onConfirm: () async {
          try {
            await sl<EmergencyTriggerService>().triggerHeartRateEmergency(
              bpm: record.bpm,
              reason: record.statusLabel,
            );
            AppRouter.router.push('/sos-status');
          } catch (e) {
            debugPrint('Gagal mengirim SOS detak jantung: $e');
            AppRouter.router.push('/sos-status');
          }
        },
        onCancel: () {
          debugPrint('User membatalkan peringatan darurat detak jantung.');
        },
      );
    }
  };

  // Start Background Service
  // (This will also start Tuya and WebSockets in the background isolate)
  await initializeBackgroundService();

  runApp(const PermissionGate(child: SahabatSosApp()));
}
