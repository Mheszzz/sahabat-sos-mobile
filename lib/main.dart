import 'dart:async';
import 'dart:convert';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:sahabat_sos_mobile/app.dart';
import 'package:sahabat_sos_mobile/core/di/injection.dart';
import 'package:sahabat_sos_mobile/core/services/background_service.dart';
import 'package:sahabat_sos_mobile/core/utils/global_event_bus.dart';
import 'package:sahabat_sos_mobile/core/widgets/permission_gate.dart';
import 'package:sahabat_sos_mobile/features/tuya_device/data/services/tuya_background_listener.dart';
import 'package:sahabat_sos_mobile/core/services/notification_service.dart';
import 'package:sahabat_sos_mobile/core/services/health_connect_service.dart';
import 'package:sahabat_sos_mobile/features/device/presentation/widgets/heart_rate_sos_dialog.dart';
import 'package:sahabat_sos_mobile/features/tuya_device/data/services/emergency_trigger_service.dart';
import 'package:sahabat_sos_mobile/routing/app_router.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Menangkap unhandled Flutter errors agar tidak force close di release mode
  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
    debugPrint('🚨 Flutter Error caught: ${details.exception}');
  };
  PlatformDispatcher.instance.onError = (error, stack) {
    debugPrint('🚨 Uncaught Platform Error: $error\n$stack');
    return true; // Cegah app force close
  };

  try {
    await initInjection();
  } catch (e) {
    debugPrint('initInjection error di main: $e');
  }

  // Inisialisasi notifikasi untuk menangani banner alert dan klik notifikasi SOS
  try {
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
  } catch (e) {
    debugPrint('NotificationService init error di main: $e');
  }

  // Listen to Tuya in UI (foreground) to navigate when app is open
  try {
    final tuyaListener = GetIt.instance<TuyaBackgroundListener>();
    tuyaListener.onSosDetected = (event) {
      AppRouter.router.push('/sos-status');
    };
  } catch (e) {
    debugPrint('TuyaListener error di main: $e');
  }

  // Inisialisasi Health Connect Service & Background Monitoring
  try {
    final healthService = sl<HealthConnectService>();
    await healthService.init();

    // Listener global jika detak jantung mencapai status kritis (< 45 atau > 130 BPM)
    healthService.onCriticalHeartRate = (record) {
      final context = AppRouter.navigatorKey.currentContext;
      if (context != null) {
        HeartRateSosDialog.show(
          context,
          record: record,
          onConfirm: () async {
            try {
              final emergencyService = sl<EmergencyTriggerService>();
              await emergencyService.triggerHeartRateEmergency(
                bpm: record.bpm,
                reason:
                    'Deteksi otomatis detak jantung kritis: ${record.bpm} BPM',
              );
              if (context.mounted) {
                unawaited(AppRouter.router.push('/sos-status'));
              }
            } catch (e) {
              debugPrint('Gagal mengirim SOS detak jantung: $e');
            }
          },
          onCancel: () {
            debugPrint('SOS detak jantung dibatalkan oleh pengguna.');
          },
        );
      }
    };
  } catch (e) {
    debugPrint('HealthConnect init error di main: $e');
  }

  // Start Background Service
  // (This will also start Tuya and WebSockets in the background isolate)
  try {
    await initializeBackgroundService();
  } catch (e) {
    debugPrint('initializeBackgroundService error di main: $e');
  }

  runApp(const PermissionGate(child: SahabatSosApp()));
}
