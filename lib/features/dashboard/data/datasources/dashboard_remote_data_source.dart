import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/constants/api_constants.dart';

abstract class DashboardRemoteDataSource {
  Future<Map<String, dynamic>> getBerandaData();
  Future<int?> triggerEmergency({
    required double latitude,
    required double longitude,
    required String address,
    required Map<String, dynamic> telemetryData,
    Map<String, dynamic>? tuyaDeviceInfo,
    Map<String, dynamic>? smartwatchDeviceInfo,
  });
}

class DashboardRemoteDataSourceImpl implements DashboardRemoteDataSource {
  final Dio dio;
  final SharedPreferences prefs;

  DashboardRemoteDataSourceImpl({
    required this.dio,
    required this.prefs,
  });

  @override
  Future<Map<String, dynamic>> getBerandaData() async {
    final token = prefs.getString('auth_token');
    if (token == null || token.isEmpty) {
      return {};
    }

    final response = await dio.get(
      ApiConstants.beranda,
      options: Options(
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      ),
    );

    if (response.statusCode == 200 && response.data is Map<String, dynamic>) {
      return response.data as Map<String, dynamic>;
    }
    return {};
  }

  @override
  Future<int?> triggerEmergency({
    required double latitude,
    required double longitude,
    required String address,
    required Map<String, dynamic> telemetryData,
    Map<String, dynamic>? tuyaDeviceInfo,
    Map<String, dynamic>? smartwatchDeviceInfo,
  }) async {
    final token = prefs.getString('auth_token');
    if (token == null || token.isEmpty) {
      throw Exception('Sesi telah berakhir, silakan login kembali');
    }

    final payload = {
      'latitude': latitude,
      'longitude': longitude,
      'lokasi_user': address,
      'trigger_source': 'app_button',
      'battery_level': telemetryData['battery_level'],
      'signal_strength': telemetryData['signal_strength'],
      if (smartwatchDeviceInfo != null && smartwatchDeviceInfo['heart_rate'] != null)
        'heart_rate': smartwatchDeviceInfo['heart_rate'],
      'device_info': {
        'mobile': telemetryData['device_info'],
        'tuya': ?tuyaDeviceInfo,
        'smartwatch': ?smartwatchDeviceInfo,
        'smartband': ?smartwatchDeviceInfo,
      },
    };

    final response = await dio.post(
      ApiConstants.emergencyTrigger,
      data: payload,
      options: Options(
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
        validateStatus: (status) =>
            status != null && (status >= 200 && status < 300 || status == 422),
      ),
    );

    if (response.statusCode == 422) {
      final message = response.data['message'] ?? 'Sinyal SOS darurat masih aktif';
      throw DioException(
        requestOptions: response.requestOptions,
        response: response,
        message: message.toString(),
      );
    }

    if (response.statusCode != 200 && response.statusCode != 201) {
      throw Exception('Gagal mengirim sinyal darurat (Kode: ${response.statusCode})');
    }

    final resData = response.data;
    if (resData is Map<String, dynamic>) {
      final sosData = resData['data'];
      if (sosData is Map<String, dynamic> && sosData['id'] != null) {
        return (sosData['id'] as num).toInt();
      }
      if (resData['id'] != null) {
        return (resData['id'] as num).toInt();
      }
    }
    return null;
  }
}
