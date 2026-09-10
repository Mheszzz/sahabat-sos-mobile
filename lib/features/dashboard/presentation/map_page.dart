import 'dart:async';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:sahabat_sos_mobile/routing/routes.dart';
import 'package:sahabat_sos_mobile/core/services/location_service.dart';
import 'package:sahabat_sos_mobile/core/di/injection.dart';
import 'package:geolocator/geolocator.dart';

class MapPage extends StatefulWidget {
  const MapPage({super.key});

  @override
  State<MapPage> createState() => _MapPageState();
}

class _MapPageState extends State<MapPage> {
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
      _mapController.move(LatLng(pos.latitude, pos.longitude), 17.0);
      _isFirstFix = false;
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
              child: const Text('Batal & Keluar'),
            ),
            ElevatedButton(
              onPressed: () {
                _isDialogShowing = false;
                Navigator.pop(context);
                _checkLocation(); // Cek lagi
              },
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Peta Darurat'),
        backgroundColor: const Color(0xFF006D77),
        foregroundColor: Colors.white,
      ),
      body: ValueListenableBuilder<Position?>(
        valueListenable: _locationService.currentPosition,
        builder: (context, position, child) {
          if (position == null) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: Color(0xFF006D77)),
                  SizedBox(height: 16),
                  Text('Menunggu Sinyal GPS...'),
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
                      Marker(
                        point: latLng,
                        width: 50,
                        height: 50,
                        child: const Icon(
                          Icons.my_location,
                          color: Colors.blue,
                          size: 40,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              Positioned(
                bottom: 20,
                left: 20,
                right: 20,
                child: Card(
                  elevation: 4,
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          'Lokasi Anda Saat Ini',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        Text('Lat: ${position.latitude}'),
                        Text('Lng: ${position.longitude}'),
                        Text('Akurasi: \u00b1${position.accuracy.toStringAsFixed(1)} meter'),
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
}
