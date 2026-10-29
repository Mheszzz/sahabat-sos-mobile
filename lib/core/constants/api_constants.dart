class ApiConstants {
  // Gunakan IP default jika tidak ada environment atau runtime override
  // Default ke IP Tailscale backend (100.105.166.45:8000)
  static const String defaultBaseUrl = 'http://100.105.166.45:8000/api';
  static const String defaultStorageUrl = 'http://100.105.166.45:8000/storage';

  // Mendukung String.fromEnvironment:
  // e.g. flutter run --dart-define=API_BASE_URL=http://100.105.166.45:8000/api
  // atau flutter run --dart-define-from-file=.env
  static const String _envBaseUrl = String.fromEnvironment('API_BASE_URL');
  static const String _altEnvBaseUrl = String.fromEnvironment('BASE_URL');
  static const String _envStorageUrl = String.fromEnvironment('STORAGE_URL');

  // Override runtime fleksibel jika ingin diatur secara dinamis melalui config / .env file
  static String? _customBaseUrl;
  static String? _customStorageUrl;

  /// Mengatur baseUrl secara runtime (misalnya dari file konfigurasi .env atau preferensi pengguna)
  static void setBaseUrl(String url, {String? customStorageUrl}) {
    final cleanUrl = url.trim().replaceAll(RegExp(r'/+$'), '');
    _customBaseUrl = cleanUrl.endsWith('/api') ? cleanUrl : '$cleanUrl/api';

    if (customStorageUrl != null && customStorageUrl.trim().isNotEmpty) {
      _customStorageUrl = customStorageUrl.trim().replaceAll(RegExp(r'/+$'), '');
    } else {
      final root = _customBaseUrl!.replaceAll(RegExp(r'/api$'), '');
      _customStorageUrl = '$root/storage';
    }
  }

  static String _stripQuotes(String value) {
    final v = value.trim();
    if ((v.startsWith('"') && v.endsWith('"')) ||
        (v.startsWith("'") && v.endsWith("'"))) {
      if (v.length >= 2) {
        return v.substring(1, v.length - 1).trim();
      }
    }
    return v;
  }

  /// Membaca konfigurasi dari string file .env (format KEY=VALUE)
  static void loadFromEnvString(String envContent) {
    for (final line in envContent.split('\n')) {
      final trimmed = line.trim();
      if (trimmed.isEmpty || trimmed.startsWith('#')) continue;
      final parts = trimmed.split('=');
      if (parts.length >= 2) {
        final key = parts[0].trim();
        final rawVal = parts.sublist(1).join('=');
        final value = _stripQuotes(rawVal);
        if (key == 'API_BASE_URL' || key == 'BASE_URL') {
          setBaseUrl(value);
        } else if (key == 'STORAGE_URL') {
          _customStorageUrl = value;
        }
      }
    }
  }

  /// Base URL aktif (prioritas: runtime override -> --dart-define/env -> default)
  static String get baseUrl {
    if (_customBaseUrl != null && _customBaseUrl!.isNotEmpty) {
      return _customBaseUrl!;
    }
    if (_envBaseUrl.isNotEmpty) {
      return _envBaseUrl;
    }
    if (_altEnvBaseUrl.isNotEmpty) {
      return _altEnvBaseUrl;
    }
    return defaultBaseUrl;
  }

  /// Storage URL aktif (prioritas: runtime override -> --dart-define/env -> turunan baseUrl -> default)
  static String get storageUrl {
    if (_customStorageUrl != null && _customStorageUrl!.isNotEmpty) {
      return _customStorageUrl!;
    }
    if (_envStorageUrl.isNotEmpty) {
      return _envStorageUrl;
    }
    if (baseUrl != defaultBaseUrl) {
      final root = baseUrl.replaceAll(RegExp(r'/api$'), '');
      return '$root/storage';
    }
    return defaultStorageUrl;
  }

  static String get authGoogle => '$baseUrl/auth/google/mobile';
  static String get authRegisterPengguna => '$baseUrl/auth/register/pengguna';
  static String get authRegisterRelawan => '$baseUrl/auth/register/relawan';
  static String get authLogin => '$baseUrl/auth/login';
  static String get sendOtp => '$baseUrl/auth/send-otp';
  static String get verifyOtp => '$baseUrl/auth/verify-otp';
  static String get completeProfile => '$baseUrl/user/complete-profile';
  static String get me => '$baseUrl/user/me';
  static String get updateLocation => '$baseUrl/user/update-location';
  static String get logout => '$baseUrl/logout';
  static String get beranda => '$baseUrl/beranda';

  static String get laporan => '$baseUrl/laporan';
  static String laporanDetail(dynamic id) => '$baseUrl/laporan/$id';
  static String get laporanOptions => '$baseUrl/laporan/options';

  static String get profile => '$baseUrl/pengguna/profile';
  static String get profileFoto => '$baseUrl/pengguna/profile/foto';

  static String get laporanNearby => '$baseUrl/laporan/nearby';
  static String laporanStatus(dynamic id) => '$baseUrl/laporan/$id/status';

  static String get sosUserHistory => '$baseUrl/sos/user/history';
  static String sosDetail(dynamic id) => '$baseUrl/sos/$id';
  static String sosActivities(dynamic id) => '$baseUrl/sos/$id/activities';

  static String get emergencyTrigger => '$baseUrl/sos/trigger';
  static String get emergencyActive => '$baseUrl/sos/active';
  static String emergencyCancel(dynamic id) => '$baseUrl/sos/$id/cancel';

  // Kontak Darurat Endpoints
  static String get kontakDarurat => '$baseUrl/pengguna/kontak-darurat';
  static String kontakDaruratDetail(dynamic id) =>
      '$baseUrl/pengguna/kontak-darurat/$id';
  static String kontakDaruratToggle(dynamic id) =>
      '$baseUrl/pengguna/kontak-darurat/$id/toggle-notif';

  static String hubungiKontakDaruratTask(String tipe, dynamic id) =>
      '$baseUrl/tugas-aktif/$tipe/$id/hubungi-kontak-darurat';

  static String relawanChatWa(String tipe, dynamic id) =>
      '$baseUrl/relawan/chat-wa/$tipe/$id';

  // Volunteer / Relawan Endpoints
  static String get relawanProfile => '$baseUrl/relawan/profile';
  static String get sosActiveRelawan => '$baseUrl/sos/active/relawan';
  static String get sosRelawanTasks => '$baseUrl/sos/relawan/tasks';
  static String sosStatusUpdate(dynamic id) => '$baseUrl/sos/$id/status';
  static String sosReject(dynamic id) => '$baseUrl/sos/$id/reject';
  static String get relawanStatusKetersediaan =>
      '$baseUrl/relawan/status-ketersediaan';
  static String get relawanBeranda => '$baseUrl/relawan/beranda';

  // Tuya Device
  static String get tuyaDeviceRegister => '$baseUrl/tuya-device/register';
  static String get tuyaDeviceList => '$baseUrl/tuya-device/list';

  // Smartwatch Endpoints
  static String get smartwatchList => '$baseUrl/pengguna/smartwatch';
  static String get smartwatchRegister => '$baseUrl/pengguna/smartwatch';
  static String smartwatchDetail(dynamic id) => '$baseUrl/pengguna/smartwatch/$id';
  static String smartwatchTelemetry(dynamic id) => '$baseUrl/pengguna/smartwatch/$id/sync-telemetry';

  static String get relawanLocationUpdate => '$baseUrl/relawan/location';
  // Riwayat / History Endpoints
  static String get riwayatPengguna => '$baseUrl/pengguna/riwayat';
  static String get riwayatRelawan => '$baseUrl/relawan/riwayat';
  static String get tugasRelawan => '$baseUrl/relawan/tugas';
}
