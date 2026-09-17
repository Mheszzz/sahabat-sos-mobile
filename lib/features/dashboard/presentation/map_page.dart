import 'dart:async';
import 'dart:ui';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:sahabat_sos_mobile/routing/routes.dart';
import 'package:sahabat_sos_mobile/core/services/location_service.dart';
import 'package:sahabat_sos_mobile/core/di/injection.dart';
import 'package:geolocator/geolocator.dart';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sahabat_sos_mobile/core/constants/api_constants.dart';

class MapPage extends StatefulWidget {
  const MapPage({super.key});

  @override
  State<MapPage> createState() => _MapPageState();
}

class _MapPageState extends State<MapPage> {
  static const Color primaryTeal = Color(0xFF00695C);
  final _locationService = sl<LocationService>();
  StreamSubscription<ServiceStatus>? _serviceStatusStream;
  bool _isDialogShowing = false;
  final MapController _mapController = MapController();
  bool _isFirstFix = true;

  @override
  void initState() {
    super.initState();
    _checkLocation();
    _listenToLocationServiceChanges();
    
    // Auto-center map hanya pada fix pertama, dan saat user belum panning
    _locationService.currentPosition.addListener(_onPositionUpdate);
  }

  void _onPositionUpdate() {
    final pos = _locationService.currentPosition.value;
    if (pos != null && _isFirstFix) {
      _mapController.move(LatLng(pos.latitude, pos.longitude), 15.0);
      _isFirstFix = false;
      _fetchNearbyReports(pos.latitude, pos.longitude);
    }
  }

  List<dynamic> _nearbyReports = [];

