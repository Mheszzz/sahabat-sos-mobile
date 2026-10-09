import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/constants/api_constants.dart';

abstract class VolunteerRemoteDataSource {
  Future<Map<String, dynamic>> getRelawanProfile();
  Future<Map<String, dynamic>> getActiveRelawanSos();
  Future<Map<String, dynamic>> getRelawanTasks();
  Future<Map<String, dynamic>> updateSosStatus(int id, String status);
  Future<Map<String, dynamic>> rejectSos(int id);
  Future<Map<String, dynamic>> getBeranda();
  Future<Map<String, dynamic>> getRelawanBerandaRiwayat();
  Future<Map<String, dynamic>> updateStatusKetersediaan(String status);
  Future<void> hubungiKontakDarurat(String tipe, int id);
}

class VolunteerRemoteDataSourceImpl implements VolunteerRemoteDataSource {
  final Dio dio;
  final SharedPreferences prefs;

  VolunteerRemoteDataSourceImpl({required this.dio, required this.prefs});

  Map<String, dynamic> _getHeaders() {
    final token = prefs.getString('auth_token');
    return {'Authorization': 'Bearer $token', 'Accept': 'application/json'};
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
        throw Exception(
          response.data['message'] ?? 'Gagal mengambil profil relawan',
        );
      }
    } on DioException catch (e) {
      throw Exception(
        e.response?.data?['message'] ??
            e.message ??
            'Gagal mengambil profil relawan',
      );
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
        throw Exception(
          response.data['message'] ?? 'Gagal mengambil daftar SOS aktif',
        );
      }
    } on DioException catch (e) {
      throw Exception(
        e.response?.data?['message'] ??
            e.message ??
            'Gagal mengambil daftar SOS aktif',
      );
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
        throw Exception(
          response.data['message'] ?? 'Gagal mengambil tugas SOS',
        );
      }
    } on DioException catch (e) {
      throw Exception(
        e.response?.data?['message'] ??
            e.message ??
            'Gagal mengambil tugas SOS',
      );
    }
  }

  @override
  Future<Map<String, dynamic>> updateSosStatus(int id, String status) async {
    try {
      final response = await dio.patch(
        ApiConstants.sosStatusUpdate(id),
        data: {'status_sos': status},
        options: Options(headers: _getHeaders()),
      );
      if (response.statusCode == 200) {
        return response.data;
      } else {
        throw Exception(
          response.data['message'] ?? 'Gagal mengupdate status SOS',
        );
      }
    } on DioException catch (e) {
      throw Exception(
        e.response?.data?['message'] ??
            e.message ??
            'Gagal mengupdate status SOS',
      );
    }
  }

  @override
  Future<Map<String, dynamic>> rejectSos(int id) async {
    try {
      final response = await dio.post(
        ApiConstants.sosReject(id),
        options: Options(headers: _getHeaders()),
      );
      if (response.statusCode == 200) {
        return response.data;
      } else {
        throw Exception(response.data['message'] ?? 'Gagal menolak SOS');
      }
    } on DioException catch (e) {
      throw Exception(
        e.response?.data?['message'] ?? e.message ?? 'Gagal menolak SOS',
      );
    }
  }

  @override
  Future<Map<String, dynamic>> getBeranda() async {
    try {
      final response = await dio.get(
        ApiConstants.relawanBeranda,
        options: Options(headers: _getHeaders()),
      );
      if (response.statusCode == 200) {
        return response.data;
      } else {
        throw Exception(
          response.data['message'] ?? 'Gagal mengambil data beranda',
        );
      }
    } on DioException catch (e) {
      throw Exception(
        e.response?.data?['message'] ??
            e.message ??
            'Gagal mengambil data beranda',
      );
    }
  }

  @override
  Future<Map<String, dynamic>> getRelawanBerandaRiwayat() async {
    try {
      final response = await dio.get(
        ApiConstants.riwayatRelawan,
        options: Options(headers: _getHeaders()),
      );
      if (response.statusCode == 200) {
        return response.data;
      } else {
        throw Exception(
          response.data['message'] ?? 'Gagal mengambil riwayat beranda relawan',
        );
      }
    } on DioException catch (e) {
      throw Exception(
        e.response?.data?['message'] ??
            e.message ??
            'Gagal mengambil riwayat beranda relawan',
      );
    }
  }

  @override
  Future<Map<String, dynamic>> updateStatusKetersediaan(String status) async {
    try {
      final response = await dio.put(
        ApiConstants.relawanStatusKetersediaan,
        data: {'status_ketersediaan': status},
        options: Options(headers: _getHeaders()),
      );
      if (response.statusCode == 200) {
        return response.data;
      } else {
        throw Exception(
          response.data['message'] ?? 'Gagal memperbarui status ketersediaan',
        );
      }
    } on DioException catch (e) {
      throw Exception(
        e.response?.data?['message'] ??
            e.message ??
            'Gagal memperbarui status ketersediaan',
      );
    }
  }

  @override
  Future<void> hubungiKontakDarurat(String tipe, int id) async {
    try {
      final response = await dio.post(
        ApiConstants.hubungiKontakDaruratTask(tipe, id),
        options: Options(headers: _getHeaders()),
      );
      if (response.statusCode != 200) {
        throw Exception(
          response.data['message'] ?? 'Gagal menghubungi kontak darurat',
        );
      }
    } on DioException catch (e) {
      throw Exception(
        e.response?.data?['message'] ??
            e.message ??
            'Gagal menghubungi kontak darurat',
      );
    }
  }
}
