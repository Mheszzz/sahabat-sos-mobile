import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/constants/api_constants.dart';

abstract class AuthRemoteDataSource {
  /// Mengembalikan Map berisi token JWT dan status is_profile_complete, atau null jika dibatalkan
  Future<Map<String, dynamic>?> signInWithGoogle();
  Future<Map<String, dynamic>> registerWithEmail({
    required String name,
    required String email,
    required String password,
    required String role,
  });
  Future<Map<String, dynamic>> loginWithEmail({
    required String email,
    required String password,
  });
  Future<Map<String, dynamic>> sendOtp({required String email});
  Future<Map<String, dynamic>> verifyOtp({
    required String email,
    required String otp,
  });
}

class AuthRemoteDataSourceImpl implements AuthRemoteDataSource {
  final Dio dio;
  final SharedPreferences prefs;

  final GoogleSignIn _googleSignIn = GoogleSignIn(
    // Di Android, clientId HARUS null (Google Play Services mendeteksi via Package Name + SHA-1)
    clientId: kIsWeb
        ? '757209543690-bpjk959q2se7oq0eos1olm6urg35oicp.apps.googleusercontent.com'
        : null,
    // Server Client ID (WAJIB Web Client ID) agar Android bisa minta Token/idToken ke backend
    serverClientId:
        '757209543690-bpjk959q2se7oq0eos1olm6urg35oicp.apps.googleusercontent.com',
    scopes: ['email', 'profile'],
  );

  AuthRemoteDataSourceImpl({required this.dio, required this.prefs});

  @override
  Future<Map<String, dynamic>?> signInWithGoogle() async {
    try {
      // Pastikan tidak ada sesi yang nyangkut
      try {
        await _googleSignIn.signOut();
      } catch (_) {}

      // 1. Munculkan dialog Google Sign In (di v6 ini cuma 1x dialog)
      debugPrint("=== [DEBUG] Menampilkan dialog Google Sign-In ===");
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();

      if (googleUser == null) {
        debugPrint("=== [DEBUG] googleUser NULL (user membatalkan atau config salah) ===");
        throw Exception(
          'User membatalkan dialog Google Sign-In atau konfigurasi salah.',
        );
      }
      debugPrint("=== [DEBUG] Akun dipilih: ${googleUser.email} ===");

      // 2. Ambil token (accessToken / idToken)
      debugPrint("=== [DEBUG] Meminta googleUser.authentication... ===");
      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      debugPrint("=== [DEBUG] Google Sign-In Berhasil Didapat ===");
      debugPrint("accessToken: ${googleAuth.accessToken != null ? 'ADA' : 'NULL'}");
      debugPrint("idToken: ${googleAuth.idToken != null ? 'ADA' : 'NULL'}");

      // Utamakan idToken jika ada (karena backend memverifikasi id_token), lalu fallback ke accessToken
      final String? tokenToSend = googleAuth.idToken ?? googleAuth.accessToken;

      if (tokenToSend != null) {
        debugPrint("Token yang dikirim ke backend: ${tokenToSend.substring(0, 20)}...");
        debugPrint("Mengirim request ke Backend: ${ApiConstants.authGoogle}");

        // 3. Kirim token ke Backend (API Laravel)
        debugPrint("=== [DEBUG] Mulai kirim request ke backend... ===");
        final response = await dio.post(
          ApiConstants.authGoogle,
          data: {'token': tokenToSend, 'id_token': tokenToSend},
          options: Options(
            headers: {'Accept': 'application/json'},
          ),
        );
        debugPrint("=== [DEBUG] Response diterima: ${response.statusCode} ===");

        if (response.statusCode == 200 || response.statusCode == 201) {
          final String backendToken = response.data['access_token'];
          final bool isProfileComplete =
              response.data['is_profile_complete'] ?? false;

          await prefs.setString('auth_token', backendToken);
          await prefs.setBool('is_profile_complete', isProfileComplete);

          return {
            'token': backendToken,
            'is_profile_complete': isProfileComplete,
          };
        } else {
          throw Exception(
            'Gagal memverifikasi token di Backend: ${response.data}',
          );
        }
      } else {
        throw Exception(
          'Google Auth tidak memberikan accessToken maupun idToken.',
        );
      }
    } catch (e) {
      debugPrint("Error Google Sign-In: $e");
      rethrow;
    }
  }

  @override
  Future<Map<String, dynamic>> registerWithEmail({
    required String name,
    required String email,
    required String password,
    required String role,
  }) async {
    try {
      final endpoint = role == 'relawan'
          ? ApiConstants.authRegisterRelawan
          : ApiConstants.authRegisterPengguna;

      final response = await dio.post(
        endpoint,
        data: {
          'name': name,
          'email': email,
          'password': password,
          'role': role,
          'persetujuan_privasi': true,
        },
        options: Options(headers: {'Accept': 'application/json'}),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        return response.data;
      } else {
        throw Exception(response.data['message'] ?? 'Registrasi gagal');
      }
    } on DioException catch (e) {
      final msg =
          e.response?.data?['message'] ?? e.message ?? 'Registrasi gagal';
      throw Exception(msg);
    }
  }

  @override
  Future<Map<String, dynamic>> loginWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      final response = await dio.post(
        ApiConstants.authLogin,
        data: {'email': email, 'password': password},
        options: Options(headers: {'Accept': 'application/json'}),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final String backendToken = response.data['access_token'];
        final bool isProfileComplete =
            response.data['is_profile_complete'] ?? false;

        await prefs.setString('auth_token', backendToken);
        await prefs.setBool('is_profile_complete', isProfileComplete);

        return {
          'token': backendToken,
          'is_profile_complete': isProfileComplete,
        };
      } else {
        throw Exception(response.data['message'] ?? 'Login gagal');
      }
    } on DioException catch (e) {
      final msg = e.response?.data?['message'] ?? e.message ?? 'Login gagal';
      throw Exception(msg);
    }
  }

  @override
  Future<Map<String, dynamic>> sendOtp({required String email}) async {
    try {
      final response = await dio.post(
        ApiConstants.sendOtp,
        data: {'email': email},
        options: Options(headers: {'Accept': 'application/json'}),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        return response.data;
      } else {
        throw Exception(response.data['message'] ?? 'Gagal mengirim OTP');
      }
    } on DioException catch (e) {
      final msg =
          e.response?.data?['message'] ?? e.message ?? 'Gagal mengirim OTP';
      throw Exception(msg);
    }
  }

  @override
  Future<Map<String, dynamic>> verifyOtp({
    required String email,
    required String otp,
  }) async {
    try {
      final response = await dio.post(
        ApiConstants.verifyOtp,
        data: {'email': email, 'otp': otp},
        options: Options(headers: {'Accept': 'application/json'}),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        // Jika backend mengembalikan token setelah verifikasi
        if (response.data['access_token'] != null) {
          final String backendToken = response.data['access_token'];
          final bool isProfileComplete =
              response.data['is_profile_complete'] ?? false;

          await prefs.setString('auth_token', backendToken);
          await prefs.setBool('is_profile_complete', isProfileComplete);
        }
        return response.data;
      } else {
        throw Exception(response.data['message'] ?? 'Verifikasi OTP gagal');
      }
    } on DioException catch (e) {
      final msg =
          e.response?.data?['message'] ?? e.message ?? 'Verifikasi OTP gagal';
      throw Exception(msg);
    }
  }
}
