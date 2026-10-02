class ApiConstants {
  // Gunakan IP komputer lokal agar bisa diakses oleh HP Fisik di jaringan Wi-Fi yang sama
  static const String baseUrl = 'http://192.168.1.2:8000/api';
  static const String storageUrl = 'http://192.168.1.2:8000/storage';
  
  static const String authGoogle = '$baseUrl/auth/google/mobile';
  static const String authRegisterPengguna = '$baseUrl/auth/register/pengguna';
  static const String authRegisterRelawan = '$baseUrl/auth/register/relawan';
  static const String authLogin = '$baseUrl/auth/login';
  static const String sendOtp = '$baseUrl/auth/send-otp';
  static const String verifyOtp = '$baseUrl/auth/verify-otp';
  static const String completeProfile = '$baseUrl/user/complete-profile';
  static const String me = '$baseUrl/user/me';
  static const String updateLocation = '$baseUrl/user/update-location';
  static const String logout = '$baseUrl/logout';
  static const String beranda = '$baseUrl/beranda';
  
  static const String laporan = '$baseUrl/laporan';
  static String laporanDetail(dynamic id) => '$baseUrl/laporan/$id';
  static const String laporanOptions = '$baseUrl/laporan/options';
  
  static const String profile = '$baseUrl/pengguna/profile';
  static const String profileFoto = '$baseUrl/pengguna/profile/foto';
  
  static const String laporanNearby = '$baseUrl/laporan/nearby';
  static String laporanStatus(dynamic id) => '$baseUrl/laporan/$id/status';
  
  static const String sosUserHistory = '$baseUrl/sos/user/history';
  static String sosDetail(dynamic id) => '$baseUrl/sos/$id';

  static const String emergencyTrigger = '$baseUrl/sos/trigger';
  static const String emergencyActive = '$baseUrl/sos/active';
  static String emergencyCancel(dynamic id) => '$baseUrl/sos/$id/cancel';
  
  // Kontak Darurat Endpoints
  static const String kontakDarurat = '$baseUrl/pengguna/kontak-darurat';
  static String kontakDaruratDetail(dynamic id) => '$baseUrl/pengguna/kontak-darurat/$id';
  static String kontakDaruratToggle(dynamic id) => '$baseUrl/pengguna/kontak-darurat/$id/toggle-notif';
  
  // Volunteer / Relawan Endpoints
  static const String relawanProfile = '$baseUrl/relawan/profile';
  static const String sosActiveRelawan = '$baseUrl/sos/active/relawan';
  static const String sosRelawanTasks = '$baseUrl/sos/relawan/tasks';
  static String sosStatusUpdate(dynamic id) => '$baseUrl/sos/$id/status';
  static String sosReject(dynamic id) => '$baseUrl/sos/$id/reject';
  
  // Tuya Device
  static const String tuyaDeviceRegister = '$baseUrl/tuya-device/register';
  static const String tuyaDeviceList = '$baseUrl/tuya-device/list';
  
  static const String relawanLocationUpdate = '$baseUrl/relawan/location';
  static const String relawanBeranda = '$baseUrl/relawan/beranda';
}
