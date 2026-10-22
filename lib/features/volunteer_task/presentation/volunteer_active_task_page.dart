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
import 'package:sahabat_sos_mobile/core/constants/api_constants.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:ui';
import 'package:sahabat_sos_mobile/core/services/accessibility_service.dart';
import 'package:sahabat_sos_mobile/features/volunteer_task/presentation/widgets/glass_container.dart';

class VolunteerActiveTaskPage extends StatefulWidget {
  final Map<String, dynamic>? initialTask;
  const VolunteerActiveTaskPage({super.key, this.initialTask});

  @override
  State<VolunteerActiveTaskPage> createState() =>
      _VolunteerActiveTaskPageState();
}

class _VolunteerActiveTaskPageState extends State<VolunteerActiveTaskPage> {
  static const Color primaryTeal = Color(0xFF006D77);
  static const Color sosRed = Color(0xFFC62828);

  final _dataSource = sl<VolunteerRemoteDataSource>();
  final _locationService = sl<LocationService>();
  Map<String, dynamic>? _activeTask;
  bool _isLoading = true;
  bool _isCompleting = false;

  LatLng? _effectiveVolPos;
  List<LatLng> _routePoints = [];
  String _etaText = 'Hitung...';
  bool _isFetchingRoute = false;
  final MapController _mapController = MapController();

