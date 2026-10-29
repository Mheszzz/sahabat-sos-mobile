import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:health/health.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum HeartRateStatus {
  normal, // 60 - 100 BPM
  warning, // 101 - 130 BPM (Cemas / Kelelahan)
  critical, // > 130 BPM atau < 45 BPM (Kritis / Potensi Serangan Jantung / Panik Akut)
  unknown,
}

class HeartRateRecord {
  final int bpm;
  final DateTime timestamp;
  final HeartRateStatus status;

  const HeartRateRecord({
    required this.bpm,
    required this.timestamp,
    required this.status,
  });

  String get statusLabel {
    switch (status) {
      case HeartRateStatus.normal:
        return 'Normal';
      case HeartRateStatus.warning:
        return 'Waspada (Tinggi)';
      case HeartRateStatus.critical:
        return bpm < 45 ? 'Bahaya (Terlalu Rendah)' : 'Bahaya (Terlalu Tinggi)';
      case HeartRateStatus.unknown:
        return 'Tidak Diketahui';
    }
  }

  @override
  String toString() => 'HeartRateRecord($bpm BPM, status: $statusLabel, at: $timestamp)';
}

/// Service to integrate with Android Health Connect for Huawei Band 7
/// (and any smartband syncing through Health Connect).
class HealthConnectService {
  static final HealthConnectService _instance = HealthConnectService._internal();
  factory HealthConnectService() => _instance;
  HealthConnectService._internal();

  final Health _health = Health();
  Timer? _pollingTimer;

  static const List<HealthDataType> _types = [
    HealthDataType.HEART_RATE,
  ];

  static const List<HealthDataAccess> _permissions = [
    HealthDataAccess.READ,
  ];

  // SharedPreferences keys
  static const String _prefAutoMonitorKey = 'health_connect_auto_monitor';
  static const String _prefLastKnownBpmKey = 'health_connect_last_bpm';
  static const String _prefConnectedDeviceKey = 'health_connect_device_name';

  static const MethodChannel _platformChannel =
      MethodChannel('com.sahabatsos.app/tuya_method');

  // State Notifiers
  final ValueNotifier<int?> currentBpm = ValueNotifier<int?>(null);
  final ValueNotifier<HeartRateStatus> currentStatus =
      ValueNotifier<HeartRateStatus>(HeartRateStatus.unknown);
  final ValueNotifier<DateTime?> lastSampleTime = ValueNotifier<DateTime?>(null);
  final ValueNotifier<bool> isMonitoring = ValueNotifier<bool>(false);
  final ValueNotifier<bool> hasPermission = ValueNotifier<bool>(false);
  final ValueNotifier<HealthConnectSdkStatus?> sdkStatus =
      ValueNotifier<HealthConnectSdkStatus?>(null);
  final ValueNotifier<String> connectedDeviceName =
      ValueNotifier<String>('Smartband');

  // Callbacks
  void Function(HeartRateRecord record)? onCriticalHeartRate;
  void Function(HeartRateRecord record)? onHeartRateUpdated;

  DateTime? _lastCriticalTriggerTime;
  static const Duration _criticalCooldown = Duration(seconds: 45);

  /// Helper untuk mengevaluasi status detak jantung
  static HeartRateStatus evaluateStatus(int bpm) {
    if (bpm <= 0) return HeartRateStatus.unknown;
    if (bpm < 45 || bpm > 130) return HeartRateStatus.critical;
    if (bpm > 100) return HeartRateStatus.warning;
    return HeartRateStatus.normal;
  }

  /// 1. Konfigurasi awal & Cek Ketersediaan Health Connect
  Future<bool> init() async {
    try {
      await _health.configure();
      final status = await _health.getHealthConnectSdkStatus();
      sdkStatus.value = status;
      debugPrint('🏥 HealthConnect SDK Status: $status');

      final permitted = await checkPermission();
      hasPermission.value = permitted;

      // Restore last known BPM from prefs
      final prefs = await SharedPreferences.getInstance();
      final savedBpm = prefs.getInt(_prefLastKnownBpmKey);
      if (savedBpm != null && currentBpm.value == null) {
        currentBpm.value = savedBpm;
        currentStatus.value = evaluateStatus(savedBpm);
      }

      // Restore last known device name or detect from Bluetooth
      final savedDeviceName = prefs.getString(_prefConnectedDeviceKey);
      if (savedDeviceName != null && savedDeviceName.isNotEmpty) {
        connectedDeviceName.value = savedDeviceName;
      }
      unawaited(detectConnectedDeviceName());

      // Check if auto monitoring was enabled previously
      final autoMonitor = prefs.getBool(_prefAutoMonitorKey) ?? false;
      if (autoMonitor && permitted) {
        unawaited(startMonitoring());
      }

      return status == HealthConnectSdkStatus.sdkAvailable;
    } catch (e) {
      debugPrint('🏥 HealthConnect init error: $e');
      return false;
    }
  }

