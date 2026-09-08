import 'package:dio/dio.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../../../../core/constants/api_constants.dart';

abstract class AuthRemoteDataSource {
  /// Mengembalikan token JWT dari backend jika sukses, atau null jika dibatalkan
  Future<String?> signInWithGoogle();
}

class AuthRemoteDataSourceImpl implements AuthRemoteDataSource {
  final Dio dio;
  
  // Menggunakan Web Client ID dari temanmu
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    serverClientId: '355219118861-82gvltkbr04m7j5l77och0ntj1vldmrn.apps.googleusercontent.com',
  );

  AuthRemoteDataSourceImpl({required this.dio});

  @override
  Future<String?> signInWithGoogle() async {
    try {
      // 1. Munculkan dialog Google Sign In
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      
      if (googleUser == null) {
        // User menekan 'Batal' saat pop-up muncul
        return null;
      }

      // 2. Ambil token (idToken)
      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final String? idToken = googleAuth.idToken;

      if (idToken != null) {
        // 3. Kirim idToken ke Backend (API Laravel)
        final response = await dio.post(
          ApiConstants.authGoogle,
          data: {
            'id_token': idToken,
          },
        );

        if (response.statusCode == 200 || response.statusCode == 201) {
          // 4. Berhasil login/registrasi, kembalikan token (atau data user) dari Laravel
          return response.data['token'];
        } else {
          throw Exception('Gagal memverifikasi token di Backend');
        }
      }
      return null;
    } catch (e) {
      print("Error Google Sign-In: $e");
      rethrow; // Bisa di-handle di Repository atau UI
    }
  }
}
