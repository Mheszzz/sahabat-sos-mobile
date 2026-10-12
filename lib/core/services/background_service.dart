import 'dart:async';
import 'dart:ui';
import 'dart:typed_data';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:sahabat_sos_mobile/core/di/injection.dart';
import 'package:sahabat_sos_mobile/features/tuya_device/data/services/tuya_background_listener.dart';
import 'package:sahabat_sos_mobile/core/services/websocket_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> initializeBackgroundService() async {
  final service = FlutterBackgroundService();

  const AndroidNotificationChannel channel = AndroidNotificationChannel(
    'sos_background_channel', // id
    'Sahabat SOS Background Service', // title
    description: 'Menjaga aplikasi tetap berjalan untuk menerima sinyal darurat.', // description
    importance: Importance.low, // low importance so it doesn't ring constantly for the persistent notif
  );

  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  const AndroidInitializationSettings initializationSettingsAndroid =
      AndroidInitializationSettings('@mipmap/ic_launcher');
  const InitializationSettings initializationSettings =
      InitializationSettings(android: initializationSettingsAndroid);
  await flutterLocalNotificationsPlugin.initialize(settings: initializationSettings);

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
      initialNotificationContent: 'Mendengarkan sinyal darurat di latar belakang...',
      foregroundServiceNotificationId: 888,
    ),
    iosConfiguration: IosConfiguration(
      autoStart: true,
      onForeground: onStart,
      onBackground: onIosBackground,
    ),
  );
  
  service.startService();
}

@pragma('vm:entry-point')
Future<bool> onIosBackground(ServiceInstance service) async {
  WidgetsFlutterBinding.ensureInitialized();
  DartPluginRegistrant.ensureInitialized();
  return true;
}

@pragma('vm:entry-point')
void onStart(ServiceInstance service) async {
  DartPluginRegistrant.ensureInitialized();

  // Inisialisasi dependensi ulang karena ini berjalan di isolate (thread) berbeda
  await initInjection();

  final prefs = sl<SharedPreferences>();
  final token = prefs.getString('auth_token');
  final volunteerId = prefs.getInt('volunteer_id'); // Assume relawan ID is saved, check if it exists

  final FlutterLocalNotificationsPlugin localNotif = FlutterLocalNotificationsPlugin();
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
      .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
      ?.createNotificationChannel(alertChannel);

  // 1. Inisialisasi WebSocket untuk mendengarkan SOS masuk (jika relawan)
  if (token != null && token.isNotEmpty) {
    await WebsocketService.init(token);
    
    // Mendengarkan SOS Baru
    if (volunteerId != null) {
      WebsocketService.listenToNewSosForVolunteer(volunteerId, (payload) {
        // Tampilkan notifikasi saat SOS masuk
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
              vibrationPattern: Int64List.fromList([0, 1000, 500, 1000, 500, 1000]),
            ),
          ),
        );
      });
    }
  }

  // 2. Inisialisasi Tuya Listener untuk alat emergency (Tombol Fisik)
  final tuyaListener = sl<TuyaBackgroundListener>();
  
  tuyaListener.onSosDetected = (event) {
    debugPrint('Background SOS Detected: ${event.deviceId}');
  };

  tuyaListener.onEmergencySent = (success, event) {
    debugPrint('Background Emergency Sent: $success');
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
    debugPrint('Background Emergency Error: $errorMsg');
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

  await tuyaListener.start();

  // Listen to service stop command
  service.on('stopService').listen((event) {
    tuyaListener.stop();
    service.stopSelf();
  });
}
