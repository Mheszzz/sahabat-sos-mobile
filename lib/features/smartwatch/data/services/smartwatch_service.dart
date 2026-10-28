import 'dart:async';
import '../models/smartwatch_device_model.dart';
import '../models/smartwatch_event_model.dart';

abstract class SmartwatchService {
  String get protocolName;

  /// Memeriksa apakah protokol / hardware Bluetooth/Huawei didukung pada perangkat ini
  Future<bool> isSupported();

  /// Memulai pemindaian smartwatch di sekitar
  Future<void> startScan({Duration timeout = const Duration(seconds: 10)});

  /// Menghentikan pemindaian
  Future<void> stopScan();

  /// Aliran hasil pemindaian
  Stream<List<SmartwatchDeviceModel>> get scanResultsStream;

  /// Menyambungkan ke smartwatch
  Future<bool> connect(SmartwatchDeviceModel device);

  /// Memutus sambungan dari smartwatch
  Future<void> disconnect(String deviceId);

  /// Aliran event tombol darurat, deteksi jatuh, dan telemetri dari jam
  Stream<SmartwatchEventModel> get eventStream;

  /// Aliran detak jantung (BPM) langsung
  Stream<int> get heartRateStream;

  /// Mengirim getaran / konfirmasi feedback ke smartwatch setelah bantuan terkirim
  Future<void> sendFeedbackAlert(
    String deviceId, {
    required String title,
    required String message,
  });

  /// Bersihkan listener dan resource
  Future<void> dispose();
}