  Future<void> _fetchNearbyReports(double lat, double lng) async {
    try {
      final prefs = sl<SharedPreferences>();
      final token = prefs.getString('auth_token');
      if (token == null) return;

      final response = await sl<Dio>().get(
        ApiConstants.laporanNearby,
        queryParameters: {
          'latitude': lat,
          'longitude': lng,
          'radius': 10, // 10 KM
        },
        options: Options(headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        }),
      );

      if (response.statusCode == 200 && mounted) {
        setState(() {
          _nearbyReports = response.data['data'] ?? [];
        });
      }
    } catch (e) {
      debugPrint('Gagal fetch nearby reports: $e');
    }
  }

  void _listenToLocationServiceChanges() {
    _serviceStatusStream = Geolocator.getServiceStatusStream().listen(
      (ServiceStatus status) {
        if (status == ServiceStatus.disabled) {
          _locationService.stopTracking();
          if (!_isDialogShowing) {
            _showLocationDeniedDialog();
          }
        } else if (status == ServiceStatus.enabled) {
          if (_isDialogShowing) {
            Navigator.pop(context); // Tutup dialog
            _isDialogShowing = false;
          }
          _checkLocation(); 
        }
      },
    );
  }

  Future<void> _checkLocation() async {
    final hasPermission = await _locationService.requestPermission();
    if (!hasPermission) {
      if (!mounted) return;
      if (!_isDialogShowing) {
        _showLocationDeniedDialog();
      }
    } else {
      _locationService.startTracking();
    }
  }

  void _showLocationDeniedDialog() {
    _isDialogShowing = true;
    showDialog(
      context: context,
      barrierDismissible: false, // Wajib menyalakan GPS
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('Akses Lokasi Dibutuhkan'),
          content: const Text(
            'Aplikasi ini membutuhkan akses GPS untuk mendeteksi lokasi keadaan darurat.\n\nHarap nyalakan GPS dan berikan izin lokasi di pengaturan HP Anda.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                _isDialogShowing = false;
                context.go(AppRoutes.login);
              },
              child: const Text('Batal & Keluar', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              onPressed: () {
                _isDialogShowing = false;
                Navigator.pop(context);
                _checkLocation(); // Cek lagi
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryTeal,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Coba Lagi'),
            ),
          ],
        );
      },
    ).then((_) {
      _isDialogShowing = false;
    });
  }

  @override
  void dispose() {
    _locationService.currentPosition.removeListener(_onPositionUpdate);
    _serviceStatusStream?.cancel();
    _locationService.stopTracking();
    _mapController.dispose();
    super.dispose();
  }

  Widget _buildGlassContainer({required Widget child, EdgeInsetsGeometry? padding}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: padding ?? const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withValues(alpha: 0.8), width: 1.5),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: child,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text(
          'Peta Darurat',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: primaryTeal,
          ),
        ),
        backgroundColor: Colors.white.withValues(alpha: 0.5),
        elevation: 0,
        centerTitle: true,
        flexibleSpace: ClipRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(color: Colors.transparent),
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: primaryTeal),
          onPressed: () => context.pop(),
        ),
      ),
      body: ValueListenableBuilder<Position?>(
        valueListenable: _locationService.currentPosition,
        builder: (context, position, child) {
          if (position == null) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: primaryTeal),
                  SizedBox(height: 16),
                  Text('Menunggu Sinyal GPS...', style: TextStyle(color: primaryTeal, fontWeight: FontWeight.w500)),
                ],
              ),
            );
          }

          final latLng = LatLng(position.latitude, position.longitude);

          return Stack(
            children: [
              FlutterMap(
                mapController: _mapController,
                options: MapOptions(
                  initialCenter: latLng,
                  initialZoom: 17.0,
                ),
                children: [
                  TileLayer(
                    urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'com.sahabat_sos_mobile.app',
                  ),
                  MarkerLayer(
                    markers: [
                      // Marker Lokasi Saat Ini
                      Marker(
                        point: latLng,
                        width: 60,
                        height: 60,
                        child: Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.blue.withValues(alpha: 0.2),
                          ),
                          child: const Center(
                            child: Icon(
                              Icons.my_location,
                              color: Colors.blue,
                              size: 30,
                            ),
                          ),
                        ),
                      ),
                      // Marker Laporan Darurat
                      ..._nearbyReports.map((report) {
                        final lat = double.tryParse(report['latitude'].toString()) ?? 0.0;
                        final lng = double.tryParse(report['longitude'].toString()) ?? 0.0;
                        return Marker(
                          point: LatLng(lat, lng),
                          width: 50,
                          height: 50,
                          child: GestureDetector(
                            onTap: () {
                              _showGlassBottomSheet(context, report);
                            },
                            child: const Icon(
                              Icons.location_on,
                              color: Colors.redAccent,
                              size: 40,
                              shadows: [
                                Shadow(
                                  blurRadius: 10,
                                  color: Colors.black26,
                                  offset: Offset(0, 4),
                                )
                              ],
                            ),
                          ),
                        );
                      }),
                    ],
                  ),
                ],
              ),
              
              // Kartu Lokasi Bawah (Glassmorphism)
              Positioned(
                bottom: 30,
                left: 20,
                right: 20,
                child: SafeArea(
                  child: _buildGlassContainer(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: primaryTeal.withValues(alpha: 0.1),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.gps_fixed, color: primaryTeal, size: 20),
                            ),
                            const SizedBox(width: 12),
                            const Text(
                              'Lokasi Anda Saat Ini',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color: primaryTeal,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            _buildInfoColumn('Latitude', position.latitude.toStringAsFixed(5)),
                            _buildInfoColumn('Longitude', position.longitude.toStringAsFixed(5)),
                            _buildInfoColumn('Akurasi', '±${position.accuracy.toStringAsFixed(1)} m'),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // Tombol Recenter Lokasi
              Positioned(
                bottom: 160,
                right: 20,
                child: FloatingActionButton(
                  backgroundColor: Colors.white.withValues(alpha: 0.9),
                  elevation: 2,
                  onPressed: () {
                    _mapController.move(latLng, 17.0);
                  },
                  child: const Icon(Icons.my_location, color: primaryTeal),
                ),
              )
            ],
          );
        },
      ),
    );
  }

  Widget _buildInfoColumn(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: Colors.black54),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
      ],
    );
  }

  void _showGlassBottomSheet(BuildContext context, dynamic report) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        margin: const EdgeInsets.all(16),
        child: _buildGlassContainer(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.grey.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.red.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.warning_rounded, color: Colors.red),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      report['kategori_laporan'] ?? 'Laporan Darurat',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold, 
                        fontSize: 18,
                        color: Colors.black87,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _buildDetailRow(Icons.info_outline, 'Status', report['status'] ?? '-'),
              const SizedBox(height: 12),
              _buildDetailRow(Icons.location_on_outlined, 'Lokasi', report['lokasi_laporan'] ?? 'Tidak diketahui'),
              if (report['distance_km'] != null) ...[
                const SizedBox(height: 12),
                _buildDetailRow(Icons.route_outlined, 'Jarak', '${report['distance_km']} KM'),
              ],
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: Colors.black54),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(fontSize: 12, color: Colors.black54),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(fontSize: 14, color: Colors.black87, fontWeight: FontWeight.w500),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

