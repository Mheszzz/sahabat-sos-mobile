import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/constants/api_constants.dart';

abstract class AuthRemoteDataSource {
  /// Mengembalikan Map berisi token JWT dan status is_profile_complete, atau null jika dibatalkan
  Future<Map<String, dynamic>?> signInWithGoogle();
  Future<Map<String, dynamic>> registerWithEmail({required String name, required String email, required String password, required String role});
  Future<Map<String, dynamic>> loginWithEmail({required String email, required String password});
  Future<Map<String, dynamic>> sendOtp({required String email});
  Future<Map<String, dynamic>> verifyOtp({required String email, required String otp});
}

class AuthRemoteDataSourceImpl implements AuthRemoteDataSource {
  final Dio dio;
  final SharedPreferences prefs;
  
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    clientId: kIsWeb ? '757209543690-bpjk959q2se7oq0eos1olm6urg35oicp.apps.googleusercontent.com' : '757209543690-jpg1blpas12drdam7leck0ha4pk7sluo.apps.googleusercontent.com',
    serverClientId: kIsWeb ? null : '355219118861-82gvltkbr04m7j5l77och0ntj1vldmrn.apps.googleusercontent.com',
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
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      
      if (googleUser == null) {
        throw Exception('User membatalkan dialog Google Sign-In atau konfigurasi salah.');
      }

      // 2. Ambil token (accessToken)
      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final String? tokenToSend = googleAuth.accessToken ?? googleAuth.idToken;

      if (tokenToSend != null) {
        // 3. Kirim token ke Backend (API Laravel)
        final response = await dio.post(
          ApiConstants.authGoogle,
          data: {
            'token': tokenToSend,
          },
          options: Options(
            headers: {
              'Accept': 'application/json',
            },
          ),
        );

        if (response.statusCode == 200 || response.statusCode == 201) {
          final String backendToken = response.data['access_token'];
          final bool isProfileComplete = response.data['is_profile_complete'] ?? false;
          
          await prefs.setString('auth_token', backendToken);
          await prefs.setBool('is_profile_complete', isProfileComplete);
          
          return {
            'token': backendToken,
            'is_profile_complete': isProfileComplete,
          };
        } else {
          throw Exception('Gagal memverifikasi token di Backend: ${response.data}');
        }
      } else {
        throw Exception('Google Auth tidak memberikan accessToken maupun idToken.');
      }
    } catch (e) {
      print("Error Google Sign-In: $e");
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
      final response = await dio.post(
        ApiConstants.authRegister,
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
      final msg = e.response?.data?['message'] ?? e.message ?? 'Registrasi gagal';
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
        data: {
          'email': email,
          'password': password,
        },
        options: Options(headers: {'Accept': 'application/json'}),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final String backendToken = response.data['access_token'];
        final bool isProfileComplete = response.data['is_profile_complete'] ?? false;

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
      final msg = e.response?.data?['message'] ?? e.message ?? 'Gagal mengirim OTP';
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
        data: {
          'email': email,
          'otp': otp,
        },
        options: Options(headers: {'Accept': 'application/json'}),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        // Jika backend mengembalikan token setelah verifikasi
        if (response.data['access_token'] != null) {
          final String backendToken = response.data['access_token'];
          final bool isProfileComplete = response.data['is_profile_complete'] ?? false;

          await prefs.setString('auth_token', backendToken);
          await prefs.setBool('is_profile_complete', isProfileComplete);
        }
        return response.data;
      } else {
        throw Exception(response.data['message'] ?? 'Verifikasi OTP gagal');
      }
    } on DioException catch (e) {
      final msg = e.response?.data?['message'] ?? e.message ?? 'Verifikasi OTP gagal';
      throw Exception(msg);
    }
  }
}
