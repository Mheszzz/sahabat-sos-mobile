class ApiConstants {
  // Gunakan IP komputer lokal (192.168.1.2) agar bisa diakses oleh HP Fisik di jaringan Wi-Fi yang sama
  static const String baseUrl = 'http://192.168.1.2:8000/api';
  
  static const String authGoogle = '$baseUrl/auth/google/mobile';
  static const String completeProfile = '$baseUrl/user/complete-profile';
  static const String me = '$baseUrl/user/me';
  
  static const String laporan = '$baseUrl/laporan';
}
