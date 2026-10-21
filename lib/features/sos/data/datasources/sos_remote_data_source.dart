import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/constants/api_constants.dart';

abstract class SosRemoteDataSource {
  Future<Map<String, dynamic>?> getActiveEmergency();
  Future<bool> cancelEmergency(int sosId, {String? reason});
  Future<List<dynamic>> getSosActivities(int sosId);
}

class SosRemoteDataSourceImpl implements SosRemoteDataSource {
  final Dio dio;
  final SharedPreferences prefs;

  SosRemoteDataSourceImpl({
    required this.dio,
    required this.prefs,
  });

  @override
  Future<Map<String, dynamic>?> getActiveEmergency() async {
    final token = prefs.getString('auth_token');
    if (token == null || token.isEmpty) {
      return null;
    }

    final response = await dio.get(
      ApiConstants.emergencyActive,
      options: Options(
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      ),
    );

    if (response.statusCode == 200 && response.data is Map<String, dynamic>) {
      return response.data['data'] as Map<String, dynamic>?;
    }
    return null;
  }

  @override
  Future<bool> cancelEmergency(int sosId, {String? reason}) async {
    final token = prefs.getString('auth_token');
    if (token == null || token.isEmpty) {
      throw Exception('Sesi telah berakhir, silakan login kembali');
    }

    final response = await dio.post(
      ApiConstants.emergencyCancel(sosId),
      data: {'alasan_batal': reason ?? 'Dibatalkan oleh pengguna'},
      options: Options(
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      ),
    );

    return response.statusCode == 200;
  }

  @override
  Future<List<dynamic>> getSosActivities(int sosId) async {
    final token = prefs.getString('auth_token');
    final response = await dio.get(
      ApiConstants.sosActivities(sosId),
      options: Options(
        headers: {
          if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      ),
    );

    if (response.statusCode == 200 && response.data is Map<String, dynamic>) {
      return (response.data['data'] as List<dynamic>?) ?? [];
    }
    return [];
  }
}
