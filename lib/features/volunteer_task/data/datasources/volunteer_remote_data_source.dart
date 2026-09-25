import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/constants/api_constants.dart';

abstract class VolunteerRemoteDataSource {
  Future<Map<String, dynamic>> getRelawanProfile();
  Future<Map<String, dynamic>> getActiveRelawanSos();
  Future<Map<String, dynamic>> getRelawanTasks();
  Future<Map<String, dynamic>> updateSosStatus(int id, String status);
}

class VolunteerRemoteDataSourceImpl implements VolunteerRemoteDataSource {
  final Dio dio;
  final SharedPreferences prefs;

  VolunteerRemoteDataSourceImpl({required this.dio, required this.prefs});

  Map<String, dynamic> _getHeaders() {
    final token = prefs.getString('auth_token');
    return {
      'Authorization': 'Bearer $token',
      'Accept': 'application/json',
    };
  }

  @override
  Future<Map<String, dynamic>> getRelawanProfile() async {
    try {
      final response = await dio.get(
        ApiConstants.relawanProfile,
        options: Options(headers: _getHeaders()),
      );
      if (response.statusCode == 200) {
        return response.data;
      } else {
        throw Exception(response.data['message'] ?? 'Gagal mengambil profil relawan');
      }
    } on DioException catch (e) {
      throw Exception(e.response?.data?['message'] ?? e.message ?? 'Gagal mengambil profil relawan');
    }
  }

  @override
  Future<Map<String, dynamic>> getActiveRelawanSos() async {
    try {
      final response = await dio.get(
        ApiConstants.sosActiveRelawan,
        options: Options(headers: _getHeaders()),
      );
      if (response.statusCode == 200) {
        return response.data;
      } else {
        throw Exception(response.data['message'] ?? 'Gagal mengambil daftar SOS aktif');
      }
    } on DioException catch (e) {
      throw Exception(e.response?.data?['message'] ?? e.message ?? 'Gagal mengambil daftar SOS aktif');
    }
  }

  @override
  Future<Map<String, dynamic>> getRelawanTasks() async {
    try {
      final response = await dio.get(
        ApiConstants.sosRelawanTasks,
        options: Options(headers: _getHeaders()),
      );
      if (response.statusCode == 200) {
        return response.data;
      } else {
        throw Exception(response.data['message'] ?? 'Gagal mengambil tugas SOS');
      }
    } on DioException catch (e) {
      throw Exception(e.response?.data?['message'] ?? e.message ?? 'Gagal mengambil tugas SOS');
    }
  }

  @override
  Future<Map<String, dynamic>> updateSosStatus(int id, String status) async {
    try {
      final response = await dio.patch(
        ApiConstants.sosStatusUpdate(id),
        data: {'status': status},
        options: Options(headers: _getHeaders()),
      );
      if (response.statusCode == 200) {
        return response.data;
      } else {
        throw Exception(response.data['message'] ?? 'Gagal mengupdate status SOS');
      }
    } on DioException catch (e) {
      throw Exception(e.response?.data?['message'] ?? e.message ?? 'Gagal mengupdate status SOS');
    }
  }
}
