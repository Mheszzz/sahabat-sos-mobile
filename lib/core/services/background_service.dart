import 'dart:async';
import 'dart:ui';
import 'dart:typed_data';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:sahabat_sos_mobile/core/di/injection.dart';
import 'package:sahabat_sos_mobile/features/tuya_device/data/services/tuya_background_listener.dart';
import 'package:sahabat_sos_mobile/features/smartwatch/data/services/smartwatch_background_listener.dart';
import 'package:sahabat_sos_mobile/core/services/websocket_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> initializeBackgroundService() async {
  final service = FlutterBackgroundService();

  const AndroidNotificationChannel channel = AndroidNotificationChannel(
    'sos_background_channel',
    'Sahabat SOS Background Service',
    description: 'Menjaga aplikasi tetap berjalan untuk menerima sinyal darurat.',
    importance: Importance.low,
  );

  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  const AndroidInitializationSettings initializationSettingsAndroid =
      AndroidInitializationSettings('@mipmap/ic_launcher');
  const InitializationSettings initializationSettings =
      InitializationSettings(android: initializationSettingsAndroid);
  await flutterLocalNotificationsPlugin.initialize(
    settings: initializationSettings,
  );

  await flutterLocalNotificationsPlugin
      .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>()
      ?.createNotificationChannel(channel);

  await service.configure(
    androidConfiguration: AndroidConfiguration(
      onStart: onStart,
      autoStart: true,
      isForegroundMode: true,
      notificationChannelId: 'sos_background_channel',
      initialNotificationTitle: 'Sahabat SOS Aktif',
      initialNotificationContent:
          'Mendengarkan sinyal darurat di latar belakang...',
      foregroundServiceNotificationId: 888,
    ),
    iosConfiguration: IosConfiguration(
      autoStart: true,
      onForeground: onStart,
      onBackground: onIosBackground,
    ),
  );

  await service.startService();
}

@pragma('vm:entry-point')
Future<bool> onIosBackground(ServiceInstance service) async {
  WidgetsFlutterBinding.ensureInitialized();
  DartPluginRegistrant.ensureInitialized();
  return true;
}

@pragma('vm:entry-point')
void onStart(ServiceInstance service) async {
  WidgetsFlutterBinding.ensureInitialized();
  DartPluginRegistrant.ensureInitialized();

  await initInjection();

  final prefs = sl<SharedPreferences>();
  await prefs.reload();
  final token = prefs.getString('auth_token');
  final volunteerId = prefs.getInt('volunteer_id');

  final FlutterLocalNotificationsPlugin localNotif =
      FlutterLocalNotificationsPlugin();
  final alertChannel = AndroidNotificationChannel(
    'sos_alert_channel_v2',
    'Peringatan Darurat SOS',
    description: 'Notifikasi saat ada panggilan SOS masuk',
    importance: Importance.max,
    enableVibration: true,
    vibrationPattern: Int64List.fromList([0, 1000, 500, 1000, 500, 1000]),
  );

  const AndroidInitializationSettings initializationSettingsAndroid =
      AndroidInitializationSettings('@mipmap/ic_launcher');
  const InitializationSettings initializationSettings =
      InitializationSettings(android: initializationSettingsAndroid);
  await localNotif.initialize(settings: initializationSettings);

  await localNotif
      .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>()
      ?.createNotificationChannel(alertChannel);

  // 1. Inisialisasi WebSocket untuk mendengarkan SOS masuk (jika relawan)
  if (token != null && token.isNotEmpty) {
    try {
      await WebsocketService.init(token);

      if (volunteerId != null) {
        WebsocketService.listenToNewSosForVolunteer(volunteerId, (payload) {
          localNotif.show(
            id: 999,
            title: 'DARURAT: Bantuan Dibutuhkan!',
            body: 'Ada panggilan darurat baru di sekitar Anda.',
            payload: jsonEncode(payload),
            notificationDetails: NotificationDetails(
              android: AndroidNotificationDetails(
                'sos_alert_channel_v2',
                'Peringatan Darurat SOS',
                importance: Importance.max,
                priority: Priority.high,
                fullScreenIntent: true,
                enableVibration: true,
                vibrationPattern:
                    Int64List.fromList([0, 1000, 500, 1000, 500, 1000]),
              ),
            ),
          );
        });
      }
    } catch (e) {
      debugPrint('Background WebSocket init error: $e');
    }
  }

  // 2. Inisialisasi Tuya Listener
  final tuyaListener = sl<TuyaBackgroundListener>();
  tuyaListener.onSosDetected = (event) {
    debugPrint('Background SOS Detected: ${event.deviceId}');
  };

  tuyaListener.onEmergencySent = (success, event) {
    if (success) {
      localNotif.show(
        id: 1000,
        title: 'SOS Darurat Terkirim!',
        body: 'Permintaan bantuan Anda sedang diproses dan dikirim ke relawan.',
        notificationDetails: const NotificationDetails(
          android: AndroidNotificationDetails(
            'sos_alert_channel_v2',
            'Peringatan Darurat SOS',
            importance: Importance.max,
            priority: Priority.high,
          ),
        ),
      );
    }
  };

  tuyaListener.onEmergencyError = (errorMsg) {
    localNotif.show(
      id: 1001,
      title: 'Gagal Mengirim SOS',
      body: 'Terjadi kesalahan: $errorMsg',
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          'sos_alert_channel_v2',
          'Peringatan Darurat SOS',
          importance: Importance.high,
          priority: Priority.high,
        ),
      ),
    );
  };

  try {
    await tuyaListener.start();
  } catch (e) {
    debugPrint('TuyaBackgroundListener skip di background isolate: $e');
  }

  // 3. Inisialisasi Smartwatch Listener
  final smartwatchListener = sl<SmartwatchBackgroundListener>();

  smartwatchListener.onSosDetected = (event) {
    debugPrint('Background Smartwatch SOS Detected: ${event.deviceId}');
  };

  smartwatchListener.onEmergencySent = (success, event) {
    if (success) {
      localNotif.show(
        id: 1002,
        title: 'SOS Smartwatch Terkirim!',
        body: 'Sinyal darurat dari jam tangan Anda telah diteruskan ke relawan.',
        notificationDetails: const NotificationDetails(
          android: AndroidNotificationDetails(
            'sos_alert_channel_v2',
            'Peringatan Darurat SOS',
            importance: Importance.max,
            priority: Priority.high,
          ),
        ),
      );
    }
  };

  smartwatchListener.onEmergencyError = (errorMsg) {
    localNotif.show(
      id: 1003,
      title: 'Gagal Mengirim SOS Smartwatch',
      body: 'Terjadi kesalahan: $errorMsg',
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          'sos_alert_channel_v2',
          'Peringatan Darurat SOS',
          importance: Importance.high,
          priority: Priority.high,
        ),
      ),
    );
  };

  // Catatan: Hindari memanggil smartwatchListener.start() di background isolate
  // secara bersamaan saat UI utama sedang aktif karena BLE GATT tidak bisa
  // dikoneksi dari 2 isolate sekaligus. Gunakan listener di UI isolate (SmartwatchManager)
  // dan panggil callback notifikasi ketika event darurat diterima.
  service.on('stopService').listen((event) {
    tuyaListener.stop();
    smartwatchListener.stop();
    service.stopSelf();
  });
}