import 'dart:async';
import 'dart:ui';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
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
            if (mounted) Navigator.pop(context); // Tutup dialog
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

  Widget _buildGlassContainer(BuildContext context, {required Widget child, EdgeInsetsGeometry? padding}) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          padding: padding ?? const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDarkMode 
                ? Colors.black.withValues(alpha: 0.4)
                : Colors.white.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: isDarkMode
                  ? Colors.white.withValues(alpha: 0.1)
                  : Colors.white.withValues(alpha: 0.3),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 15,
                offset: const Offset(0, 5),
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
    final theme = Theme.of(context);
    final primaryColor = theme.colorScheme.primary;
    final isDarkMode = theme.brightness == Brightness.dark;

    return Scaffold(
      extendBodyBehindAppBar: true,
      body: ValueListenableBuilder<Position?>(
        valueListenable: _locationService.currentPosition,
        builder: (context, position, child) {
          if (position == null) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: primaryColor),
                  const SizedBox(height: 16),
                  Text('Menunggu Sinyal GPS...', style: TextStyle(color: primaryColor, fontWeight: FontWeight.w500)),
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
                  ColorFiltered(
                    colorFilter: isDarkMode
                        ? const ColorFilter.matrix([
                            -1,  0,  0, 0, 255,
                             0, -1,  0, 0, 255,
                             0,  0, -1, 0, 255,
                             0,  0,  0, 1,   0,
                          ])
                        : const ColorFilter.mode(Colors.transparent, BlendMode.multiply),
                    child: TileLayer(
                      urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.sahabat_sos_mobile.app',
                    ),
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

              // Top Left: Back Button
              Positioned(
                top: MediaQuery.paddingOf(context).top + 16,
                left: 16,
                child: _buildGlassContainer(
                  context,
                  padding: const EdgeInsets.all(4),
                  child: IconButton(
                    icon: Icon(CupertinoIcons.back, color: isDarkMode ? Colors.white : Colors.black87),
                    onPressed: () => context.pop(),
                  ),
                ),
              ),

              // Top Right: Apple Maps style controls (Info, Recenter, 2D)
              Positioned(
                top: MediaQuery.paddingOf(context).top + 16,
                right: 16,
                child: _buildGlassContainer(
                  context,
                  padding: EdgeInsets.zero,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(CupertinoIcons.info, color: Colors.blue),
                        onPressed: () {},
                      ),
                      Container(
                        height: 1,
                        width: 40,
                        color: isDarkMode ? Colors.white24 : Colors.black12,
                      ),
                      IconButton(
                        icon: const Icon(CupertinoIcons.location, color: Colors.blue),
                        onPressed: () {
                          _mapController.move(latLng, 17.0);
                        },
                      ),
                      Container(
                        height: 1,
                        width: 40,
                        color: isDarkMode ? Colors.white24 : Colors.black12,
                      ),
                      TextButton(
                        onPressed: () {},
                        style: TextButton.styleFrom(
                          padding: EdgeInsets.zero,
                          minimumSize: const Size(48, 48),
                        ),
                        child: const Text('2D', style: TextStyle(color: Colors.blue, fontWeight: FontWeight.bold, fontSize: 16)),
                      ),
                    ],
                  ),
                ),
              ),
              
              // Kartu Lokasi Bawah (Glassmorphism)
              Positioned(
                bottom: 100, // Diperbesar agar tidak tertimpa navbar
                left: 20,
                right: 20,
                child: SafeArea(
                  child: _buildGlassContainer(
                    context,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: primaryColor.withValues(alpha: 0.1),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(Icons.gps_fixed, color: primaryColor, size: 20),
                            ),
                            const SizedBox(width: 12),
                            Text(
                              'Lokasi Anda Saat Ini',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color: primaryColor,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            _buildInfoColumn(context, 'Latitude', position.latitude.toStringAsFixed(5)),
                            _buildInfoColumn(context, 'Longitude', position.longitude.toStringAsFixed(5)),
                            _buildInfoColumn(context, 'Akurasi', '±${position.accuracy.toStringAsFixed(1)} m'),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildInfoColumn(BuildContext context, String label, String value) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(fontSize: 12, color: isDarkMode ? Colors.white54 : Colors.black54),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: isDarkMode ? Colors.white70 : Colors.black87,
          ),
        ),
      ],
    );
  }

  void _showGlassBottomSheet(BuildContext context, dynamic report) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(ctx).bottom + MediaQuery.paddingOf(ctx).bottom,
        ),
        child: Container(
          margin: const EdgeInsets.all(16),
          child: _buildGlassContainer(
          context,
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
                    color: isDarkMode ? Colors.white24 : Colors.grey.withValues(alpha: 0.5),
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
                      style: TextStyle(
                        fontWeight: FontWeight.bold, 
                        fontSize: 18,
                        color: isDarkMode ? Colors.white : Colors.black87,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _buildDetailRow(context, Icons.info_outline, 'Status', report['status'] ?? '-'),
              const SizedBox(height: 12),
              _buildDetailRow(context, Icons.location_on_outlined, 'Lokasi', report['lokasi_laporan'] ?? 'Tidak diketahui'),
              if (report['distance_km'] != null) ...[
                const SizedBox(height: 12),
                _buildDetailRow(context, Icons.route_outlined, 'Jarak', '${report['distance_km']} KM'),
              ],
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
      ),
    );
  }

  Widget _buildDetailRow(BuildContext context, IconData icon, String label, String value) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: isDarkMode ? Colors.white54 : Colors.black54),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(fontSize: 12, color: isDarkMode ? Colors.white54 : Colors.black54),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: TextStyle(fontSize: 14, color: isDarkMode ? Colors.white : Colors.black87, fontWeight: FontWeight.w500),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

