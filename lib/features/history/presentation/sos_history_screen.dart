import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
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
    Color bgColor;
    Color textColor;

    switch (status.toLowerCase()) {
      case 'selesai':
        bgColor = Colors.green.shade100;
        textColor = Colors.green.shade800;
        break;
      case 'batal':
      case 'dibatalkan':
        bgColor = Colors.grey.shade200;
        textColor = Colors.grey.shade700;
        break;
      case 'proses':
        bgColor = Colors.blue.shade100;
        textColor = Colors.blue.shade800;
        break;
      default:
        bgColor = Colors.red.shade100;
        textColor = Colors.red.shade800;
    }

    String getDisplayStatus(String s) {
      final lower = s.toLowerCase();
      if (lower == 'batal' || lower == 'dibatalkan') return 'DIBATALKAN';
      if (lower == 'selesai') return 'SELESAI';
      if (lower == 'proses' || lower == 'ditangani') return 'SEDANG DITANGANI';
      if (lower == 'aktif') return 'MENUNGGU RELAWAN';
      return s.toUpperCase();
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        getDisplayStatus(status),
        style: TextStyle(
          color: textColor,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6F8),
      appBar: AppBar(
        title: const Text('Riwayat Khusus SOS', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: primaryTeal))
          : _errorMessage != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(CupertinoIcons.exclamationmark_triangle, size: 50, color: Colors.red.shade300),
                      const SizedBox(height: 16),
                      Text(_errorMessage!, textAlign: TextAlign.center, style: const TextStyle(color: Colors.red)),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _fetchSosHistory,
                        child: const Text('Coba Lagi'),
                      )
                    ],
                  ),
                )
              : _sosHistory.isEmpty
                  ? const Center(child: Text('Belum ada riwayat SOS.'))
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

                        return Card(
                          elevation: 0,
                          margin: const EdgeInsets.only(bottom: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          child: Padding(
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
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    _buildStatusBadge(status),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  children: [
                                    const Icon(CupertinoIcons.clock, size: 16, color: Colors.grey),
                                    const SizedBox(width: 6),
                                    Text(_formatDate(date), style: const TextStyle(color: Colors.grey, fontSize: 13)),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Row(
                                  children: [
                                    const Icon(CupertinoIcons.location, size: 16, color: Colors.grey),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: FutureBuilder<String>(
                                        future: _getAddress(item, index),
                                        builder: (context, snapshot) {
                                          return Text(
                                            snapshot.data ?? location,
                                            style: const TextStyle(color: Colors.grey, fontSize: 13),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          );
                                        },
                                      ),
                                    ),
                                  ],
                                ),
                                if (relawan != null) ...[
                                  const SizedBox(height: 6),
                                  Row(
                                    children: [
                                      const Icon(CupertinoIcons.person_solid, size: 16, color: Colors.grey),
                                      const SizedBox(width: 6),
                                      Text('Relawan: $relawan', style: const TextStyle(color: Colors.grey, fontSize: 13)),
                                    ],
                                  ),
                                ]
                              ],
                            ),
                          ),
                        );
                      },
                    ),
    );
  }
}
