import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/constants/api_constants.dart';

abstract class EmergencyContactRemoteDataSource {
  Future<List<dynamic>> getContacts();
  Future<Map<String, dynamic>> getContactById(int id);
  Future<Map<String, dynamic>> addContact(Map<String, dynamic> data);
  Future<Map<String, dynamic>> updateContact(int id, Map<String, dynamic> data);
  Future<void> deleteContact(int id);
  Future<Map<String, dynamic>> toggleNotif(int id, bool terimaNotif);
}

class EmergencyContactRemoteDataSourceImpl implements EmergencyContactRemoteDataSource {
  final Dio dio;
  final SharedPreferences prefs;

  EmergencyContactRemoteDataSourceImpl({required this.dio, required this.prefs});

  Map<String, dynamic> _getHeaders() {
    final token = prefs.getString('auth_token');
    return {
      'Authorization': 'Bearer $token',
      'Accept': 'application/json',
    };
  }

  @override
  Future<List<dynamic>> getContacts() async {
    try {
      final response = await dio.get(
        ApiConstants.kontakDarurat,
        options: Options(headers: _getHeaders()),
      );
      if (response.statusCode == 200) {
        return response.data['data'] ?? [];
      } else {
        throw Exception(response.data['message'] ?? 'Gagal mengambil daftar kontak darurat');
      }
    } on DioException catch (e) {
      throw Exception(e.response?.data?['message'] ?? 'Gagal mengambil kontak darurat');
    }
  }

  @override
  Future<Map<String, dynamic>> getContactById(int id) async {
    try {
      final response = await dio.get(
        ApiConstants.kontakDaruratDetail(id),
        options: Options(headers: _getHeaders()),
      );
      if (response.statusCode == 200) {
        return response.data['data'];
      } else {
        throw Exception(response.data['message'] ?? 'Gagal mengambil detail kontak darurat');
      }
    } on DioException catch (e) {
      throw Exception(e.response?.data?['message'] ?? 'Gagal mengambil detail kontak darurat');
    }
  }

  @override
  Future<Map<String, dynamic>> addContact(Map<String, dynamic> data) async {
    try {
      final response = await dio.post(
        ApiConstants.kontakDarurat,
        data: data,
        options: Options(headers: _getHeaders()),
      );
      if (response.statusCode == 201 || response.statusCode == 200) {
        return response.data['data'];
      } else {
        throw Exception(response.data['message'] ?? 'Gagal menambahkan kontak darurat');
      }
    } on DioException catch (e) {
      throw Exception(e.response?.data?['message'] ?? 'Gagal menambahkan kontak darurat');
    }
  }

  @override
  Future<Map<String, dynamic>> updateContact(int id, Map<String, dynamic> data) async {
    try {
      final response = await dio.put(
        ApiConstants.kontakDaruratDetail(id),
        data: data,
        options: Options(headers: _getHeaders()),
      );
      if (response.statusCode == 200) {
        return response.data['data'];
      } else {
        throw Exception(response.data['message'] ?? 'Gagal memperbarui kontak darurat');
      }
    } on DioException catch (e) {
      throw Exception(e.response?.data?['message'] ?? 'Gagal memperbarui kontak darurat');
    }
  }

  @override
  Future<void> deleteContact(int id) async {
    try {
      final response = await dio.delete(
        ApiConstants.kontakDaruratDetail(id),
        options: Options(headers: _getHeaders()),
      );
      if (response.statusCode != 200) {
        throw Exception(response.data['message'] ?? 'Gagal menghapus kontak darurat');
      }
    } on DioException catch (e) {
      throw Exception(e.response?.data?['message'] ?? 'Gagal menghapus kontak darurat');
    }
  }

  @override
  Future<Map<String, dynamic>> toggleNotif(int id, bool terimaNotif) async {
    try {
      final response = await dio.patch(
        ApiConstants.kontakDaruratToggle(id),
        data: {'terima_notif': terimaNotif},
        options: Options(headers: _getHeaders()),
      );
      if (response.statusCode == 200) {
        return response.data['data'];
      } else {
        throw Exception(response.data['message'] ?? 'Gagal mengubah status notifikasi');
      }
    } on DioException catch (e) {
      throw Exception(e.response?.data?['message'] ?? 'Gagal mengubah status notifikasi');
    }
  }
}
