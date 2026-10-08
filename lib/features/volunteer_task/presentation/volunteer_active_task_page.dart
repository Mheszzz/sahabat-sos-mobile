import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:sahabat_sos_mobile/core/di/injection.dart';
import 'package:sahabat_sos_mobile/features/volunteer_task/data/datasources/volunteer_remote_data_source.dart';
import 'package:sahabat_sos_mobile/core/utils/global_event_bus.dart'
    as import_event_bus;
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:dio/dio.dart';
import 'package:sahabat_sos_mobile/core/services/location_service.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:ui';
import 'package:sahabat_sos_mobile/features/volunteer_task/presentation/widgets/glass_container.dart';

class VolunteerActiveTaskPage extends StatefulWidget {
  const VolunteerActiveTaskPage({super.key});

  @override
  State<VolunteerActiveTaskPage> createState() =>
      _VolunteerActiveTaskPageState();
}

class _VolunteerActiveTaskPageState extends State<VolunteerActiveTaskPage> {
  static const Color primaryTeal = Color(0xFF006D77);
  static const Color sosRed = Color(0xFFC62828);
  static const Color bgColor = Color(0xFFF5F6F8);
  static const Color glassTeal = Color(0xFFE0F2F1);
  static const Color glassBlue = Color(0xFFE3F2FD);

  final _dataSource = sl<VolunteerRemoteDataSource>();
  final _locationService = sl<LocationService>();
  Map<String, dynamic>? _activeTask;
  bool _isLoading = true;

  LatLng? _effectiveVolPos;
  List<LatLng> _routePoints = [];
  String _etaText = 'Hitung...';
  bool _isFetchingRoute = false;
  final MapController _mapController = MapController();

  @override
  void initState() {
    super.initState();
    _fetchTask();
    import_event_bus.GlobalEventBus.refreshMap.addListener(_fetchTask);
  }

  @override
  void dispose() {
    import_event_bus.GlobalEventBus.refreshMap.removeListener(_fetchTask);
    _mapController.dispose();
    super.dispose();
  }

  Future<void> _fetchRoute(LatLng start, LatLng end) async {
    if (!mounted) return;
    setState(() {
      _isFetchingRoute = true;
    });
    try {
      final dio = Dio();
      final url =
          'https://router.project-osrm.org/route/v1/driving/${start.longitude},${start.latitude};${end.longitude},${end.latitude}?geometries=geojson';
      final response = await dio.get(url);

      if (response.statusCode == 200 && mounted) {
        if (response.data['routes'] == null ||
            (response.data['routes'] as List).isEmpty) {
          setState(() {
            _etaText = 'Gagal';
          });
          return;
        }
        final routes = response.data['routes'] as List;
        if (routes.isEmpty) {
          setState(() {
            _etaText = 'Gagal';
          });
        } else {
          final geometry = routes[0]['geometry'];
          final coords = geometry['coordinates'] as List;

          final durationSeconds = routes[0]['duration'] as num;
          final durationMins = (durationSeconds / 60).round();
          final distanceMeters = routes[0]['distance'] as num;

          String eta = '';
          if (durationMins > 0) {
            eta = '$durationMins Menit';
          } else {
            eta = '< 1 Menit';
          }
          if (distanceMeters > 1000) {
            eta += ' (${(distanceMeters / 1000).toStringAsFixed(1)}km)';
          } else {
            eta += ' (${distanceMeters.round()}m)';
          }

          setState(() {
            _etaText = eta;
            _routePoints = coords.map((coord) {
              return LatLng(coord[1] as double, coord[0] as double);
            }).toList();
          });

          // Tunggu sedikit agar map widget ter-render sebelum fitCamera
          Future.delayed(const Duration(milliseconds: 300), () {
            if (mounted && _routePoints.length > 1) {
              final bounds = LatLngBounds.fromPoints(_routePoints);
              _mapController.fitCamera(
                CameraFit.bounds(
                  bounds: bounds,
                  padding: const EdgeInsets.all(30.0),
                ),
              );
            }
          });
        }
      } else if (mounted) {
        setState(() {
          _etaText = 'Gagal';
        });
      }
    } catch (e) {
      debugPrint('Error fetching route: $e');
      if (mounted)
        setState(() {
          _etaText = 'Gagal';
        });
    } finally {
      if (mounted) {
        setState(() {
          _isFetchingRoute = false;
        });
      }
    }
  }

