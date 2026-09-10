import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/constants/api_constants.dart';

abstract class AuthRemoteDataSource {
  /// Mengembalikan Map berisi token JWT dan status is_profile_complete, atau null jika dibatalkan
  Future<Map<String, dynamic>?> signInWithGoogle();
}

class AuthRemoteDataSourceImpl implements AuthRemoteDataSource {
  final Dio dio;
  final SharedPreferences prefs;
  
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    clientId: kIsWeb ? '355219118861-82gvltkbr04m7j5l77och0ntj1vldmrn.apps.googleusercontent.com' : '355219118861-e5g4epemc4v5he571v5qoe455ko6cn64.apps.googleusercontent.com',
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
}
