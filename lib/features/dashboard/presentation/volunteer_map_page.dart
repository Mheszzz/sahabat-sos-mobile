import 'package:sahabat_sos_mobile/core/utils/global_event_bus.dart'
    as import_event_bus;
import 'dart:async';
import 'dart:convert';
import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:sahabat_sos_mobile/core/di/injection.dart';
import 'package:sahabat_sos_mobile/core/services/location_service.dart';
import 'package:sahabat_sos_mobile/core/services/websocket_service.dart';
import 'package:sahabat_sos_mobile/core/constants/api_constants.dart';
import 'package:sahabat_sos_mobile/features/volunteer_task/data/datasources/volunteer_remote_data_source.dart'
    as import_volunteer;

class VolunteerMapPage extends StatefulWidget {
  const VolunteerMapPage({super.key});

  @override
  State<VolunteerMapPage> createState() => VolunteerMapPageState();
}

class VolunteerMapPageState extends State<VolunteerMapPage>
    with SingleTickerProviderStateMixin {
  static const Color sosRed = Color(0xFFE50000);

  final LocationService _locationService = sl<LocationService>();
  final MapController _mapController = MapController();

  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  List<Map<String, dynamic>> _activeSosList = [];
  final Set<int> _listeningIds = {};
  Timer? _pollingTimer;
  StreamSubscription<ServiceStatus>? _serviceStatusStream;
  bool _isFirstFix = true;
  bool _isLoading = true;

  List<LatLng> _routePoints = [];
  bool _isFetchingRoute = false;
  Map<String, dynamic>? _acceptedSos;

  /// Dipanggil dari MainVolunteerScreen saat relawan menerima tugas baru.
  /// Langsung set SOS yang diterima dan fetch rute menuju lokasi korban.
  void acceptSosAndRoute(Map<String, dynamic> sosData) {
    final pos = _locationService.currentPosition.value;
    final lat = double.tryParse(sosData['latitude']?.toString() ?? '');
    final lng = double.tryParse(sosData['longitude']?.toString() ?? '');

    if (!mounted) return;
    setState(() {
      _acceptedSos = sosData;
      // Tandai sebagai assigned agar marker berubah warna
      final idx = _activeSosList.indexWhere((e) => e['id'] == sosData['id']);
      if (idx != -1) {
        _activeSosList[idx]['is_assigned'] = true;
      }
    });

    if (lat != null && lng != null && pos != null) {
      _fetchRoute(LatLng(pos.latitude, pos.longitude), LatLng(lat, lng));
    }
  }

  Future<void> _fetchRoute(LatLng start, LatLng end) async {
    setState(() {
      _isFetchingRoute = true;
    });
    try {
      final dio = Dio();
      final url =
          'https://router.project-osrm.org/route/v1/driving/${start.longitude},${start.latitude};${end.longitude},${end.latitude}?geometries=geojson';
      final response = await dio.get(url);

      if (response.statusCode == 200) {
        final routes = response.data['routes'] as List;
        if (routes.isNotEmpty) {
          final geometry = routes[0]['geometry'];
          final coords = geometry['coordinates'] as List;

          setState(() {
            _routePoints = coords.map((coord) {
              return LatLng(coord[1] as double, coord[0] as double);
            }).toList();
          });

          // Fit bounds to show the route
          if (_routePoints.length > 1) {
            final bounds = LatLngBounds.fromPoints(_routePoints);
            _mapController.fitCamera(
              CameraFit.bounds(
                bounds: bounds,
                padding: const EdgeInsets.all(80.0),
              ),
            );
          }
        }
      }
    } catch (e) {
      debugPrint('Error fetching route: $e');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Gagal membuat rute: $e')));
      }
    } finally {
      if (mounted) {
        setState(() {
          _isFetchingRoute = false;
        });
      }
    }
  }

  @override
  void initState() {
    super.initState();
    import_event_bus.GlobalEventBus.refreshMap.addListener(_fetchActiveSos);

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.4, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _locationService.currentPosition.addListener(_onPositionUpdate);
    _initMap();
  }

  void _onPositionUpdate() {
    final pos = _locationService.currentPosition.value;
    if (pos != null && _isFirstFix) {
      try {
        _mapController.move(LatLng(pos.latitude, pos.longitude), 15.0);
        _isFirstFix = false;
      } catch (e) {
        debugPrint('MapController belum siap: $e');
      }
    }
  }

  Future<void> _initMap() async {
    final hasPermission = await _locationService.requestPermission();
    if (hasPermission) {
      _locationService.startTracking();
      _listenToLocationServiceChanges();
      await _fetchActiveSos();
      _initWebSocket();
      _startPolling();
    } else {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _listenToLocationServiceChanges() {
    _serviceStatusStream = Geolocator.getServiceStatusStream().listen((status) {
      if (status == ServiceStatus.enabled) {
        _locationService.startTracking();
      } else {
        _locationService.stopTracking();
      }
    });
  }

  Future<void> _initWebSocket() async {
    try {
      final prefs = sl<SharedPreferences>();
      final token = prefs.getString('auth_token');
      if (token != null) {
        await WebsocketService.init(token);
        _subscribeToActiveSos();
      }
    } catch (e) {
      debugPrint('WebSocket init error: $e');
    }
  }

  void _subscribeToActiveSos() {
    for (final sos in _activeSosList) {
      final id = sos['id'] as int;
      if (!_listeningIds.contains(id)) {
        _listeningIds.add(id);
        WebsocketService.listenToEmergencyLocation(id, (data) {
          _updateSosLocation(id, data);
        });
      }
    }
  }

  void _unsubscribeRemovedSos(List<int> newIds) {
    final removed = _listeningIds.difference(newIds.toSet());
    for (final id in removed) {
      WebsocketService.stopListeningEmergencyLocation(id);
      _listeningIds.remove(id);
    }
  }

  void _startPolling() {
    _pollingTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      _fetchActiveSos();
    });
  }

  Map<String, dynamic> _getHeaders() {
    final prefs = sl<SharedPreferences>();
    final token = prefs.getString('auth_token');
    return {'Authorization': 'Bearer $token', 'Accept': 'application/json'};
  }

  Future<void> _fetchActiveSos() async {
    try {
      final dio = sl<Dio>();
      final options = Options(headers: _getHeaders());

      // 1. Fetch SOS yang belum diambil
      final responseUnassigned = await dio.get(
        ApiConstants.sosActiveRelawan,
        options: options,
      );

      // 2. Fetch SOS yang SEDANG diproses oleh relawan ini
      final responseAssigned = await dio.get(
        ApiConstants.sosRelawanTasks,
        options: options,
      );

      if (mounted) {
        List<Map<String, dynamic>> combinedList = [];

        // Parse Unassigned
        if (responseUnassigned.statusCode == 200) {
          final dynamic rawData = responseUnassigned.data['data'];
          if (rawData != null && rawData is Map<String, dynamic>) {
            combinedList.add(Map<String, dynamic>.from(rawData));
          } else if (rawData is List) {
            combinedList.addAll(
              rawData.map((e) => Map<String, dynamic>.from(e as Map)).toList(),
            );
          }
        }

        bool hasAssigned = false;

        // Parse Assigned (yang sudah diterima/diproses relawan ini)
        if (responseAssigned.statusCode == 200) {
          final dynamic rawData = responseAssigned.data['data'];
          if (rawData != null && rawData is Map<String, dynamic>) {
            final dataMap = Map<String, dynamic>.from(rawData);
            dataMap['is_assigned'] = true;
            combinedList.add(dataMap);
            hasAssigned = true;
          } else if (rawData is List) {
            final assignedList = rawData.map((e) {
              final map = Map<String, dynamic>.from(e as Map);
              map['is_assigned'] = true;
              return map;
            }).toList();
            if (assignedList.isNotEmpty) {
              hasAssigned = true;
            }
            combinedList.addAll(assignedList);
          }
        }

        // Filter duplicates just in case
        final uniqueMap = <int, Map<String, dynamic>>{};
        for (var item in combinedList) {
          final id = item['id'] as int;
          uniqueMap[id] = item;
        }
        final finalUniqueList = uniqueMap.values.toList();

        final newIds = finalUniqueList.map((e) => e['id'] as int).toList();
        _unsubscribeRemovedSos(newIds);

        setState(() {
          _activeSosList = finalUniqueList;
          _isLoading = false;
          if (!hasAssigned) {
            _acceptedSos = null;
            _routePoints.clear();
          }
        });

        _subscribeToActiveSos();
      }
    } catch (e) {
      debugPrint('Gagal fetch SOS aktif: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _updateSosLocation(int sosId, dynamic data) {
    if (!mounted) return;
    try {
      Map<String, dynamic> loc;
      if (data is String) {
        loc = jsonDecode(data);
      } else {
        loc = data as Map<String, dynamic>;
      }

      setState(() {
        final idx = _activeSosList.indexWhere((e) => e['id'] == sosId);
        if (idx != -1) {
          _activeSosList[idx]['latitude'] =
              double.tryParse(loc['latitude']?.toString() ?? '') ??
              _activeSosList[idx]['latitude'];
          _activeSosList[idx]['longitude'] =
              double.tryParse(loc['longitude']?.toString() ?? '') ??
              _activeSosList[idx]['longitude'];
          if (loc['lokasi_user'] != null) {
            _activeSosList[idx]['lokasi_user'] = loc['lokasi_user'];
          }
        }
      });
    } catch (e) {
      debugPrint('Error update lokasi SOS: $e');
    }
  }

  @override
  void dispose() {
    import_event_bus.GlobalEventBus.refreshMap.removeListener(_fetchActiveSos);
    _locationService.currentPosition.removeListener(_onPositionUpdate);
    _pulseController.dispose();
    _pollingTimer?.cancel();
    _serviceStatusStream?.cancel();
    _locationService.stopTracking();
    for (final id in _listeningIds) {
      WebsocketService.stopListeningEmergencyLocation(id);
    }
    _mapController.dispose();
    super.dispose();
  }

  void _recenterMap() {
    final pos = _locationService.currentPosition.value;
    if (pos != null) {
      _mapController.move(LatLng(pos.latitude, pos.longitude), 16.0);
    }
  }

  double _calculateDistanceKm(LatLng a, LatLng b) {
    return const Distance().as(LengthUnit.Kilometer, a, b);
  }

  // ──────────────────────────── UI ────────────────────────────

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primaryColor = theme.colorScheme.primary;
    final isDarkMode = theme.brightness == Brightness.dark;

    return Scaffold(
      extendBodyBehindAppBar: true,
      body: ValueListenableBuilder<Position?>(
        valueListenable: _locationService.currentPosition,
        builder: (context, position, _) {
          if (_isLoading || position == null) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: primaryColor),
                  const SizedBox(height: 16),
                  Text(
                    'Menunggu Sinyal GPS...',
                    style: TextStyle(
                      color: primaryColor,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            );
          }

          final myLatLng = LatLng(position.latitude, position.longitude);

          return Stack(
            children: [
              // ── Map ──
              FlutterMap(
                mapController: _mapController,
                options: MapOptions(initialCenter: myLatLng, initialZoom: 15.0),
                children: [
                  ColorFiltered(
                    colorFilter: isDarkMode
                        ? const ColorFilter.matrix([
                            -1,
                            0,
                            0,
                            0,
                            255,
                            0,
                            -1,
                            0,
                            0,
                            255,
                            0,
                            0,
                            -1,
                            0,
                            255,
                            0,
                            0,
                            0,
                            1,
                            0,
                          ])
                        : const ColorFilter.mode(
                            Colors.transparent,
                            BlendMode.multiply,
                          ),
                    child: TileLayer(
                      urlTemplate:
                          'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.sahabat_sos_mobile.app',
                    ),
                  ),
                  if (_routePoints.isNotEmpty)
                    PolylineLayer(
                      polylines: [
                        Polyline(
                          points: _routePoints,
                          color: Colors.blueAccent,
                          strokeWidth: 5.0,
                        ),
                      ],
                    ),
                  MarkerLayer(
                    markers: [
                      // ── Volunteer Marker (Pulsing Blue Dot) ──
                      Marker(
                        point: myLatLng,
                        width: 70,
                        height: 70,
                        child: AnimatedBuilder(
                          animation: _pulseAnimation,
                          builder: (context, child) {
                            return Stack(
                              alignment: Alignment.center,
                              children: [
                                Container(
                                  width: 60 * _pulseAnimation.value,
                                  height: 60 * _pulseAnimation.value,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: Colors.blue.withValues(alpha: 0.25),
                                  ),
                                ),
                                Container(
                                  width: 22,
                                  height: 22,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: Colors.blue,
                                    border: Border.all(
                                      color: Colors.white,
                                      width: 3,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withValues(
                                          alpha: 0.2,
                                        ),
                                        blurRadius: 6,
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                      ),

                      // ── SOS User Markers ──
                      ...(() {
                        final Map<String, int> coordOffsets = {};
                        return _activeSosList.map((sos) {
                          final latRaw =
                              double.tryParse(sos['latitude'].toString()) ??
                              0.0;
                          final lngRaw =
                              double.tryParse(sos['longitude'].toString()) ??
                              0.0;

                          final coordKey = "${latRaw}_${lngRaw}";
                          final offsetIndex = coordOffsets[coordKey] ?? 0;
                          coordOffsets[coordKey] = offsetIndex + 1;

                          // Geser sedikit jika tumpang tindih agar tetap terlihat terpisah
                          final lat = latRaw + (offsetIndex * 0.00025);
                          final lng = lngRaw + (offsetIndex * 0.00025);

                          final name = sos['pengguna']?['name'] ?? 'SOS';
                          String locationDesc =
                              sos['lokasi_user'] ??
                              sos['lokasi_laporan'] ??
                              sos['address'] ??
                              '';
                          if (locationDesc.isEmpty) {
                            locationDesc =
                                "${lat.toStringAsFixed(4)}, ${lng.toStringAsFixed(4)}";
                          }
                          final isAssigned = sos['is_assigned'] == true;

                          return Marker(
                            point: LatLng(lat, lng),
                            width: 140,
                            height: 90,
                            child: GestureDetector(
                              onTap: () => _showSosDetails(sos),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: isAssigned
                                          ? Colors.amber.shade100
                                          : Colors.white,
                                      borderRadius: BorderRadius.circular(8),
                                      border: isAssigned
                                          ? Border.all(
                                              color: Colors.amber.shade800,
                                              width: 1.5,
                                            )
                                          : Border.all(
                                              color: sosRed,
                                              width: 1.5,
                                            ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withValues(
                                            alpha: 0.15,
                                          ),
                                          blurRadius: 4,
                                        ),
                                      ],
                                    ),
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          name,
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                            color: isAssigned
                                                ? Colors.amber.shade900
                                                : sosRed,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        if (locationDesc.isNotEmpty)
                                          Text(
                                            locationDesc,
                                            style: TextStyle(
                                              fontSize: 9,
                                              color: isDarkMode
                                                  ? Colors.black87
                                                  : Colors.grey[800],
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Icon(
                                    isAssigned
                                        ? CupertinoIcons.location_solid
                                        : CupertinoIcons
                                              .exclamationmark_triangle_fill,
                                    color: isAssigned
                                        ? Colors.amber.shade800
                                        : sosRed,
                                    size: 32,
                                  ),
                                ],
                              ),
                            ),
                          );
                        }).toList();
                      })(),
                    ],
                  ),
                ],
              ),

              // ── Top SOS Target Info ──
              if (_acceptedSos != null)
                Positioned(
                  top: MediaQuery.paddingOf(context).top + 16,
                  left: 16,
                  right: 16,
                  child: _buildGlassContainer(
                    context,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          'Menuju Lokasi Darurat',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                            color: sosRed,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _acceptedSos!['lokasi_user'] ??
                              _acceptedSos!['lokasi_laporan'] ??
                              _acceptedSos!['address'] ??
                              "Lat: ${double.tryParse(_acceptedSos!['latitude'].toString())?.toStringAsFixed(4)}, Lng: ${double.tryParse(_acceptedSos!['longitude'].toString())?.toStringAsFixed(4)}",
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: isDarkMode ? Colors.white : Colors.black87,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ),

              // ── SOS Counter Badge (Moved down if accepted SOS is shown) ──
              if (_activeSosList.isNotEmpty && _acceptedSos == null)
                Positioned(
                  top: MediaQuery.paddingOf(context).top + 16,
                  left: 16,
                  child: _buildGlassContainer(
                    context,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 10,
                          height: 10,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: sosRed,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '${_activeSosList.length} SOS Aktif',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            color: sosRed,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

              // ── Bottom Info Card ──
              Positioned(
                bottom: 100, // Diperbesar agar tidak tertimpa navbar
                left: 16,
                right: 16,
                child: SafeArea(
                  child: _buildGlassContainer(
                    context,
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: primaryColor.withValues(alpha: 0.1),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.gps_fixed,
                            color: primaryColor,
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'Lokasi Anda (Relawan)',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                  color: primaryColor,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${position.latitude.toStringAsFixed(5)}, ${position.longitude.toStringAsFixed(5)}  ·  ±${position.accuracy.toStringAsFixed(0)}m',
                                style: TextStyle(
                                  color: isDarkMode
                                      ? Colors.white70
                                      : Colors.grey[600],
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // ── Bottom Right: Recenter Button ──
              Positioned(
                bottom: 180,
                right: 16,
                child: SafeArea(
                  top: false,
                  child: _buildGlassContainer(
                    context,
                    padding: const EdgeInsets.all(4),
                    borderRadius: BorderRadius.circular(20),
                    child: IconButton(
                      icon: const Icon(
                        CupertinoIcons.location,
                        color: Colors.blue,
                      ),
                      onPressed: _recenterMap,
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

  // ──────────────────── Glass Container ────────────────────

  Widget _buildGlassContainer(
    BuildContext context, {
    required Widget child,
    EdgeInsetsGeometry? padding,
    BorderRadius? borderRadius,
  }) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final radius = borderRadius ?? BorderRadius.circular(24);
    return ClipRRect(
      borderRadius: radius,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          padding: padding ?? const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDarkMode
                ? Colors.black.withValues(alpha: 0.4)
                : Colors.white.withValues(alpha: 0.5),
            borderRadius: radius,
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

  // ──────────────────── SOS Detail Sheet ────────────────────

  void _showSosDetails(Map<String, dynamic> sos) {
    final theme = Theme.of(context);
    final primaryColor = theme.colorScheme.primary;
    final isDarkMode = theme.brightness == Brightness.dark;

    final volunteerPos = _locationService.currentPosition.value;
    final sosLat = double.tryParse(sos['latitude'].toString()) ?? 0.0;
    final sosLng = double.tryParse(sos['longitude'].toString()) ?? 0.0;

    double? distanceKm;
    if (volunteerPos != null) {
      distanceKm = _calculateDistanceKm(
        LatLng(volunteerPos.latitude, volunteerPos.longitude),
        LatLng(sosLat, sosLng),
      );
    }

    final pengguna = sos['pengguna'] as Map<String, dynamic>? ?? {};
    final nama = pengguna['name'] ?? sos['user']?['nama'] ?? 'User';
    final noTelp =
        pengguna['phone'] ??
        pengguna['no_telp'] ??
        sos['user']?['no_telp'] ??
        '-';

    String alamat =
        sos['lokasi_user'] ?? sos['lokasi_laporan'] ?? sos['address'] ?? '';
    if (alamat.isEmpty) {
      alamat =
          "Lat: ${sosLat.toStringAsFixed(4)}, Lng: ${sosLng.toStringAsFixed(4)}";
    }

    final status = sos['status_sos'] ?? 'aktif';

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          bottom:
              MediaQuery.viewInsetsOf(ctx).bottom +
              MediaQuery.paddingOf(ctx).bottom,
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
                // Handle bar
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: isDarkMode
                          ? Colors.white24
                          : Colors.grey.withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),

                // Header: Name + Status
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: sosRed.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        CupertinoIcons.exclamationmark_triangle_fill,
                        color: sosRed,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        nama,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                          color: isDarkMode ? Colors.white : Colors.black87,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: sosRed.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        status.toString().toUpperCase(),
                        style: const TextStyle(
                          color: sosRed,
                          fontWeight: FontWeight.bold,
                          fontSize: 11,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Details
                _buildDetailRow(
                  context,
                  CupertinoIcons.phone_fill,
                  'Telepon',
                  noTelp,
                ),
                const SizedBox(height: 10),
                _buildDetailRow(
                  context,
                  CupertinoIcons.location_solid,
                  'Lokasi',
                  alamat,
                ),
                if (distanceKm != null) ...[
                  const SizedBox(height: 10),
                  _buildDetailRow(
                    context,
                    CupertinoIcons.arrow_right_arrow_left,
                    'Jarak',
                    '${distanceKm.toStringAsFixed(1)} km dari Anda',
                  ),
                ],
                const SizedBox(height: 20),

                // Actions
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    icon: Icon(
                      (sos['is_assigned'] == true)
                          ? CupertinoIcons.check_mark_circled_solid
                          : CupertinoIcons.checkmark_circle,
                      size: 20,
                    ),
                    label: Text(
                      (sos['is_assigned'] == true)
                          ? 'Selesaikan Tugas'
                          : 'Terima Tugas',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    onPressed: _isFetchingRoute
                        ? null
                        : () async {
                            Navigator.pop(ctx);

                            try {
                              final dataSource =
                                  sl<
                                    import_volunteer.VolunteerRemoteDataSource
                                  >();
                              final sosId = sos['id'] as int;

                              if (sos['is_assigned'] == true) {
                                // Selesaikan Tugas
                                await dataSource.updateSosStatus(
                                  sosId,
                                  'selesai',
                                );
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        'Tugas telah diselesaikan.',
                                      ),
                                    ),
                                  );
                                }
                                setState(() {
                                  _acceptedSos = null;
                                  _routePoints.clear();
                                });
                              } else {
                                // Terima Tugas
                                await dataSource.updateSosStatus(
                                  sosId,
                                  'proses',
                                );
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        'Tugas diterima! Sedang membuat rute...',
                                      ),
                                    ),
                                  );
                                }
                                setState(() {
                                  _acceptedSos = sos;
                                });
                                if (volunteerPos != null) {
                                  _fetchRoute(
                                    LatLng(
                                      volunteerPos.latitude,
                                      volunteerPos.longitude,
                                    ),
                                    LatLng(sosLat, sosLng),
                                  );
                                }
                              }

                              // Refresh map data
                              import_event_bus.GlobalEventBus.refreshMap.value =
                                  !import_event_bus
                                      .GlobalEventBus
                                      .refreshMap
                                      .value;
                            } catch (e) {
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Terjadi kesalahan: $e'),
                                  ),
                                );
                              }
                            }
                          },
                  ),
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(
    BuildContext context,
    IconData icon,
    String label,
    String value,
  ) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          icon,
          size: 18,
          color: isDarkMode ? Colors.white54 : Colors.black54,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  color: isDarkMode ? Colors.white54 : Colors.black45,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: TextStyle(
                  fontSize: 14,
                  color: isDarkMode ? Colors.white : Colors.black87,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
