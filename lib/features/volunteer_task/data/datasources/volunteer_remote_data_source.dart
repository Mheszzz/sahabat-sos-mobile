import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/constants/api_constants.dart';

abstract class VolunteerRemoteDataSource {
  Future<Map<String, dynamic>> getRelawanProfile();
  Future<Map<String, dynamic>> getActiveRelawanSos();
  Future<Map<String, dynamic>> getRelawanTasks();
  Future<Map<String, dynamic>> updateSosStatus(int id, String status, {String? catatan});
  Future<Map<String, dynamic>> rejectSos(int id, {String? alasan});
  Future<Map<String, dynamic>> getBeranda();
  Future<Map<String, dynamic>> getRelawanBerandaRiwayat();
  Future<Map<String, dynamic>> updateStatusKetersediaan(String status);
  Future<String?> hubungiKontakDarurat(String tipe, int id);
  Future<String?> getChatWaPengguna(String tipe, int id);
  Future<List<Map<String, dynamic>>> getActiveSosList();
  Future<List<Map<String, dynamic>>> getActiveLaporanList({
    double? latitude,
    double? longitude,
    double? radius,
  });
  Future<void> updateLaporanStatus(dynamic id, String status, {String? catatan});
  Future<Map<String, dynamic>> fetchDrivingRoute({
    required double startLat,
    required double startLng,
    required double endLat,
    required double endLng,
  });
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
  Future<Map<String, dynamic>> updateSosStatus(int id, String status, {String? catatan}) async {
    try {
      final payload = <String, dynamic>{'status_sos': status};
      if (catatan != null && catatan.trim().isNotEmpty) {
        payload['catatan'] = catatan.trim();
      }
      final response = await dio.patch(
        ApiConstants.sosStatusUpdate(id),
        data: payload,
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
  Future<Map<String, dynamic>> rejectSos(int id, {String? alasan}) async {
    try {
      final response = await dio.post(
        ApiConstants.sosReject(id),
        data: (alasan != null && alasan.isNotEmpty) ? {'alasan': alasan} : null,
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
        ApiConstants.beranda,
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
  Future<String?> hubungiKontakDarurat(String tipe, int id) async {
    try {
      final response = await dio.post(
        ApiConstants.hubungiKontakDaruratTask(tipe, id),
        options: Options(headers: _getHeaders()),
      );
      if (response.statusCode == 200 && response.data != null) {
        final data = response.data;
        if (data is Map) {
          final resData = data['data'];
          if (resData is Map) {
            final waUrl = resData['whatsapp_url'] ??
                resData['target_kontak']?['whatsapp_url'];
            if (waUrl != null) return waUrl.toString();
          }
          final waUrl = data['whatsapp_url'];
          if (waUrl != null) return waUrl.toString();
        }
        return null;
      } else {
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

  @override
  Future<String?> getChatWaPengguna(String tipe, int id) async {
    try {
      final response = await dio.post(
        ApiConstants.relawanChatWa(tipe, id),
        options: Options(headers: _getHeaders()),
      );
      if (response.statusCode == 200 && response.data != null) {
        final data = response.data;
        if (data is Map) {
          final resData = data['data'];
          if (resData is Map) {
            final waUrl = resData['whatsapp_url'];
            if (waUrl != null) return waUrl.toString();
          }
          final waUrl = data['whatsapp_url'];
          if (waUrl != null) return waUrl.toString();
        }
      }
      return null;
    } on DioException catch (e) {
      throw Exception(
        e.response?.data?['message'] ??
            e.message ??
            'Gagal menyiapkan tautan chat WhatsApp pengguna',
      );
    }
  }

  @override
  Future<List<Map<String, dynamic>>> getActiveSosList() async {
    try {
      final response = await dio.get(
        ApiConstants.sosActiveRelawan,
        options: Options(headers: _getHeaders()),
      );
      final List<Map<String, dynamic>> result = [];
      if (response.statusCode == 200 && response.data['data'] is List) {
        for (final item in response.data['data']) {
          if (item is Map) {
            final map = Map<String, dynamic>.from(item);
            map['tipe'] = 'sos';
            result.add(map);
          }
        }
      }
      return result;
    } on DioException catch (e) {
      throw Exception(
        e.response?.data?['message'] ??
            e.message ??
            'Gagal mengambil SOS aktif',
      );
    }
  }

  @override
  Future<List<Map<String, dynamic>>> getActiveLaporanList({
    double? latitude,
    double? longitude,
    double? radius,
  }) async {
    try {
      final Response response;
      if (latitude != null && longitude != null) {
        response = await dio.get(
          ApiConstants.laporanNearby,
          queryParameters: {
            'latitude': latitude,
            'longitude': longitude,
            'radius': radius ?? 50.0,
          },
          options: Options(headers: _getHeaders()),
        );
      } else {
        response = await dio.get(
          ApiConstants.laporan,
          queryParameters: {'status': 'aktif'},
          options: Options(headers: _getHeaders()),
        );
      }

      final List<Map<String, dynamic>> result = [];
      if (response.statusCode == 200) {
        final rawData = response.data['data'];
        List<dynamic> items = [];
        if (rawData is Map && rawData['data'] is List) {
          items = rawData['data'];
        } else if (rawData is List) {
          items = rawData;
        }
        for (final item in items) {
          if (item is Map) {
            final map = Map<String, dynamic>.from(item);
            map['tipe'] = 'laporan';
            if (map['id_relawan'] == null) {
              result.add(map);
            }
          }
        }
      }
      return result;
    } on DioException catch (e) {
      throw Exception(
        e.response?.data?['message'] ??
            e.message ??
            'Gagal mengambil laporan aktif',
      );
    }
  }

  @override
  Future<void> updateLaporanStatus(dynamic id, String status, {String? catatan}) async {
    try {
      final payload = <String, dynamic>{'status': status};
      if (catatan != null && catatan.trim().isNotEmpty) {
        payload['catatan'] = catatan.trim();
      }
      final response = await dio.put(
        ApiConstants.laporanStatus(id),
        data: payload,
        options: Options(headers: _getHeaders()),
      );
      if (response.statusCode != 200) {
        throw Exception(
          response.data['message'] ?? 'Gagal memperbarui status laporan',
        );
      }
    } on DioException catch (e) {
      throw Exception(
        e.response?.data?['message'] ??
            e.message ??
            'Gagal memperbarui status laporan',
      );
    }
  }

  @override
  Future<Map<String, dynamic>> fetchDrivingRoute({
    required double startLat,
    required double startLng,
    required double endLat,
    required double endLng,
  }) async {
    try {
      const osrmBaseUrl = String.fromEnvironment(
        'OSRM_ROUTING_URL',
        defaultValue: 'https://router.project-osrm.org',
      );
      final url =
          '$osrmBaseUrl/route/v1/driving/$startLng,$startLat;$endLng,$endLat?geometries=geojson';
      final response = await dio.get(url);
      if (response.statusCode == 200 && response.data != null) {
        return Map<String, dynamic>.from(response.data as Map);
      } else {
        throw Exception('Rute navigasi tidak ditemukan');
      }
    } on DioException catch (e) {
      throw Exception(
        e.response?.data?['message'] ??
            e.message ??
            'Gagal mengambil rute navigasi',
      );
    }
  }
}
