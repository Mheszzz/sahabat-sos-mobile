import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'dart:ui';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:get_it/get_it.dart';
import 'package:sahabat_sos_mobile/core/constants/api_constants.dart';
import 'package:intl/intl.dart';
import 'package:geocoding/geocoding.dart';

class SosHistoryScreen extends StatefulWidget {
  const SosHistoryScreen({super.key});

  @override
  State<SosHistoryScreen> createState() => _SosHistoryScreenState();
}

class _SosHistoryScreenState extends State<SosHistoryScreen> {
  static const Color primaryTeal = Color(0xFF00695C);

  bool _isLoading = true;
  String? _errorMessage;
  List<dynamic> _sosHistory = [];

  final Map<int, String> _addressCache = {};

  Future<String> _getAddress(Map<String, dynamic> item, int index) async {
    final id = item['id'] ?? index;
    if (_addressCache.containsKey(id)) {
      return _addressCache[id]!;
    }

    String defaultLocation = item['lokasi_sos']?.toString() ?? 'Lokasi tidak diketahui';
    final rawLocationStr = defaultLocation;
    final alamatMatch = RegExp(r'alamat:\s*([^,}]+)').firstMatch(rawLocationStr);
    if (alamatMatch != null) {
      defaultLocation = alamatMatch.group(1)!.trim();
    }

    final latVal = item['latitude'];
    double? latitude;
    if (latVal != null) {
      latitude = (latVal is num) ? latVal.toDouble() : double.tryParse(latVal.toString());
    } else {
      final latMatch = RegExp(r'latitude:\s*(-?\d+\.\d+)').firstMatch(rawLocationStr);
      if (latMatch != null) latitude = double.tryParse(latMatch.group(1)!);
    }

    final lngVal = item['longitude'];
    double? longitude;
    if (lngVal != null) {
      longitude = (lngVal is num) ? lngVal.toDouble() : double.tryParse(lngVal.toString());
    } else {
      final lngMatch = RegExp(r'longitude:\s*(-?\d+\.\d+)').firstMatch(rawLocationStr);
      if (lngMatch != null) longitude = double.tryParse(lngMatch.group(1)!);
    }

    if (latitude != null && longitude != null) {
      try {
        final placemarks = await Geocoding().placemarkFromCoordinates(latitude, longitude);
        if (placemarks.isNotEmpty) {
          final place = placemarks.first;
          final addressList = [
            place.subLocality,
            place.locality,
            place.subAdministrativeArea,
            place.administrativeArea,
          ].where((e) => e != null && e.isNotEmpty).toList();
          final address = addressList.join(', ');
          if (address.isNotEmpty) {
            _addressCache[id] = address;
            return address;
          }
        }
      } catch (e) {
        // Fallback
      }
    }
    
    _addressCache[id] = defaultLocation;
    return defaultLocation;
  }

  @override
  void initState() {
    super.initState();
    _fetchSosHistory();
  }

  Future<void> _fetchSosHistory() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final prefs = GetIt.instance<SharedPreferences>();
      final token = prefs.getString('auth_token');
      final dio = GetIt.instance<Dio>();

      final headers = {if (token != null) 'Authorization': 'Bearer $token'};

      final response = await dio.get(
        ApiConstants.sosUserHistory,
        options: Options(headers: headers),
      );

