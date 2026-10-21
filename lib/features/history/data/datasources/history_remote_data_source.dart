import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/constants/api_constants.dart';

abstract class HistoryRemoteDataSource {
  Future<Map<String, dynamic>> getHistory({
    required int page,
    required int perPage,
  });

  Future<List<dynamic>> getSosHistory();

  Future<Map<String, dynamic>> getDetail({
    required int id,
    required bool isSos,
  });

  Future<void> updateStatus({
    required int id,
    required bool isSos,
    required String status,
  });

  Future<String?> getUserRole();

  Future<void> downloadAudio({
    required String url,
    required String savePath,
  });
}

class HistoryRemoteDataSourceImpl implements HistoryRemoteDataSource {
  final Dio dio;
  final SharedPreferences prefs;

  HistoryRemoteDataSourceImpl({
    required this.dio,
    required this.prefs,
  });

  Map<String, String> _buildHeaders() {
    final token = prefs.getString('auth_token');
    return {
      'Accept': 'application/json',
      if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
    };
  }

  @override
  Future<Map<String, dynamic>> getHistory({
    required int page,
    required int perPage,
  }) async {
    try {
      final role = prefs.getString('user_role');
      final endpoint = role == 'relawan'
          ? ApiConstants.riwayatRelawan
          : ApiConstants.riwayatPengguna;

      final response = await dio.get(
        '$endpoint?page=$page&per_page=$perPage',
        options: Options(headers: _buildHeaders()),
      );

      if (response.statusCode == 200 && response.data is Map) {
        return Map<String, dynamic>.from(response.data as Map);
      }
      throw Exception('Format data riwayat tidak valid');
    } on DioException catch (e) {
      debugPrint('DioException getHistory: ${e.message}');
      throw Exception(
        e.response?.data?['message'] ?? 'Gagal memuat daftar riwayat',
      );
    }
  }

  @override
  Future<List<dynamic>> getSosHistory() async {
    try {
      final response = await dio.get(
        ApiConstants.sosUserHistory,
        options: Options(headers: _buildHeaders()),
      );

      if (response.statusCode == 200 && response.data is Map) {
        final data = response.data['data'];
        if (data != null && data is Map && data['data'] is List) {
          return List<dynamic>.from(data['data'] as List);
        } else if (data is List) {
          return List<dynamic>.from(data);
        }
        return [];
      }
      throw Exception('Format data riwayat SOS tidak valid');
    } on DioException catch (e) {
      debugPrint('DioException getSosHistory: ${e.message}');
      throw Exception(
        e.response?.data?['message'] ?? 'Gagal memuat riwayat SOS',
      );
    }
  }

  @override
  Future<Map<String, dynamic>> getDetail({
    required int id,
    required bool isSos,
  }) async {
    try {
      final url = isSos
          ? ApiConstants.sosDetail(id)
          : ApiConstants.laporanDetail(id);

      final response = await dio.get(
        url,
        options: Options(headers: _buildHeaders()),
      );

      if (response.statusCode == 200 && response.data is Map) {
        final data = response.data['data'];
        if (data != null && data is Map) {
          return Map<String, dynamic>.from(data);
        }
      }
      throw Exception('Detail riwayat tidak ditemukan');
    } on DioException catch (e) {
      debugPrint('DioException getDetail: ${e.message}');
      throw Exception(
        e.response?.data?['message'] ?? 'Gagal memuat detail riwayat',
      );
    }
  }

  @override
  Future<void> updateStatus({
    required int id,
    required bool isSos,
    required String status,
  }) async {
    try {
      final url = isSos
          ? ApiConstants.sosStatusUpdate(id)
          : ApiConstants.laporanStatus(id);

      final payload = isSos ? {'status_sos': status} : {'status': status};

      final response = await dio.put(
        url,
        data: payload,
        options: Options(headers: _buildHeaders()),
      );

      if (response.statusCode != 200) {
        throw Exception(
          response.data?['message'] ?? 'Gagal memperbarui status',
        );
      }
    } on DioException catch (e) {
      debugPrint('DioException updateStatus: ${e.message}');
      throw Exception(
        e.response?.data?['message'] ?? 'Gagal memperbarui status',
      );
    }
  }

  @override
  Future<String?> getUserRole() async {
    try {
      final cachedRole = prefs.getString('user_role');
      if (cachedRole != null && cachedRole.isNotEmpty) {
        return cachedRole.toLowerCase();
      }

      final response = await dio.get(
        ApiConstants.me,
        options: Options(headers: _buildHeaders()),
      );

      if (response.statusCode == 200 && response.data is Map) {
        final role = response.data['data']?['role']?.toString().toLowerCase();
        if (role != null && role.isNotEmpty) {
          await prefs.setString('user_role', role);
          return role;
        }
      }
      return null;
    } catch (e) {
      debugPrint('Gagal mengambil peran pengguna: $e');
      return prefs.getString('user_role')?.toLowerCase();
    }
  }

  @override
  Future<void> downloadAudio({
    required String url,
    required String savePath,
  }) async {
    try {
      if (await File(savePath).exists()) return;
      await dio.download(
        url,
        savePath,
        options: Options(headers: _buildHeaders()),
      );
    } on DioException catch (e) {
      debugPrint('DioException downloadAudio: ${e.message}');
      throw Exception('Gagal mengunduh berkas audio');
    }
  }
}