  @override
  void initState() {
    super.initState();
    if (widget.initialTask != null) {
      _activeTask = Map<String, dynamic>.from(widget.initialTask!);
      _isLoading = false;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _initTaskRoute();
      });
    }
    _fetchTask();
    import_event_bus.GlobalEventBus.refreshMap.addListener(_fetchTask);

    // Memastikan tracking live GPS relawan aktif dan marker relawan terupdate secara real-time
    _locationService.startTracking();
    _locationService.currentPosition.addListener(_onLivePositionChanged);
  }

  @override
  void dispose() {
    _locationService.currentPosition.removeListener(_onLivePositionChanged);
    import_event_bus.GlobalEventBus.refreshMap.removeListener(_fetchTask);
    _mapController.dispose();
    super.dispose();
  }

  void _onLivePositionChanged() {
    final pos = _locationService.currentPosition.value;
    if (pos == null || !mounted) return;

    final lat = double.tryParse(
      _activeTask?['latitude']?.toString() ??
          _activeTask?['lokasi']?['latitude']?.toString() ??
          '',
    );
    final lng = double.tryParse(
      _activeTask?['longitude']?.toString() ??
          _activeTask?['lokasi']?['longitude']?.toString() ??
          '',
    );

    double vLat = pos.latitude;
    double vLng = pos.longitude;

    if (lat != null && lng != null) {
      if ((vLat - lat).abs() > 1 || (vLng - lng).abs() > 1) {
        vLat = lat - 0.015;
        vLng = lng - 0.015;
      }
    }

    setState(() {
      _effectiveVolPos = LatLng(vLat, vLng);
    });
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
              final num latVal = coord[1] as num;
              final num lngVal = coord[0] as num;
              return LatLng(latVal.toDouble(), lngVal.toDouble());
            }).toList();
          });

          // Tunggu sedikit agar map widget ter-render sebelum fitCamera
          Future.delayed(const Duration(milliseconds: 300), () {
            if (mounted && _routePoints.length > 1) {
              final bounds = LatLngBounds.fromPoints(_routePoints);
              _mapController.fitCamera(
                CameraFit.bounds(
                  bounds: bounds,
                  padding: const EdgeInsets.all(24.0),
                  maxZoom: 16.0,
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
      if (mounted) {
        setState(() {
          _etaText = 'Gagal';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isFetchingRoute = false;
        });
      }
    }
  }

  void _initTaskRoute() {
    if (_activeTask == null || !mounted) return;

    final lat = double.tryParse(
      _activeTask!['latitude']?.toString() ??
          _activeTask!['lokasi']?['latitude']?.toString() ??
          '',
    );
    final lng = double.tryParse(
      _activeTask!['longitude']?.toString() ??
          _activeTask!['lokasi']?['longitude']?.toString() ??
          '',
    );
    final volPos = _locationService.currentPosition.value;

    if (lat != null && lng != null) {
      double vLat;
      double vLng;
      if (volPos != null) {
        vLat = volPos.latitude;
        vLng = volPos.longitude;
        if ((vLat - lat).abs() > 1 || (vLng - lng).abs() > 1) {
          vLat = lat - 0.015;
          vLng = lng - 0.015;
        }
      } else {
        // Fallback jika GPS belum siap: gunakan offset dekat titik tujuan
        vLat = lat - 0.008;
        vLng = lng - 0.008;
      }
      _effectiveVolPos = LatLng(vLat, vLng);

      final routeInfo = _activeTask!['route_info'];
      final polylineData = _activeTask!['polyline'] ??
          (routeInfo != null ? routeInfo['polyline'] : null);
      final durationStr = _activeTask!['duration_formatted'] ??
          (routeInfo != null ? routeInfo['duration_formatted'] : null);
      final distanceStr = _activeTask!['distance_formatted'] ??
          (routeInfo != null ? routeInfo['distance_formatted'] : null);

      if (distanceStr != null && polylineData != null) {
        setState(() {
          _etaText = '$durationStr ($distanceStr)';
          final List<dynamic> polyCoords = polylineData;
          _routePoints = polyCoords.map((coord) {
            final num latVal = coord[1] as num;
            final num lngVal = coord[0] as num;
            return LatLng(latVal.toDouble(), lngVal.toDouble());
          }).toList();
        });

        Future.delayed(const Duration(milliseconds: 300), () {
          if (mounted && _routePoints.length > 1) {
            final bounds = LatLngBounds.fromPoints(_routePoints);
            _mapController.fitCamera(
              CameraFit.bounds(
                bounds: bounds,
                padding: const EdgeInsets.all(24.0),
                maxZoom: 16.0,
              ),
            );
          }
        });
      } else if (_effectiveVolPos != null) {
        _fetchRoute(_effectiveVolPos!, LatLng(lat, lng));
      }
    } else {
      setState(() {
        _etaText = 'Gagal (Lokasi?)';
      });
    }
  }

  Future<void> _fetchTask() async {
    if (!mounted || _isCompleting) return;
    if (_activeTask == null) {
      setState(() {
        _isLoading = true;
        _routePoints.clear();
        _etaText = 'Hitung...';
      });
    }
    try {
      final res = await _dataSource.getRelawanTasks();
      if (mounted) {
        if (res['data'] != null) {
          setState(() {
            _activeTask = Map<String, dynamic>.from(res['data'] as Map);
            _isLoading = false;
          });
          _initTaskRoute();
        } else if (_activeTask == null) {
          setState(() {
            _activeTask = null;
            _isLoading = false;
          });
        } else {
          // Tetap pertahankan _activeTask yang sudah diisi lewat initialTask
          setState(() {
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      debugPrint('Error fetch task: $e');
      if (mounted) {
        setState(() {
          _activeTask ??= null;
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

    final isHighContrast =
        AccessibilityService.instance.isHighContrastEnabled ||
        Theme.of(context).brightness == Brightness.dark ||
        MediaQuery.of(context).highContrast;
    final dialogBg = isHighContrast ? const Color(0xFF121212) : Colors.white;
    final textPrimary = isHighContrast ? Colors.white : const Color(0xFF111827);
    final textSecondary =
        isHighContrast ? const Color(0xFFD1D5DB) : const Color(0xFF4B5563);

    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: dialogBg,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: isHighContrast
              ? const BorderSide(color: Color(0xFF4B5563), width: 1.5)
              : BorderSide.none,
        ),
        title: Text(
          'Hubungi Kontak Darurat',
          style: TextStyle(
            color: textPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          'Yakin ingin mengirim notifikasi SOS ke kontak darurat korban?',
          style: TextStyle(
            color: textSecondary,
            height: 1.4,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              'Batal',
              style: TextStyle(
                color: isHighContrast
                    ? const Color(0xFF9CA3AF)
                    : Colors.grey.shade600,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text('Hubungi'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const Center(child: CupertinoActivityIndicator(radius: 16)),
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
        const SnackBar(content: Text('Gagal menghubungi kontak darurat')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: AccessibilityService.instance,
      builder: (context, _) {
        final isHighContrast =
            AccessibilityService.instance.isHighContrastEnabled ||
            Theme.of(context).brightness == Brightness.dark ||
            MediaQuery.of(context).highContrast;
        final currentBg =
            isHighContrast ? Colors.black : const Color(0xFFF5F6F8);
        final tealColor =
            isHighContrast ? const Color(0xFF80CBC4) : primaryTeal;
        final cardBg = isHighContrast ? const Color(0xFF121212) : null;
        final cardBorder = isHighContrast
            ? Border.all(color: const Color(0xFF4B5563), width: 1.5)
            : null;

        if (_isLoading) {
          return Scaffold(
            extendBodyBehindAppBar: true,
            appBar: AppBar(
              backgroundColor: Colors.transparent,
              elevation: 0,
              leading: BackButton(color: tealColor),
            ),
            body: Stack(
              children: [
                Positioned.fill(
                  child: Container(
                    color: currentBg,
                  ),
                ),
                Center(
                  child: CupertinoActivityIndicator(
                    radius: 16,
                    color: tealColor,
                  ),
                ),
              ],
            ),
          );
        }

        if (_activeTask == null) {
          return Scaffold(
            extendBodyBehindAppBar: true,
            appBar: AppBar(
              backgroundColor: Colors.transparent,
              elevation: 0,
              leading: BackButton(color: tealColor),
            ),
            body: Stack(
              children: [
                Positioned.fill(
                  child: Container(
                    color: currentBg,
                  ),
                ),
                Center(
                  child: GlassContainer(
                    padding: const EdgeInsets.all(32),
                    color: cardBg,
                    border: cardBorder,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          CupertinoIcons.doc_text_search,
                          size: 64,
                          color: tealColor.withValues(alpha: 0.5),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Tidak ada tugas aktif.',
                          style: TextStyle(
                            color: isHighContrast
                                ? Colors.white
                                : Colors.black87,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Belum ada tugas darurat yang sedang Anda tangani saat ini.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: isHighContrast
                                ? const Color(0xFFD1D5DB)
                                : Colors.black54,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 20),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            OutlinedButton.icon(
                              onPressed: () => Navigator.pop(context),
                              icon: const Icon(CupertinoIcons.arrow_left,
                                  size: 16),
                              label: const Text('Kembali'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: tealColor,
                                side: BorderSide(
                                  color: isHighContrast
                                      ? const Color(0xFF4B5563)
                                      : primaryTeal,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            ElevatedButton.icon(
                              onPressed: _fetchTask,
                              icon: const Icon(CupertinoIcons.refresh, size: 16),
                              label: const Text('Muat Ulang'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: isHighContrast
                                    ? const Color(0xFF00897B)
                                    : primaryTeal,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),
                          ],
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
        final idKasus = _activeTask!['id_kasus'] ??
            _activeTask!['nomor_kasus'] ??
            'SOS-$idSos';
        final pengguna = _activeTask!['pengguna'] ?? {};
        final nama = pengguna['name'] ?? 'Korban';
        final lokasi = _activeTask!['lokasi_user'] ??
            _activeTask!['lokasi_laporan'] ??
            'Lokasi tidak diketahui';

        final kategoriUser = pengguna['kategori_user'] ?? 'Umum';
        final catatanMedis = (pengguna['catatan_medis'] != null &&
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
        const int currentStep = 2; // 1 = Diterima, 2 = Sedang ditangani, 3 = Selesai
        const int totalSteps = 3;

        return Scaffold(
          backgroundColor: Colors.transparent,
          extendBodyBehindAppBar: true,
          appBar: AppBar(
            backgroundColor: isHighContrast
                ? Colors.black.withValues(alpha: 0.75)
                : Colors.white.withValues(alpha: 0.15),
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
                Text(
                  'Sahabat SOS',
                  style: TextStyle(
                    color: tealColor,
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
                  color: isHighContrast
                      ? const Color(0xFF1E2430)
                      : Colors.white.withValues(alpha: 0.3),
                  shape: BoxShape.circle,
                  border: isHighContrast
                      ? Border.all(color: const Color(0xFF4B5563), width: 1.5)
                      : null,
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
                  color: currentBg,
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
                        color: isHighContrast
                            ? const Color(0xFF7F1D1D)
                            : sosRed.withValues(alpha: 0.75),
                        border: Border.all(
                          color: isHighContrast
                              ? const Color(0xFFEF4444)
                              : Colors.white.withValues(alpha: 0.4),
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
                              'ID: $idKasus',
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
                    color: cardBg,
                    border: cardBorder,
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'TAHAPAN PENANGANAN',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: isHighContrast
                                    ? const Color(0xFFD1D5DB)
                                    : Colors.black54,
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: isHighContrast
                                    ? const Color(0xFF1E3A34)
                                    : primaryTeal.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(12),
                                border: isHighContrast
                                    ? Border.all(color: const Color(0xFF00897B))
                                    : null,
                              ),
                              child: Text(
                                'Langkah $currentStep dari $totalSteps',
                                style: TextStyle(
                                  color: tealColor,
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
                                isHighContrast: isHighContrast,
                                isFirst: true,
                              ),
                            ),
                            _buildLine(1, currentStep,
                                isHighContrast: isHighContrast),
                            Expanded(
                              child: _buildStep(
                                2,
                                'Ditangani',
                                currentStep,
                                isHighContrast: isHighContrast,
                              ),
                            ),
                            _buildLine(2, currentStep,
                                isHighContrast: isHighContrast),
                            Expanded(
                              child: _buildStep(
                                3,
                                'Selesai',
                                currentStep,
                                isHighContrast: isHighContrast,
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
                    color: cardBg,
                    border: cardBorder,
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
                                  color: tealColor,
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Rute Tercepat ke\nKorban',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                    color: isHighContrast
                                        ? Colors.white
                                        : Colors.black87,
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
                                color: isHighContrast
                                    ? const Color(0xFF1E3A34)
                                    : Colors.green.shade50.withValues(
                                        alpha: 0.5,
                                      ),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: isHighContrast
                                      ? const Color(0xFF00897B)
                                      : Colors.green.shade200,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    CupertinoIcons.time,
                                    color: tealColor,
                                    size: 14,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    _etaText,
                                    style: TextStyle(
                                      color: tealColor,
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
                          height: 180,
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: isHighContrast
                                ? const Color(0xFF1E2430)
                                : Colors.grey[200],
                            borderRadius: BorderRadius.circular(16),
                            border: isHighContrast
                                ? Border.all(color: const Color(0xFF4B5563))
                                : null,
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
                                    maxZoom: 18.0,
                                    minZoom: 4.0,
                                    interactionOptions:
                                        const InteractionOptions(
                                          flags: InteractiveFlag.all,
                                        ),
                                  ),
                                  children: [
                                    TileLayer(
                                      urlTemplate:
                                          'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                                      userAgentPackageName:
                                          'com.sahabat_sos_mobile.app',
                                      maxZoom: 18,
                                      tileBuilder: isHighContrast
                                          ? (context, tileWidget, tile) {
                                              return ColorFiltered(
                                                colorFilter: const ColorFilter
                                                    .matrix(<double>[
                                                  -1.0, 0.0, 0.0, 0.0, 255.0,
                                                  0.0, -1.0, 0.0, 0.0, 255.0,
                                                  0.0, 0.0, -1.0, 0.0, 255.0,
                                                  0.0, 0.0, 0.0, 1.0, 0.0,
                                                ]),
                                                child: tileWidget,
                                              );
                                            }
                                          : null,
                                    ),
                                    if (_routePoints.isNotEmpty)
                                      PolylineLayer(
                                        polylines: [
                                          Polyline(
                                            points: _routePoints,
                                            color: tealColor,
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
                                  child: CupertinoActivityIndicator(radius: 16),
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
                            icon: Icon(
                              CupertinoIcons.arrow_up_right_square,
                              size: 16,
                              color: tealColor,
                            ),
                            label: Text(
                              'Buka Google Maps',
                              style: TextStyle(
                                color: tealColor,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: isHighContrast
                                  ? const Color(0xFF1E2430)
                                  : Colors.white.withValues(
                                      alpha: 0.5,
                                    ),
                              elevation: 0,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                                side: BorderSide(
                                  color: isHighContrast
                                      ? const Color(0xFF4B5563)
                                      : Colors.white.withValues(alpha: 0.8),
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
                    color: cardBg,
                    border: cardBorder,
                    child: Column(
                      children: [
                        Row(
                          children: [
                            CircleAvatar(
                              backgroundColor: isHighContrast
                                  ? const Color(0xFF1E2430)
                                  : Colors.white.withValues(
                                      alpha: 0.5,
                                    ),
                              radius: 24,
                              child: Icon(
                                CupertinoIcons.person,
                                color: tealColor,
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
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                          color: isHighContrast
                                              ? Colors.white
                                              : Colors.black87,
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
                                            color: isHighContrast
                                                ? const Color(0xFF1E3A5F)
                                                : Colors.blue.shade50
                                                    .withValues(alpha: 0.8),
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
                                            border: isHighContrast
                                                ? Border.all(
                                                    color:
                                                        const Color(0xFF3B82F6))
                                                : null,
                                          ),
                                          child: Row(
                                            children: [
                                              Icon(
                                                CupertinoIcons.eye_slash_fill,
                                                color: isHighContrast
                                                    ? const Color(0xFF93C5FD)
                                                    : Colors.blue.shade700,
                                                size: 10,
                                              ),
                                              const SizedBox(width: 4),
                                              Text(
                                                kategoriUser,
                                                style: TextStyle(
                                                  color: isHighContrast
                                                      ? const Color(0xFF93C5FD)
                                                      : Colors.blue.shade700,
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
                                    style: TextStyle(
                                      color: isHighContrast
                                          ? const Color(0xFFD1D5DB)
                                          : Colors.black87,
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
                            color: isHighContrast
                                ? const Color(0xFF3B2904)
                                : Colors.amber.shade50.withValues(alpha: 0.6),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isHighContrast
                                  ? const Color(0xFFD97706)
                                  : Colors.amber.shade200.withValues(
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
                                    color: isHighContrast
                                        ? const Color(0xFFFDE68A)
                                        : Colors.amber.shade800,
                                    size: 16,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    'Protokol Interaksi:',
                                    style: TextStyle(
                                      color: isHighContrast
                                          ? const Color(0xFFFDE68A)
                                          : Colors.amber.shade900,
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
                                  color: isHighContrast
                                      ? const Color(0xFFFDE68A)
                                      : Colors.amber.shade900,
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
                                icon: Icon(
                                  CupertinoIcons.phone,
                                  size: 16,
                                  color: tealColor,
                                ),
                                label: Text(
                                  'Panggil',
                                  style: TextStyle(color: tealColor),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: isHighContrast
                                      ? const Color(0xFF1E2430)
                                      : Colors.white.withValues(
                                          alpha: 0.5,
                                        ),
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    side: BorderSide(
                                      color: isHighContrast
                                          ? const Color(0xFF4B5563)
                                          : Colors.white,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: () {},
                                icon: Icon(
                                  CupertinoIcons.chat_bubble,
                                  size: 16,
                                  color: tealColor,
                                ),
                                label: Text(
                                  'Chat',
                                  style: TextStyle(color: tealColor),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: isHighContrast
                                      ? const Color(0xFF1E2430)
                                      : Colors.white.withValues(
                                          alpha: 0.5,
                                        ),
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    side: BorderSide(
                                      color: isHighContrast
                                          ? const Color(0xFF4B5563)
                                          : Colors.white,
                                    ),
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
                              style: TextStyle(
                                  color: sosRed, fontWeight: FontWeight.bold),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: isHighContrast
                                  ? const Color(0xFF450A0A)
                                  : Colors.red.shade50.withValues(
                                      alpha: 0.8,
                                    ),
                              elevation: 0,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                                side: BorderSide(
                                    color: isHighContrast
                                        ? const Color(0xFFEF4444)
                                        : sosRed.withValues(alpha: 0.3)),
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
                        final navigator = Navigator.of(context);
                        final messenger = ScaffoldMessenger.of(context);
                        try {
                          _isCompleting = true;
                          final isLaporan = _activeTask?['tipe'] == 'laporan' ||
                              (_activeTask?['tipe'] != 'sos' &&
                                  _activeTask?['kategori_laporan'] != 'SOS' &&
                                  _activeTask?['kategori_laporan'] != null);
                          if (isLaporan) {
                            final dio = sl<Dio>();
                            final prefs = sl<SharedPreferences>();
                            final token = prefs.getString('auth_token');
                            await dio.put(
                              ApiConstants.laporanStatus(idSos),
                              data: {'status': 'selesai'},
                              options: Options(headers: {
                                if (token != null) 'Authorization': 'Bearer $token',
                                'Accept': 'application/json',
                              }),
                            );
                          } else {
                            await _dataSource.updateSosStatus(
                              int.parse(idSos.toString()),
                              'selesai',
                            );
                          }
                          // Otomatis arahkan ke tab Tugas Relawan (index 1)
                          import_event_bus.GlobalEventBus.changeVolunteerTab
                              .value = 1;
                          import_event_bus.GlobalEventBus.refreshMap.value =
                              !import_event_bus.GlobalEventBus.refreshMap.value;
                          if (!mounted) return;
                          messenger.showSnackBar(
                            const SnackBar(
                              content: Text('Tugas telah diselesaikan.'),
                            ),
                          );
                          navigator.popUntil((route) => route.isFirst);
                        } catch (e) {
                          _isCompleting = false;
                          if (!mounted) return;
                          messenger.showSnackBar(
                            SnackBar(
                              content: Text(
                                'Gagal menyelesaikan: $e',
                              ),
                            ),
                          );
                        }
                      },
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
      },
    );
  }

  Widget _buildStep(
    int stepNum,
    String label,
    int currentStep, {
    bool isHighContrast = false,
    bool isFirst = false,
    bool isLast = false,
  }) {
    final bool isCompleted = stepNum < currentStep;
    final bool isActive = stepNum == currentStep;
    final tealColor = isHighContrast ? const Color(0xFF80CBC4) : primaryTeal;
    final activeBg = isHighContrast ? const Color(0xFF00897B) : primaryTeal;

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
                ? activeBg
                : (isHighContrast
                    ? const Color(0xFF1E2430)
                    : Colors.white.withValues(alpha: 0.5)),
            shape: BoxShape.circle,
            border: Border.all(
              color: isCompleted || isActive
                  ? Colors.transparent
                  : (isHighContrast
                      ? const Color(0xFF4B5563)
                      : Colors.white),
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
                          : (isHighContrast
                              ? const Color(0xFF9CA3AF)
                              : Colors.grey[500]),
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
                ? tealColor
                : (isCompleted
                    ? (isHighContrast ? Colors.white : Colors.black87)
                    : (isHighContrast
                        ? const Color(0xFF9CA3AF)
                        : Colors.grey)),
            fontWeight: isActive || isCompleted
                ? FontWeight.bold
                : FontWeight.normal,
          ),
        ),
      ],
    );
  }

  Widget _buildLine(int stepNum, int currentStep,
      {bool isHighContrast = false}) {
    final bool isCompleted = stepNum < currentStep;
    return Expanded(
      child: Container(
        height: 2,
        margin: const EdgeInsets.only(bottom: 14), // align with circle center
        color: isCompleted
            ? (isHighContrast ? const Color(0xFF00897B) : primaryTeal)
            : (isHighContrast ? const Color(0xFF4B5563) : Colors.grey[300]),
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
    final isHighContrast =
        AccessibilityService.instance.isHighContrastEnabled ||
        Theme.of(context).brightness == Brightness.dark ||
        MediaQuery.of(context).highContrast;
    final trackBg =
        isHighContrast ? const Color(0xFF1E2430) : const Color(0xFFE2EBEB);
    final trackBorder = isHighContrast
        ? Border.all(color: const Color(0xFF4B5563), width: 1.5)
        : Border.all(color: const Color(0xFFB0C4C4));
    final labelColor =
        isHighContrast ? const Color(0xFF80CBC4) : const Color(0xFF006D77);
    final thumbColor =
        isHighContrast ? const Color(0xFF00897B) : const Color(0xFF006D77);

    return LayoutBuilder(
      builder: (context, constraints) {
        final maxWidth = constraints.maxWidth;
        final maxDrag = maxWidth - _thumbSize;

        return Container(
          width: maxWidth,
          height: _thumbSize,
          decoration: BoxDecoration(
            color: trackBg,
            borderRadius: BorderRadius.circular(_thumbSize / 2),
            border: trackBorder,
          ),
          child: Stack(
            children: [
              // 1. Base Text
              Center(
                child: Text(
                  _isCompleted ? "Memproses..." : widget.label,
                  style: TextStyle(
                    color: labelColor,
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
                  color: thumbColor,
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
                      color: thumbColor,
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
                      CupertinoIcons.chevron_right_2,
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
