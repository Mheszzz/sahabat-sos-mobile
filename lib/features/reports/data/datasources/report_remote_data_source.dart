import 'dart:io';
import 'package:dio/dio.dart';
import 'package:http_parser/http_parser.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/constants/api_constants.dart';

abstract class ReportRemoteDataSource {
  Future<Map<String, dynamic>> getReportOptions();
  Future<void> submitReport({
    required String categoryId,
    required String address,
    required double latitude,
    required double longitude,
    String? quickMessage,
    String? additionalNotes,
    double? radius,
    File? photoFile,
    File? audioFile,
  });
}

class ReportRemoteDataSourceImpl implements ReportRemoteDataSource {
  final Dio dio;
  final SharedPreferences prefs;

  ReportRemoteDataSourceImpl({
    required this.dio,
    required this.prefs,
  });

  @override
  Future<Map<String, dynamic>> getReportOptions() async {
    final token = prefs.getString('auth_token');
    if (token == null || token.isEmpty) {
      throw Exception('Token otentikasi tidak ditemukan. Silakan login kembali.');
    }

    final response = await dio.get(
      ApiConstants.laporanOptions,
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
    throw Exception('Gagal memuat opsi laporan dari server.');
  }

  @override
  Future<void> submitReport({
    required String categoryId,
    required String address,
    required double latitude,
    required double longitude,
    String? quickMessage,
    String? additionalNotes,
    double? radius,
    File? photoFile,
    File? audioFile,
  }) async {
    final token = prefs.getString('auth_token');
    if (token == null || token.isEmpty) {
      throw Exception('Token otentikasi tidak ditemukan. Silakan login kembali.');
    }

    final Map<String, dynamic> formMap = {
      'kategori_laporan': categoryId,
      'lokasi_laporan': address,
      'latitude': latitude,
      'longitude': longitude,
    };

    if (quickMessage != null && quickMessage.trim().isNotEmpty) {
      formMap['pesan_cepat'] = quickMessage.trim();
    }
    if (additionalNotes != null && additionalNotes.trim().isNotEmpty) {
      formMap['keterangan_tambahan'] = additionalNotes.trim();
    }
    if (radius != null) {
      formMap['radius'] = radius;
    }

    final formData = FormData.fromMap(formMap);

    if (photoFile != null) {
      formData.files.add(
        MapEntry(
          'foto_laporan',
          await MultipartFile.fromFile(photoFile.path),
        ),
      );
    }

    if (audioFile != null) {
      formData.files.add(
        MapEntry(
          'rekam_suara',
          await MultipartFile.fromFile(
            audioFile.path,
            contentType: MediaType('audio', 'wav'),
          ),
        ),
      );
    }

    final response = await dio.post(
      ApiConstants.laporan,
      data: formData,
      options: Options(
        sendTimeout: const Duration(minutes: 3),
        receiveTimeout: const Duration(minutes: 3),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      ),
    );

    if (response.statusCode != 200 && response.statusCode != 201) {
      throw Exception('Gagal mengirim laporan (Status: ${response.statusCode})');
    }
  }
}