  Future<void> _fetchTask() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _routePoints.clear();
      _etaText = 'Hitung...';
    });
    try {
      final res = await _dataSource.getRelawanTasks();
      if (mounted) {
        setState(() {
          _activeTask = res['data'];
          _isLoading = false;
        });

        if (_activeTask != null) {
          final lat = double.tryParse(
            _activeTask!['latitude']?.toString() ?? '',
          );
          final lng = double.tryParse(
            _activeTask!['longitude']?.toString() ?? '',
          );
          final volPos = _locationService.currentPosition.value;

          if (lat != null && lng != null && volPos != null) {
            double vLat = volPos.latitude;
            double vLng = volPos.longitude;
            // Mock location if too far (e.g., using emulator in USA)
            if ((vLat - lat).abs() > 1 || (vLng - lng).abs() > 1) {
              vLat = lat - 0.015;
              vLng = lng - 0.015;
            }
            _effectiveVolPos = LatLng(vLat, vLng);

            if (_activeTask!['distance_formatted'] != null && _activeTask!['polyline'] != null) {
              setState(() {
                _etaText = '${_activeTask!['duration_formatted']} (${_activeTask!['distance_formatted']})';
                final List<dynamic> polyCoords = _activeTask!['polyline'];
                _routePoints = polyCoords.map((coord) {
                  return LatLng(coord[1] as double, coord[0] as double);
                }).toList();
              });

              // Tunggu sedikit agar map widget ter-render sebelum fitCamera
              Future.delayed(const Duration(milliseconds: 300), () {
                if (mounted && _routePoints.length > 1) {
                  final bounds = LatLngBounds.fromPoints(_routePoints);
                  _mapController.fitCamera(
                    CameraFit.bounds(
                      bounds: bounds,
                      padding: const EdgeInsets.all(30.0),
                    ),
                  );
                }
              });
            } else {
              _fetchRoute(_effectiveVolPos!, LatLng(lat, lng));
            }
          } else {
            setState(() {
              _etaText = 'Gagal (Lokasi?)';
            });
          }
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _activeTask = null;
          _isLoading = false;
        });
      }
    }
  }

  /// Buka navigasi eksternal (Google Maps)
  Future<void> _openExternalNavigation(double lat, double lng) async {
    final googleMapsUrl = Uri.parse(
      'https://www.google.com/maps/dir/?api=1&destination=$lat,$lng&travelmode=driving',
    );
    final googleMapsApp = Uri.parse('google.navigation:q=$lat,$lng&mode=d');

    if (!mounted) return;

    if (await canLaunchUrl(googleMapsApp)) {
      await launchUrl(googleMapsApp);
    } else {
      await launchUrl(googleMapsUrl, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _hubungiKontakDarurat() async {
    if (_activeTask == null) return;
    
    final idSos = _activeTask!['id'];
    
    bool? confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hubungi Kontak Darurat'),
        content: const Text('Yakin ingin mengirim notifikasi SOS ke kontak darurat korban?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Hubungi', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const Center(child: CircularProgressIndicator()),
      );
      
      // Default tipe "sos" untuk SOS aktif
      await _dataSource.hubungiKontakDarurat('sos', idSos);
      
      if (!mounted) return;
      Navigator.pop(context); // close loading
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Notifikasi telah dikirim ke kontak darurat korban')),
      );
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal menghubungi kontak darurat')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        body: Stack(
          children: [
            Positioned.fill(
              child: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color(0xFFE0F7FA),
                      Color(0xFFF1F8E9),
                      Color(0xFFE3F2FD),
                    ],
                  ),
                ),
              ),
            ),
            const Center(child: CupertinoActivityIndicator(radius: 16)),
          ],
        ),
      );
    }

    if (_activeTask == null) {
      return Scaffold(
        body: Stack(
          children: [
            Positioned.fill(
              child: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color(0xFFE0F7FA),
                      Color(0xFFF1F8E9),
                      Color(0xFFE3F2FD),
                    ],
                  ),
                ),
              ),
            ),
            Center(
              child: GlassContainer(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      CupertinoIcons.doc_text_search,
                      size: 64,
                      color: primaryTeal.withValues(alpha: 0.5),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Tidak ada tugas aktif.',
                      style: TextStyle(
                        color: Colors.black54,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    }

    final idSos = _activeTask!['id'] ?? '-';
    final pengguna = _activeTask!['pengguna'] ?? {};
    final nama = pengguna['name'] ?? 'Korban';
    final noTelp = pengguna['no_telp'] ?? '-';
    final lokasi =
        _activeTask!['lokasi_user'] ??
        _activeTask!['lokasi_laporan'] ??
        'Lokasi tidak diketahui';

    final kategoriUser = pengguna['kategori_user'] ?? 'Umum';
    final catatanMedis =
        (pengguna['catatan_medis'] != null &&
            pengguna['catatan_medis'].toString().isNotEmpty)
        ? pengguna['catatan_medis']
        : 'Tidak ada catatan medis spesifik';

    // Helper untuk menentukan protokol berdasarkan kategori
    String protocolText =
        'Tetap tenang, perkenalkan diri Anda dengan ramah, dan tanyakan bantuan apa yang dibutuhkan.';
    if (kategoriUser.toString().toLowerCase().contains('tunanetra')) {
      protocolText =
          'Dekati dari arah depan, sentuh pundak dengan izin, lalu sebutkan nama dan identitas resmi relawan Sahabat SOS secara perlahan dan artikulatif.';
    } else if (kategoriUser.toString().toLowerCase().contains('tunarungu') ||
        kategoriUser.toString().toLowerCase().contains('tuli')) {
      protocolText =
          'Sentuh pundak dengan lembut untuk menarik perhatian, bicara berhadapan agar gerak bibir terlihat, atau gunakan tulisan/isyarat sederhana.';
    } else if (kategoriUser.toString().toLowerCase().contains('tunadaksa')) {
      protocolText =
          'Tanyakan dulu bagaimana Anda bisa membantu memindahkan atau memosisikan mereka. Jangan menarik tubuh mereka tanpa instruksi.';
    }

    // Karena berada di halaman ini berarti tugas sudah diterima (proses),
    // posisinya selalu di langkah 2 (Sedang ditangani) menuju langkah 3 (Selesai).
    int currentStep = 2; // 1 = Diterima, 2 = Sedang ditangani, 3 = Selesai
    int totalSteps = 3;

    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.white.withValues(alpha: 0.15),
        elevation: 0,
        flexibleSpace: ClipRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(color: Colors.transparent),
          ),
        ),
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset('assets/images/logo.png', height: 24),
            const SizedBox(width: 8),
            const Text(
              'Sahabat SOS',
              style: TextStyle(
                color: primaryTeal,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ],
        ),
        centerTitle: true,
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 16),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.3),
              shape: BoxShape.circle,
            ),
            child: IconButton(
              icon: const Icon(
                CupertinoIcons.phone_fill,
                color: sosRed,
                size: 20,
              ),
              onPressed: () {},
            ),
          ),
        ],
      ),
      body: Stack(
        children: [
          // iOS Style Abstract Gradient Background
          Positioned.fill(
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFFE0F7FA),
                    Color(0xFFF1F8E9),
                    Color(0xFFE3F2FD),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            top: -50,
            left: -50,
            child: Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.tealAccent.withValues(alpha: 0.3),
              ),
            ),
          ),
          Positioned(
            bottom: -100,
            right: -50,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.blueAccent.withValues(alpha: 0.2),
              ),
            ),
          ),
          Positioned.fill(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
              child: Container(color: Colors.transparent),
            ),
          ),

          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  // Red header card -> GlassContainer
                  GlassContainer(
                    padding: const EdgeInsets.all(16),
                    color: sosRed.withValues(alpha: 0.75),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.4),
                      width: 1.5,
                    ),
                    borderRadius: BorderRadius.circular(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(
                              CupertinoIcons.time,
                              color: Colors.white70,
                              size: 14,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'ID: #SOS-' + idSos.toString(),
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Panggilan Darurat SOS',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(
                              CupertinoIcons.location_solid,
                              color: Colors.white,
                              size: 16,
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                lokasi,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Stepper -> GlassContainer
                  GlassContainer(
                    padding: const EdgeInsets.all(16),
                    borderRadius: BorderRadius.circular(20),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'TAHAPAN PENANGANAN',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: Colors.black54,
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: primaryTeal.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                'Langkah ' +
                                    currentStep.toString() +
                                    ' dari ' +
                                    totalSteps.toString(),
                                style: const TextStyle(
                                  color: primaryTeal,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Expanded(
                              child: _buildStep(
                                1,
                                'Diterima',
                                currentStep,
                                isFirst: true,
                              ),
                            ),
                            _buildLine(1, currentStep),
                            Expanded(
                              child: _buildStep(2, 'Ditangani', currentStep),
                            ),
                            _buildLine(2, currentStep),
                            Expanded(
                              child: _buildStep(
                                3,
                                'Selesai',
                                currentStep,
                                isLast: true,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Rute Tercepat -> GlassContainer
                  GlassContainer(
                    padding: const EdgeInsets.all(16),
                    borderRadius: BorderRadius.circular(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  CupertinoIcons.map,
                                  color: primaryTeal,
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                const Text(
                                  'Rute Tercepat ke\nKorban',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.green.shade50.withValues(
                                  alpha: 0.5,
                                ),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: Colors.green.shade200,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    CupertinoIcons.time,
                                    color: primaryTeal,
                                    size: 14,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    _etaText,
                                    style: const TextStyle(
                                      color: primaryTeal,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Container(
                          height: 150,
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: Colors.grey[200],
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: const [
                              BoxShadow(
                                color: Colors.black12,
                                blurRadius: 10,
                                offset: Offset(0, 5),
                              ),
                            ],
                          ),
                          child: Stack(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(16),
                                child: FlutterMap(
                                  mapController: _mapController,
                                  options: MapOptions(
                                    initialCenter: _routePoints.isNotEmpty
                                        ? _routePoints.first
                                        : (_activeTask != null &&
                                              _activeTask!['latitude'] !=
                                                  null &&
                                              _activeTask!['longitude'] != null)
                                        ? LatLng(
                                            double.tryParse(
                                                  _activeTask!['latitude']
                                                      .toString(),
                                                ) ??
                                                0.0,
                                            double.tryParse(
                                                  _activeTask!['longitude']
                                                      .toString(),
                                                ) ??
                                                0.0,
                                          )
                                        : _effectiveVolPos != null
                                        ? _effectiveVolPos!
                                        : const LatLng(-6.200000, 106.816666),
                                    initialZoom: 14.0,
                                    interactionOptions:
                                        const InteractionOptions(
                                          flags: InteractiveFlag
                                              .none, // Disable zoom, pan, etc.
                                        ),
                                  ),
                                  children: [
                                    TileLayer(
                                      urlTemplate:
                                          'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                                      userAgentPackageName:
                                          'com.sahabat_sos_mobile.app',
                                    ),
                                    if (_routePoints.isNotEmpty)
                                      PolylineLayer(
                                        polylines: [
                                          Polyline(
                                            points: _routePoints,
                                            color: primaryTeal,
                                            strokeWidth: 4.0,
                                          ),
                                        ],
                                      ),
                                    MarkerLayer(
                                      markers: [
                                        // Volunteer marker
                                        if (_effectiveVolPos != null)
                                          Marker(
                                            point: _effectiveVolPos!,
                                            width: 24,
                                            height: 24,
                                            child: Container(
                                              decoration: BoxDecoration(
                                                color: Colors.blue,
                                                shape: BoxShape.circle,
                                                border: Border.all(
                                                  color: Colors.white,
                                                  width: 2,
                                                ),
                                                boxShadow: const [
                                                  BoxShadow(
                                                    color: Colors.black26,
                                                    blurRadius: 4,
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        // Victim marker
                                        if (_activeTask != null &&
                                            _activeTask!['latitude'] != null &&
                                            _activeTask!['longitude'] != null)
                                          Marker(
                                            point: LatLng(
                                              double.tryParse(
                                                    _activeTask!['latitude']
                                                        .toString(),
                                                  ) ??
                                                  0.0,
                                              double.tryParse(
                                                    _activeTask!['longitude']
                                                        .toString(),
                                                  ) ??
                                                  0.0,
                                            ),
                                            width: 32,
                                            height: 32,
                                            child: const Icon(
                                              CupertinoIcons.location_solid,
                                              color: sosRed,
                                              size: 32,
                                            ),
                                          ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              if (_isFetchingRoute)
                                const Center(
                                  child: CircularProgressIndicator(
                                    color: primaryTeal,
                                  ),
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: () {
                              final lat = double.tryParse(
                                _activeTask!['latitude']?.toString() ?? '',
                              );
                              final lng = double.tryParse(
                                _activeTask!['longitude']?.toString() ?? '',
                              );
                              if (lat != null && lng != null) {
                                _openExternalNavigation(lat, lng);
                              }
                            },
                            icon: const Icon(
                              CupertinoIcons.arrow_up_right_square,
                              size: 16,
                              color: primaryTeal,
                            ),
                            label: const Text(
                              'Buka Google Maps',
                              style: TextStyle(
                                color: primaryTeal,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white.withValues(
                                alpha: 0.5,
                              ),
                              elevation: 0,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                                side: BorderSide(
                                  color: Colors.white.withValues(alpha: 0.8),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // User Info -> GlassContainer
                  GlassContainer(
                    padding: const EdgeInsets.all(16),
                    borderRadius: BorderRadius.circular(20),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            CircleAvatar(
                              backgroundColor: Colors.white.withValues(
                                alpha: 0.5,
                              ),
                              radius: 24,
                              child: const Icon(
                                CupertinoIcons.person,
                                color: primaryTeal,
                                size: 24,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Text(
                                        nama,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      if (kategoriUser.toLowerCase() !=
                                              'umum' &&
                                          kategoriUser != '')
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 6,
                                            vertical: 2,
                                          ),
                                          decoration: BoxDecoration(
                                            color: Colors.blue.shade50
                                                .withValues(alpha: 0.8),
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
                                          ),
                                          child: Row(
                                            children: [
                                              Icon(
                                                CupertinoIcons.eye_slash_fill,
                                                color: Colors.blue.shade700,
                                                size: 10,
                                              ),
                                              const SizedBox(width: 4),
                                              Text(
                                                kategoriUser,
                                                style: TextStyle(
                                                  color: Colors.blue.shade700,
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    catatanMedis,
                                    style: const TextStyle(
                                      color: Colors.black87,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.amber.shade50.withValues(alpha: 0.6),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: Colors.amber.shade200.withValues(
                                alpha: 0.5,
                              ),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    CupertinoIcons.info_circle,
                                    color: Colors.amber.shade800,
                                    size: 16,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    'Protokol Interaksi:',
                                    style: TextStyle(
                                      color: Colors.amber.shade900,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Text(
                                protocolText,
                                style: TextStyle(
                                  color: Colors.amber.shade900,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: () {},
                                icon: const Icon(
                                  CupertinoIcons.phone,
                                  size: 16,
                                  color: primaryTeal,
                                ),
                                label: const Text(
                                  'Panggil',
                                  style: TextStyle(color: primaryTeal),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.white.withValues(
                                    alpha: 0.5,
                                  ),
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    side: const BorderSide(color: Colors.white),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: () {},
                                icon: const Icon(
                                  CupertinoIcons.chat_bubble,
                                  size: 16,
                                  color: primaryTeal,
                                ),
                                label: const Text(
                                  'Chat',
                                  style: TextStyle(color: primaryTeal),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.white.withValues(
                                    alpha: 0.5,
                                  ),
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    side: const BorderSide(color: Colors.white),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: _hubungiKontakDarurat,
                            icon: const Icon(
                              CupertinoIcons.exclamationmark_triangle_fill,
                              color: sosRed,
                              size: 16,
                            ),
                            label: const Text(
                              'Hubungi Kontak Darurat Korban',
                              style: TextStyle(color: sosRed, fontWeight: FontWeight.bold),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red.shade50.withValues(
                                alpha: 0.8,
                              ),
                              elevation: 0,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                                side: BorderSide(color: sosRed.withValues(alpha: 0.3)),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Actions
                  SizedBox(
                    width: double.infinity,
                    child: SlideToCompleteButton(
                      label: 'Kasus Telah Selesai',
                      onCompleted: () async {
                        try {
                          await _dataSource.updateSosStatus(
                            int.parse(idSos.toString()),
                            'selesai',
                          );
                          import_event_bus.GlobalEventBus.refreshMap.value =
                              !import_event_bus.GlobalEventBus.refreshMap.value;
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Tugas telah diselesaikan.'),
                              ),
                            );
                          }
                        } catch (e) {
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  'Gagal menyelesaikan: ' + e.toString(),
                                ),
                              ),
                            );
                          }
                        }
                      },
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () {},
                      icon: const Icon(
                        CupertinoIcons.shield,
                        color: sosRed,
                        size: 20,
                      ),
                      label: const Text(
                        'Minta Bantuan Tambahan Relawan',
                        style: TextStyle(
                          color: sosRed,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red.shade50.withValues(
                          alpha: 0.7,
                        ),
                        elevation: 0,
                        side: BorderSide(color: Colors.red.shade200),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 100), // padding for bottom nav
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStep(
    int stepNum,
    String label,
    int currentStep, {
    bool isFirst = false,
    bool isLast = false,
  }) {
    bool isCompleted = stepNum < currentStep;
    bool isActive = stepNum == currentStep;

    IconData? icon;
    if (isCompleted) {
      icon = CupertinoIcons.check_mark;
    } else if (isActive && stepNum == 2) {
      icon = CupertinoIcons.location_solid; // "Ditangani / Sedang Menuju"
    } else if (isActive && stepNum == 3) {
      icon = CupertinoIcons.flag_fill;
    }

    return Column(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: isCompleted || isActive
                ? primaryTeal
                : Colors.white.withValues(alpha: 0.5),
            shape: BoxShape.circle,
            border: Border.all(
              color: isCompleted || isActive
                  ? Colors.transparent
                  : Colors.white,
              width: 2,
            ),
            boxShadow: [
              if (isActive)
                BoxShadow(
                  color: primaryTeal.withValues(alpha: 0.3),
                  blurRadius: 8,
                  spreadRadius: 2,
                ),
            ],
          ),
          child: icon != null
              ? Icon(icon, size: 16, color: Colors.white)
              : Center(
                  child: Text(
                    stepNum.toString(),
                    style: TextStyle(
                      color: isCompleted || isActive
                          ? Colors.white
                          : Colors.grey[500],
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
        ),
        const SizedBox(height: 6),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: isActive
                ? primaryTeal
                : (isCompleted ? Colors.black87 : Colors.grey),
            fontWeight: isActive || isCompleted
                ? FontWeight.bold
                : FontWeight.normal,
          ),
        ),
      ],
    );
  }

  Widget _buildLine(int stepNum, int currentStep) {
    bool isCompleted = stepNum < currentStep;
    return Expanded(
      child: Container(
        height: 2,
        margin: const EdgeInsets.only(bottom: 14), // align with circle center
        color: isCompleted ? primaryTeal : Colors.grey[300],
      ),
    );
  }
}

class SlideToCompleteButton extends StatefulWidget {
  final VoidCallback onCompleted;
  final String label;

  const SlideToCompleteButton({
    super.key,
    required this.onCompleted,
    this.label = 'Geser untuk menyelesaikan',
  });

  @override
  State<SlideToCompleteButton> createState() => _SlideToCompleteButtonState();
}

class _SlideToCompleteButtonState extends State<SlideToCompleteButton> {
  double _dragPosition = 0.0;
  bool _isCompleted = false;
  final double _thumbSize = 60.0;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxWidth = constraints.maxWidth;
        final maxDrag = maxWidth - _thumbSize;

        return Container(
          width: maxWidth,
          height: _thumbSize,
          decoration: BoxDecoration(
            color: const Color(0xFFE2EBEB), // Light teal-gray from image
            borderRadius: BorderRadius.circular(_thumbSize / 2),
            border: Border.all(color: const Color(0xFFB0C4C4)),
          ),
          child: Stack(
            children: [
              // 1. Base Text (Dark Teal)
              Center(
                child: Text(
                  _isCompleted ? "Memproses..." : widget.label,
                  style: const TextStyle(
                    color: Color(0xFF006D77),
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),

              // 2. Peeling / Fill Effect (Solid Teal expanding)
              AnimatedContainer(
                duration: _dragPosition == 0.0
                    ? const Duration(milliseconds: 300)
                    : Duration.zero,
                width: _dragPosition + _thumbSize,
                height: _thumbSize,
                decoration: BoxDecoration(
                  color: const Color(0xFF006D77),
                  borderRadius: BorderRadius.circular(_thumbSize / 2),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(_thumbSize / 2),
                  child: Stack(
                    children: [
                      // Render the white text perfectly aligned with the base text
                      Positioned(
                        left: 0,
                        width:
                            maxWidth, // Force same width as parent to keep text centered
                        child: Container(
                          height: _thumbSize,
                          alignment: Alignment.center,
                          child: Text(
                            _isCompleted ? "Memproses..." : widget.label,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // 3. Draggable Thumb
              AnimatedPositioned(
                duration: _dragPosition == 0.0
                    ? const Duration(milliseconds: 300)
                    : Duration.zero,
                curve: Curves.easeOutBack,
                left: _dragPosition,
                child: GestureDetector(
                  onHorizontalDragUpdate: (details) {
                    if (_isCompleted) return;
                    setState(() {
                      _dragPosition += details.delta.dx;
                      if (_dragPosition < 0) _dragPosition = 0;
                      if (_dragPosition > maxDrag) _dragPosition = maxDrag;
                    });
                  },
                  onHorizontalDragEnd: (details) {
                    if (_isCompleted) return;
                    if (_dragPosition > maxDrag * 0.75) {
                      setState(() {
                        _dragPosition = maxDrag;
                        _isCompleted = true;
                      });
                      widget.onCompleted();
                    } else {
                      setState(() {
                        _dragPosition = 0.0; // Snap back
                      });
                    }
                  },
                  child: Container(
                    width: _thumbSize,
                    height: _thumbSize,
                    decoration: BoxDecoration(
                      color: const Color(0xFF006D77),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.25),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.keyboard_double_arrow_right,
                      color: Colors.white,
                      size: 36,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