  /// 2. Buka Instalasi Health Connect jika belum ada di HP pengguna
  Future<void> installHealthConnect() async {
    try {
      await _health.installHealthConnect();
    } catch (e) {
      debugPrint('🏥 HealthConnect install error: $e');
    }
  }

  /// 3. Cek apakah izin baca detak jantung sudah diberikan
  Future<bool> checkPermission() async {
    try {
      final permitted = await _health.hasPermissions(
            _types,
            permissions: _permissions,
          ) ??
          false;
      hasPermission.value = permitted;
      return permitted;
    } catch (e) {
      debugPrint('🏥 HealthConnect checkPermission error: $e');
      return false;
    }
  }

  /// 4. Meminta Izin Akses Pengguna ke Health Connect
  Future<bool> requestHeartRatePermission() async {
    try {
      final permitted = await _health.requestAuthorization(
        _types,
        permissions: _permissions,
      );
      hasPermission.value = permitted;
      if (permitted) {
        await fetchLatestHeartRate();
      }
      return permitted;
    } catch (e) {
      debugPrint('🏥 HealthConnect requestPermission error: $e');
      return false;
    }
  }

  /// 5. Mengambil Sampel Detak Jantung Terbaru (Latest Heart Rate)
  Future<HeartRateRecord?> fetchLatestHeartRate({
    Duration lookback = const Duration(minutes: 30),
  }) async {
    try {
      final now = DateTime.now();
      var startTime = now.subtract(lookback);

      List<HealthDataPoint> healthData = await _health.getHealthDataFromTypes(
        types: _types,
        startTime: startTime,
        endTime: now,
      );

      // Jika data kosong dalam rentang lookback, coba cek hingga 24 jam terakhir
      if (healthData.isEmpty) {
        startTime = now.subtract(const Duration(hours: 24));
        healthData = await _health.getHealthDataFromTypes(
          types: _types,
          startTime: startTime,
          endTime: now,
        );
      }

      healthData = _health.removeDuplicates(healthData);

      if (healthData.isNotEmpty) {
        // Urutkan dari yang paling baru
        healthData.sort((a, b) => b.dateTo.compareTo(a.dateTo));
        final latestPoint = healthData.first;

        if (latestPoint.value is NumericHealthValue) {
          final numericVal = latestPoint.value as NumericHealthValue;
          final bpm = numericVal.numericValue.round();
          final status = evaluateStatus(bpm);
          final record = HeartRateRecord(
            bpm: bpm,
            timestamp: latestPoint.dateTo,
            status: status,
          );

          currentBpm.value = bpm;
          currentStatus.value = status;
          lastSampleTime.value = latestPoint.dateTo;

          // Simpan ke SharedPreferences
          final prefs = await SharedPreferences.getInstance();
          await prefs.setInt(_prefLastKnownBpmKey, bpm);

          onHeartRateUpdated?.call(record);

          // Cek ambang batas kritis
          if (status == HeartRateStatus.critical) {
            _checkAndTriggerCritical(record);
          }

          return record;
        }
      }
    } catch (e) {
      debugPrint('🏥 Gagal mengambil data detak jantung: $e');
    }
    return null;
  }

  /// 6. Mengambil Riwayat Detak Jantung untuk Grafik / Log
  Future<List<HeartRateRecord>> getRecentHistory({
    Duration duration = const Duration(hours: 12),
  }) async {
    try {
      final now = DateTime.now();
      final startTime = now.subtract(duration);

      List<HealthDataPoint> points = await _health.getHealthDataFromTypes(
        types: _types,
        startTime: startTime,
        endTime: now,
      );

      points = _health.removeDuplicates(points);
      points.sort((a, b) => a.dateTo.compareTo(b.dateTo));

      return points
          .where((p) => p.value is NumericHealthValue)
          .map((p) {
            final val = (p.value as NumericHealthValue).numericValue.round();
            return HeartRateRecord(
              bpm: val,
              timestamp: p.dateTo,
              status: evaluateStatus(val),
            );
          })
          .toList();
    } catch (e) {
      debugPrint('🏥 Gagal mengambil riwayat detak jantung: $e');
      return [];
    }
  }