      if (response.statusCode == 200) {
        final data = response.data['data'] != null && response.data['data']['data'] != null
            ? response.data['data']['data']
            : (response.data['data'] is List ? response.data['data'] : []);
            
        setState(() {
          _sosHistory = data;
          _isLoading = false;
        });
      } else {
        setState(() {
          _errorMessage = 'Gagal mengambil riwayat khusus SOS';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Terjadi kesalahan sistem: $e';
        _isLoading = false;
      });
    }
  }

  String _formatDate(String dateStr) {
    try {
      final date = DateTime.parse(dateStr).toLocal();
      return DateFormat('dd MMM yyyy, HH:mm').format(date);
    } catch (_) {
      return dateStr;
    }
  }

  Widget _buildStatusBadge(String status) {
    Color badgeColor;

    switch (status.toLowerCase()) {
      case 'selesai':
        badgeColor = Colors.green.shade600;
        break;
      case 'batal':
      case 'dibatalkan':
        badgeColor = Colors.grey.shade600;
        break;
      case 'ditangani':
        badgeColor = Colors.orange;
        break;
      default:
        badgeColor = Colors.red.shade600;
    }

    String getDisplayStatus(String s) {
      final lower = s.toLowerCase();
      if (lower == 'batal' || lower == 'dibatalkan') return 'Dibatalkan';
      if (lower == 'selesai') return 'Selesai';
      if (lower == 'ditangani') return 'Sedang Ditangani';
      if (lower == 'belum ditangani' || lower == 'aktif') return 'Menunggu Relawan';
      return s;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: badgeColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: badgeColor.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: badgeColor, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(
            getDisplayStatus(status),
            style: TextStyle(
              color: badgeColor,
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6F8),
      appBar: AppBar(
        title: Row(
          children: [
            Image.asset('assets/images/logo.png', width: 24, height: 24),
            const SizedBox(width: 8),
            const Text(
              'Riwayat Khusus SOS',
              style: TextStyle(
                color: primaryTeal,
                fontWeight: FontWeight.bold,
                fontSize: 20,
              ),
            ),
          ],
        ),
        backgroundColor: const Color(0xFFF5F6F8),
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleSpacing: 0,
        iconTheme: const IconThemeData(color: primaryTeal),
      ),
      body: _isLoading
          ? const Center(child: CupertinoActivityIndicator(radius: 16))
          : _errorMessage != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.red.shade100),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(CupertinoIcons.exclamationmark_circle, size: 48, color: Colors.red.shade400),
                          const SizedBox(height: 16),
                          Text(
                            'Oops! Terjadi Kesalahan',
                            style: TextStyle(
                              color: Colors.red.shade800,
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(_errorMessage!, textAlign: TextAlign.center, style: TextStyle(color: Colors.red.shade700, fontSize: 14)),
                          const SizedBox(height: 20),
                          ElevatedButton.icon(
                            onPressed: _fetchSosHistory,
                            icon: const Icon(CupertinoIcons.refresh, size: 18),
                            label: const Text('Coba Lagi'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red.shade600,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20),
                              ),
                              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                            ),
                          )
                        ],
                      ),
                    ),
                  ),
                )
              : _sosHistory.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(24),
                              decoration: BoxDecoration(
                                color: Colors.grey.shade200,
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                CupertinoIcons.folder,
                                size: 64,
                                color: Colors.grey.shade400,
                              ),
                            ),
                            const SizedBox(height: 24),
                            const Text(
                              'Belum ada riwayat SOS',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                              ),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'Riwayat panggilan SOS akan muncul di sini',
                              textAlign: TextAlign.center,
                              style: TextStyle(fontSize: 14, color: Colors.black54),
                            ),
                          ],
                        ),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _sosHistory.length,
                      itemBuilder: (context, index) {
                        final item = _sosHistory[index];
                        final title = item['judul_sos'] ?? 'Darurat SOS';
                        final status = item['status_sos'] ?? 'aktif';
                        final date = item['waktu_sos'] ?? item['created_at'] ?? '';
                        final location = item['lokasi_sos'] ?? 'Lokasi tidak diketahui';
                        final relawan = item['relawan'] != null ? item['relawan']['name'] : null;

                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.05),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(16),
                            child: BackdropFilter(
                              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                              child: Container(
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.4),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: Colors.white.withValues(alpha: 0.6),
                                    width: 1.5,
                                  ),
                                ),
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Expanded(
                                          child: Text(
                                            title,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 16,
                                              color: Colors.black87,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        _buildStatusBadge(status),
                                      ],
                                    ),
                                    const Padding(
                                      padding: EdgeInsets.symmetric(vertical: 12),
                                      child: Divider(height: 1),
                                    ),
                                    Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.all(6),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFE0F2F1),
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: const Icon(CupertinoIcons.clock, size: 16, color: primaryTeal),
                                        ),
                                        const SizedBox(width: 10),
                                        Text(_formatDate(date), style: const TextStyle(color: Colors.black54, fontSize: 13)),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.all(6),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFFBE9E7),
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: const Icon(CupertinoIcons.location, size: 16, color: Color(0xFFD84315)),
                                        ),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: FutureBuilder<String>(
                                            future: _getAddress(item, index),
                                            builder: (context, snapshot) {
                                              return Text(
                                                snapshot.data ?? location,
                                                style: const TextStyle(color: Colors.black54, fontSize: 13),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              );
                                            },
                                          ),
                                        ),
                                      ],
                                    ),
                                    if (relawan != null) ...[
                                      const SizedBox(height: 8),
                                      Row(
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.all(6),
                                            decoration: BoxDecoration(
                                              color: primaryTeal.withValues(alpha: 0.1),
                                              borderRadius: BorderRadius.circular(8),
                                            ),
                                            child: const Icon(CupertinoIcons.person_solid, size: 16, color: primaryTeal),
                                          ),
                                          const SizedBox(width: 10),
                                          Text('Relawan: $relawan', style: const TextStyle(color: Colors.black54, fontSize: 13)),
                                        ],
                                      ),
                                    ]
                                  ],
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
    );
  }
}
