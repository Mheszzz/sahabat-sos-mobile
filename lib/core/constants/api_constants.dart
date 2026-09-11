class ApiConstants {
  // Gunakan IP komputer lokal agar bisa diakses oleh HP Fisik di jaringan Wi-Fi yang sama
  static const String baseUrl = 'http://192.168.110.91:8000/api';
  
  static const String authGoogle = '$baseUrl/auth/google/mobile';
  static const String authRegister = '$baseUrl/auth/register';
  static const String authLogin = '$baseUrl/auth/login';
  static const String sendOtp = '$baseUrl/auth/send-otp';
  static const String verifyOtp = '$baseUrl/auth/verify-otp';
  static const String completeProfile = '$baseUrl/user/complete-profile';
  static const String me = '$baseUrl/user/me';
  static const String updateLocation = '$baseUrl/user/update-location';
  static const String logout = '$baseUrl/logout';
  static const String beranda = '$baseUrl/beranda';
  
  static const String laporan = '$baseUrl/laporan';
  static const String laporanOptions = '$baseUrl/laporan/options';
}