  /// 7. Mulai Pemantauan Berkala (Continuous Polling)
  Future<void> startMonitoring({
    Duration interval = const Duration(seconds: 15),
  }) async {
    if (isMonitoring.value) return;

    isMonitoring.value = true;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefAutoMonitorKey, true);

    // Fetch segera
    await fetchLatestHeartRate();

    // Jalankan timer polling berkala
    _pollingTimer?.cancel();
    _pollingTimer = Timer.periodic(interval, (_) async {
      await fetchLatestHeartRate();
    });

    debugPrint('🏥 HealthConnect monitoring dimulai (interval: ${interval.inSeconds}s)');
  }

  /// 8. Hentikan Pemantauan Berkala
  Future<void> stopMonitoring() async {
    _pollingTimer?.cancel();
    _pollingTimer = null;
    isMonitoring.value = false;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefAutoMonitorKey, false);

    debugPrint('🏥 HealthConnect monitoring dihentikan');
  }

  /// 9. Simulasi Detak Jantung (Untuk Pengujian & QA)
  void simulateBpm(int bpm) {
    final status = evaluateStatus(bpm);
    final record = HeartRateRecord(
      bpm: bpm,
      timestamp: DateTime.now(),
      status: status,
    );
    currentBpm.value = bpm;
    currentStatus.value = status;
    lastSampleTime.value = DateTime.now();
    onHeartRateUpdated?.call(record);

    if (status == HeartRateStatus.critical) {
      _checkAndTriggerCritical(record);
    }
  }

  /// Evaluasi dan picu alert darurat dengan debounce/cooldown
  void _checkAndTriggerCritical(HeartRateRecord record) {
    final now = DateTime.now();
    if (_lastCriticalTriggerTime != null &&
        now.difference(_lastCriticalTriggerTime!) < _criticalCooldown) {
      debugPrint('🏥 Critical heart rate in cooldown period, ignoring: ${record.bpm} BPM');
      return;
    }

    _lastCriticalTriggerTime = now;
    debugPrint('🚨 DETEKSI DETAK JANTUNG KRITIS: ${record.bpm} BPM!');
    onCriticalHeartRate?.call(record);
  }

  void dispose() {
    _pollingTimer?.cancel();
    currentBpm.dispose();
    currentStatus.dispose();
    lastSampleTime.dispose();
    isMonitoring.dispose();
    hasPermission.dispose();
    sdkStatus.dispose();
    connectedDeviceName.dispose();
  }

  /// 10. Deteksi Nama Smartwatch/Smartband dari Perangkat Bluetooth Terhubung
  Future<String> detectConnectedDeviceName() async {
    try {
      final dynamic rawName =
          await _platformChannel.invokeMethod('getConnectedSmartbandName');
      if (rawName is String && rawName.trim().isNotEmpty) {
        final formattedName = _formatDeviceName(rawName.trim());
        connectedDeviceName.value = formattedName;

        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_prefConnectedDeviceKey, formattedName);

        debugPrint('⌚ Terdeteksi Smartwatch/Smartband: $formattedName');
        return formattedName;
      }
    } catch (e) {
      debugPrint('⌚ Gagal deteksi nama Smartband Bluetooth: $e');
    }

    // Jika belum tersimpan, default ke 'Smartband'
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_prefConnectedDeviceKey) ?? 'Smartband';
    connectedDeviceName.value = saved;
    return saved;
  }

  /// Helper untuk membersihkan suffix MAC address atau angka acak pabrikan jika ada
  String _formatDeviceName(String raw) {
    // Misalnya "HUAWEI Band 7-4E2" -> "HUAWEI Band 7"
    final regex = RegExp(r'^(.+?)(?:-[0-9A-Fa-f]{3,4})?$');
    final match = regex.firstMatch(raw);
    if (match != null && match.group(1) != null) {
      return match.group(1)!.trim();
    }
    return raw;
  }
}
