import 'dart:async';
import 'dart:convert';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:sahabat_sos_mobile/core/di/injection.dart';
import 'package:sahabat_sos_mobile/core/constants/api_constants.dart';
import 'package:sahabat_sos_mobile/core/services/location_service.dart';
import 'package:sahabat_sos_mobile/core/services/websocket_service.dart';
import 'package:sahabat_sos_mobile/core/services/accessibility_service.dart';
import 'package:sahabat_sos_mobile/core/theme/accessible_colors.dart';
import 'package:sahabat_sos_mobile/core/utils/global_event_bus.dart' as event_bus;
import 'package:sahabat_sos_mobile/features/volunteer_task/data/datasources/volunteer_remote_data_source.dart';
import 'package:sahabat_sos_mobile/features/volunteer_task/presentation/volunteer_active_task_page.dart';
import 'package:sahabat_sos_mobile/features/dashboard/presentation/widgets/volunteer_sos_detail_sheet.dart';

enum RadarFilter {
  all,
  inRadius,
  assigned,
}

class VolunteerMapPage extends StatefulWidget {
  const VolunteerMapPage({super.key});

  @override
  State<VolunteerMapPage> createState() => VolunteerMapPageState();
}

class VolunteerMapPageState extends State<VolunteerMapPage>
    with SingleTickerProviderStateMixin {
  static const Color sosRed = Color(0xFFDC2626);
  static const Color sosAmber = Color(0xFFD97706);

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
  final Map<String, String> _addressCache = {};

  double _radarRadiusMeters = double.tryParse(
        const String.fromEnvironment('RADAR_RADIUS_METERS'),
      ) ??
      2000.0;
  RadarFilter _selectedFilter = RadarFilter.all;

  /// Dipanggil dari MainVolunteerScreen saat relawan menerima tugas baru
  void acceptSosAndRoute(Map<String, dynamic> sosData) {
    final pos = _locationService.currentPosition.value;
    final lat = double.tryParse(sosData['latitude']?.toString() ?? '');
    final lng = double.tryParse(sosData['longitude']?.toString() ?? '');

    if (!mounted) return;
    setState(() {
      _acceptedSos = sosData;
      final idx = _activeSosList.indexWhere((e) => e['id'] == sosData['id']);
      if (idx != -1) {
        _activeSosList[idx]['is_assigned'] = true;
      }
    });

    if (lat != null && lng != null && pos != null) {
      unawaited(_fetchRoute(LatLng(pos.latitude, pos.longitude), LatLng(lat, lng)));
    }
  }

  Future<void> _fetchRoute(LatLng start, LatLng end) async {
    setState(() {
      _isFetchingRoute = true;
    });
    try {
      final dio = Dio();
      const osrmBaseUrl = String.fromEnvironment(
        'OSRM_ROUTING_URL',
        defaultValue: 'https://router.project-osrm.org',
      );
      final url =
          '$osrmBaseUrl/route/v1/driving/${start.longitude},${start.latitude};${end.longitude},${end.latitude}?geometries=geojson';
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal membuat rute: $e')),
        );
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
    event_bus.GlobalEventBus.refreshMap.addListener(_fetchActiveSos);

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.35, end: 1.0).animate(
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

  void _fitAllSosMarkers() {
    final points = <LatLng>[];
    final myPos = _locationService.currentPosition.value;
    if (myPos != null) {
      points.add(LatLng(myPos.latitude, myPos.longitude));
    }
    for (final sos in _filteredSosList) {
      final lat = double.tryParse(sos['latitude']?.toString() ?? '');
      final lng = double.tryParse(sos['longitude']?.toString() ?? '');
      if (lat != null && lng != null && lat != 0.0 && lng != 0.0) {
        points.add(LatLng(lat, lng));
      }
    }
    if (points.isNotEmpty) {
      if (points.length == 1) {
        _mapController.move(points.first, 15.0);
      } else {
        final bounds = LatLngBounds.fromPoints(points);
        _mapController.fitCamera(
          CameraFit.bounds(
            bounds: bounds,
            padding: const EdgeInsets.all(70.0),
            maxZoom: 16.0,
          ),
        );
      }
    }
  }

  Future<void> _initMap() async {
    final hasPermission = await _locationService.requestPermission();
    if (hasPermission) {
      _locationService.startTracking();
      _listenToLocationServiceChanges();
      await _fetchActiveSos();
      unawaited(_initWebSocket());
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
    final prefs = sl<SharedPreferences>();
    final cachedStatus = prefs.getString('verification_status');
    final cachedActive = prefs.getBool('user_is_active') ?? true;
    if (cachedStatus != 'terverifikasi' || !cachedActive) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    try {
      final dio = sl<Dio>();
      final options = Options(headers: _getHeaders());

      final responseUnassigned = await dio.get(
        ApiConstants.sosActiveRelawan,
        options: options,
      );

      final responseAssigned = await dio.get(
        ApiConstants.sosRelawanTasks,
        options: options,
      );

      if (mounted) {
        final List<Map<String, dynamic>> combinedList = [];

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

        // Deduplikasi kasus berdasarkan ID unik
        final uniqueMap = <int, Map<String, dynamic>>{};
        for (var item in combinedList) {
          final rawId = item['id'];
          final id = (rawId is int)
              ? rawId
              : int.tryParse(rawId?.toString() ?? '0') ?? 0;
          if (id != 0) {
            uniqueMap[id] = item;
          }
        }
        final finalUniqueList = uniqueMap.values.toList();

        final newIds = finalUniqueList.map((e) {
          final rawId = e['id'];
          return (rawId is int)
              ? rawId
              : int.tryParse(rawId?.toString() ?? '0') ?? 0;
        }).where((id) => id != 0).toList();
        _unsubscribeRemovedSos(newIds);

        setState(() {
          _activeSosList = finalUniqueList;
          _isLoading = false;
          if (!hasAssigned) {
            _acceptedSos = null;
            _routePoints.clear();
          } else if (_acceptedSos == null) {
            try {
              final assignedSos = finalUniqueList.firstWhere(
                (e) => e['is_assigned'] == true,
              );
              _acceptedSos = assignedSos;

              final sosLat = double.tryParse(
                assignedSos['latitude']?.toString() ?? '',
              );
              final sosLng = double.tryParse(
                assignedSos['longitude']?.toString() ?? '',
              );
              final volunteerPos = _locationService.currentPosition.value;

              if (sosLat != null &&
                  sosLng != null &&
                  volunteerPos != null &&
                  _routePoints.isEmpty) {
                _fetchRoute(
                  LatLng(volunteerPos.latitude, volunteerPos.longitude),
                  LatLng(sosLat, sosLng),
                );
              }
            } catch (e) {
              debugPrint('Error finding assigned SOS: $e');
            }
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
    event_bus.GlobalEventBus.refreshMap.removeListener(_fetchActiveSos);
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

  List<Map<String, dynamic>> get _filteredSosList {
    final myPos = _locationService.currentPosition.value;
    if (myPos == null) return _activeSosList;

    final myLatLng = LatLng(myPos.latitude, myPos.longitude);

    switch (_selectedFilter) {
      case RadarFilter.all:
        return _activeSosList;
      case RadarFilter.inRadius:
        return _activeSosList.where((sos) {
          final lat = double.tryParse(sos['latitude']?.toString() ?? '');
          final lng = double.tryParse(sos['longitude']?.toString() ?? '');
          if (lat == null || lng == null || lat == 0.0 || lng == 0.0) return false;
          final distKm = _calculateDistanceKm(myLatLng, LatLng(lat, lng));
          return distKm <= (_radarRadiusMeters / 1000.0);
        }).toList();
      case RadarFilter.assigned:
        return _activeSosList.where((sos) => sos['is_assigned'] == true).toList();
    }
  }

  int get _inRadiusCount {
    final myPos = _locationService.currentPosition.value;
    if (myPos == null) return _activeSosList.length;
    final myLatLng = LatLng(myPos.latitude, myPos.longitude);
    return _activeSosList.where((sos) {
      final lat = double.tryParse(sos['latitude']?.toString() ?? '');
      final lng = double.tryParse(sos['longitude']?.toString() ?? '');
      if (lat == null || lng == null || lat == 0.0 || lng == 0.0) return false;
      return _calculateDistanceKm(myLatLng, LatLng(lat, lng)) <=
          (_radarRadiusMeters / 1000.0);
    }).length;
  }

  int get _assignedCount {
    return _activeSosList.where((sos) => sos['is_assigned'] == true).length;
  }

  void _toggleRadarRadius() {
    setState(() {
      if (_radarRadiusMeters == 2000.0) {
        _radarRadiusMeters = 3000.0;
        AccessibilityService.instance.speak(
          'Radius jangkauan radar diperluas ke 3 kilometer',
        );
      } else {
        _radarRadiusMeters = 2000.0;
        AccessibilityService.instance.speak(
          'Radius jangkauan radar kembali ke 2 kilometer standar',
        );
      }
    });
  }

  Future<String> _getMarkerAddress(
    Map<String, dynamic> sos,
    double lat,
    double lng,
  ) async {
    final id = sos['id']?.toString() ?? '${lat}_$lng';
    if (_addressCache.containsKey(id)) return _addressCache[id]!;
    final address = await _resolveAddress(sos, lat, lng);
    _addressCache[id] = address;
    return address;
  }

  Future<String> _resolveAddress(
    Map<String, dynamic> sos,
    double lat,
    double lng,
  ) async {
    String alamat = sos['pengguna']?['alamat']?.toString() ??
        sos['pengguna']?['lokasi_user']?.toString() ??
        sos['lokasi_user']?.toString() ??
        sos['lokasi_laporan']?.toString() ??
        sos['address']?.toString() ??
        '';
    final alamatMatch = RegExp(r'alamat:\s*([^,}]+)').firstMatch(alamat);
    if (alamatMatch != null) {
      alamat = alamatMatch.group(1)!.trim();
    }

    if (lat != 0.0 && lng != 0.0) {
      try {
        final placemarks = await Geocoding().placemarkFromCoordinates(lat, lng);
        if (placemarks.isNotEmpty) {
          final place = placemarks.first;
          final addressList = [
            place.subLocality,
            place.locality,
            place.subAdministrativeArea,
            place.administrativeArea,
          ].where((e) => e != null && e.isNotEmpty).toList();
          final address = addressList.join(', ');
          if (address.isNotEmpty) return address;
        }
      } catch (_) {}
    }

    if (alamat.isNotEmpty) return alamat;
    return "Lat: ${lat.toStringAsFixed(4)}, Lng: ${lng.toStringAsFixed(4)}";
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: AccessibilityService.instance,
      builder: (context, _) {
        final theme = Theme.of(context);
        final isHighContrast =
            AccessibilityService.instance.isHighContrastEnabled ||
            theme.brightness == Brightness.dark ||
            MediaQuery.of(context).highContrast;
        final isDarkMode =
            isHighContrast || theme.brightness == Brightness.dark;
        final primaryColor = isHighContrast
            ? const Color(0xFF80CBC4)
            : theme.colorScheme.primary;
        final textPrimary = AccessibleColors.textPrimary(isHighContrast);
        final textSecondary = AccessibleColors.textSecondary(isHighContrast);

        return Scaffold(
          extendBodyBehindAppBar: true,
          backgroundColor: isHighContrast ? Colors.black : null,
          body: ValueListenableBuilder<Position?>(
            valueListenable: _locationService.currentPosition,
            builder: (context, position, _) {
              if (_isLoading || position == null) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CupertinoActivityIndicator(
                        radius: 16,
                        color: primaryColor,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Menghubungkan ke Radar GPS...',
                        style: TextStyle(
                          color: primaryColor,
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                        ),
                      ),
                    ],
                  ),
                );
              }

              final myLatLng = LatLng(position.latitude, position.longitude);
              final filteredList = _filteredSosList;

              return Stack(
                children: [
                  FlutterMap(
                    mapController: _mapController,
                    options: MapOptions(
                      initialCenter: myLatLng,
                      initialZoom: 15.0,
                    ),
                    children: [
                      ColorFiltered(
                        colorFilter: isDarkMode
                            ? const ColorFilter.matrix([
                                -1, 0, 0, 0, 255,
                                0, -1, 0, 0, 255,
                                0, 0, -1, 0, 255,
                                0, 0, 0, 1, 0,
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

                      // Lingkaran Jangkauan Radar Relawan
                      CircleLayer(
                        circles: [
                          CircleMarker(
                            point: myLatLng,
                            radius: _radarRadiusMeters,
                            useRadiusInMeter: true,
                            color: primaryColor.withValues(
                              alpha: isDarkMode ? 0.08 : 0.05,
                            ),
                            borderColor: primaryColor.withValues(
                              alpha: isDarkMode ? 0.45 : 0.35,
                            ),
                            borderStrokeWidth: 1.5,
                          ),
                          if (_radarRadiusMeters > 2000.0)
                            CircleMarker(
                              point: myLatLng,
                              radius: 3000.0,
                              useRadiusInMeter: true,
                              color: sosAmber.withValues(alpha: 0.03),
                              borderColor: sosAmber.withValues(alpha: 0.35),
                              borderStrokeWidth: 1.2,
                            ),
                        ],
                      ),

                      if (_routePoints.isNotEmpty)
                        PolylineLayer(
                          polylines: [
                            Polyline(
                              points: _routePoints,
                              color: const Color(0xFF2563EB),
                              strokeWidth: 5.0,
                            ),
                          ],
                        ),

                      MarkerLayer(
                        markers: [
                          // Marker Posisi Relawan dengan Animasi Beacon Radar
                          Marker(
                            point: myLatLng,
                            width: 72,
                            height: 72,
                            child: AnimatedBuilder(
                              animation: _pulseAnimation,
                              builder: (context, child) {
                                return Stack(
                                  alignment: Alignment.center,
                                  children: [
                                    Container(
                                      width: 66 * _pulseAnimation.value,
                                      height: 66 * _pulseAnimation.value,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: primaryColor.withValues(
                                          alpha: (1.0 - _pulseAnimation.value) *
                                              0.45,
                                        ),
                                      ),
                                    ),
                                    Container(
                                      width: 24,
                                      height: 24,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: primaryColor,
                                        border: Border.all(
                                          color: Colors.white,
                                          width: 3,
                                        ),
                                        boxShadow: isHighContrast
                                            ? null
                                            : [
                                                BoxShadow(
                                                  color: Colors.black
                                                      .withValues(alpha: 0.25),
                                                  blurRadius: 6,
                                                ),
                                              ],
                                      ),
                                      child: const Icon(
                                        CupertinoIcons.shield_fill,
                                        color: Colors.white,
                                        size: 11,
                                      ),
                                    ),
                                  ],
                                );
                              },
                            ),
                          ),

                          // Marker Panggilan Kasus Darurat SOS
                          ...(() {
                            final Map<String, int> coordOffsets = {};
                            return filteredList.map((sos) {
                              final latRaw =
                                  double.tryParse(sos['latitude'].toString()) ??
                                  0.0;
                              final lngRaw =
                                  double.tryParse(sos['longitude'].toString()) ??
                                  0.0;

                              final coordKey = "${latRaw}_$lngRaw";
                              final offsetIndex = coordOffsets[coordKey] ?? 0;
                              coordOffsets[coordKey] = offsetIndex + 1;

                              // Menggeser sedikit jika terdapat koordinat identik agar tidak bertumpuk
                              final lat = latRaw + (offsetIndex * 0.00025);
                              final lng = lngRaw + (offsetIndex * 0.00025);

                              final name = sos['pengguna']?['name'] ?? 'SOS';
                              final isAssigned = sos['is_assigned'] == true;
                              final distanceKm = _calculateDistanceKm(
                                myLatLng,
                                LatLng(latRaw, lngRaw),
                              );

                              return Marker(
                                point: LatLng(lat, lng),
                                width: 140,
                                height: 90,
                                child: GestureDetector(
                                  onTap: () => _showSosDetailSheet(sos),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: isHighContrast
                                              ? const Color(0xFF1E2430)
                                              : (isAssigned
                                                  ? Colors.amber.shade50
                                                  : Colors.white),
                                          borderRadius:
                                              BorderRadius.circular(8),
                                          border: Border.all(
                                            color: isAssigned
                                                ? sosAmber
                                                : (isHighContrast
                                                    ? const Color(0xFFEF4444)
                                                    : sosRed),
                                            width: isHighContrast ? 1.5 : 1.2,
                                          ),
                                          boxShadow: isHighContrast
                                              ? null
                                              : [
                                                  BoxShadow(
                                                    color: Colors.black
                                                        .withValues(alpha: 0.12),
                                                    blurRadius: 4,
                                                    offset: const Offset(0, 1),
                                                  ),
                                                ],
                                        ),
                                        child: Column(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Text(
                                              '${distanceKm.toStringAsFixed(1)} km · $name',
                                              style: TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.bold,
                                                color: isAssigned
                                                    ? sosAmber
                                                    : (isHighContrast
                                                        ? Colors.white
                                                        : sosRed),
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            FutureBuilder<String>(
                                              future: _getMarkerAddress(
                                                sos,
                                                latRaw,
                                                lngRaw,
                                              ),
                                              builder: (context, snapshot) {
                                                return Text(
                                                  snapshot.data ?? 'Memuat...',
                                                  style: TextStyle(
                                                    fontSize: 9,
                                                    color: isHighContrast
                                                        ? const Color(0xFFD1D5DB)
                                                        : (isDarkMode
                                                            ? Colors.white70
                                                            : Colors.grey[700]),
                                                  ),
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                );
                                              },
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
                                        color: isAssigned ? sosAmber : sosRed,
                                        size: 30,
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

                  // Area Kontrol Atas: Radar Siaga Status & Filter Situasional
                  Positioned(
                    top: MediaQuery.paddingOf(context).top + 12,
                    left: 16,
                    right: 16,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _buildTopStatusPanel(
                          context,
                          isHighContrast: isHighContrast,
                          primaryColor: primaryColor,
                          textPrimary: textPrimary,
                          textSecondary: textSecondary,
                        ),
                        const SizedBox(height: 8),
                        _buildFilterRow(
                          isHighContrast: isHighContrast,
                          isDarkMode: isDarkMode,
                          primaryColor: primaryColor,
                        ),
                      ],
                    ),
                  ),

                  // Klaster Tombol Aksi Peta (Sebelah Kanan)
                  Positioned(
                    right: 16,
                    bottom: MediaQuery.paddingOf(context).bottom + 158,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildFloatingActionButton(
                          icon: CupertinoIcons.square_stack_3d_up,
                          tooltip: 'Lihat Semua Titik Darurat',
                          onPressed: _fitAllSosMarkers,
                          isHighContrast: isHighContrast,
                          isDarkMode: isDarkMode,
                          primaryColor: primaryColor,
                        ),
                        const SizedBox(height: 10),
                        _buildFloatingActionButton(
                          icon: CupertinoIcons.location_fill,
                          tooltip: 'Pusatkan Posisi Saya',
                          onPressed: _recenterMap,
                          isHighContrast: isHighContrast,
                          isDarkMode: isDarkMode,
                          primaryColor: primaryColor,
                        ),
                        const SizedBox(height: 10),
                        _buildFloatingActionButton(
                          icon: CupertinoIcons.arrow_clockwise,
                          tooltip: 'Perbarui Radar',
                          onPressed: () {
                            _fetchActiveSos();
                            AccessibilityService.instance.speak(
                              'Memperbarui radar kasus...',
                            );
                          },
                          isHighContrast: isHighContrast,
                          isDarkMode: isDarkMode,
                          primaryColor: primaryColor,
                        ),
                      ],
                    ),
                  ),

                  // Informasi Lokasi & Status Siaga Bawah
                  Positioned(
                    bottom: MediaQuery.paddingOf(context).bottom + 98,
                    left: 16,
                    right: 76,
                    child: _buildSolidCard(
                      context,
                      isHighContrast: isHighContrast,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(7),
                            decoration: BoxDecoration(
                              color: primaryColor.withValues(alpha: 0.12),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              CupertinoIcons.compass,
                              color: primaryColor,
                              size: 18,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  'Siaga Lapangan (GPS Aktif)',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                    color: textPrimary,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '${position.latitude.toStringAsFixed(4)}, ${position.longitude.toStringAsFixed(4)} (±${position.accuracy.toStringAsFixed(0)}m)',
                                  style: TextStyle(
                                    color: textSecondary,
                                    fontSize: 11,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildTopStatusPanel(
    BuildContext context, {
    required bool isHighContrast,
    required Color primaryColor,
    required Color textPrimary,
    required Color textSecondary,
  }) {
    if (_acceptedSos != null) {
      return _buildSolidCard(
        context,
        isHighContrast: isHighContrast,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        border: Border.all(
          color: isHighContrast ? const Color(0xFFEF4444) : sosRed,
          width: isHighContrast ? 1.5 : 1.2,
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isHighContrast
                    ? const Color(0xFF450A0A)
                    : sosRed.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                CupertinoIcons.location_north_fill,
                size: 18,
                color: sosRed,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Menuju Lokasi Darurat',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: isHighContrast
                          ? const Color(0xFFFCA5A5)
                          : sosRed,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _acceptedSos?['pengguna']?['name'] ?? 'Kasus Ditangani',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: textPrimary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            ElevatedButton(
              onPressed: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => VolunteerActiveTaskPage(
                      initialTask: _acceptedSos!,
                    ),
                  ),
                );
                if (mounted) {
                  setState(() {
                    _acceptedSos = null;
                    _routePoints.clear();
                  });
                  await _fetchActiveSos();
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: isHighContrast
                    ? const Color(0xFF00897B)
                    : primaryColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 8,
                ),
                minimumSize: const Size(64, 48),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text(
                'Detail',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      );
    }

    return _buildSolidCard(
      context,
      isHighContrast: isHighContrast,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(
        children: [
          AnimatedBuilder(
            animation: _pulseAnimation,
            builder: (context, _) => Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: primaryColor,
                boxShadow: isHighContrast
                    ? null
                    : [
                        BoxShadow(
                          color: primaryColor.withValues(
                            alpha: 0.45 * _pulseAnimation.value,
                          ),
                          blurRadius: 8 * _pulseAnimation.value,
                          spreadRadius: 2 * _pulseAnimation.value,
                        ),
                      ],
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Radar Relawan Siaga',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: textPrimary,
                  ),
                ),
                Text(
                  'Jangkauan ${(_radarRadiusMeters / 1000).toStringAsFixed(1)} Km  ·  ${_activeSosList.length} Panggilan Aktif',
                  style: TextStyle(
                    fontSize: 11,
                    color: textSecondary,
                  ),
                ),
              ],
            ),
          ),
          Semantics(
            button: true,
            label: 'Ubah radius radar',
            child: InkWell(
              onTap: _toggleRadarRadius,
              borderRadius: BorderRadius.circular(8),
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 48, minWidth: 48),
                child: Container(
                  alignment: Alignment.center,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: primaryColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: primaryColor.withValues(alpha: 0.35),
                      width: 1.0,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        CupertinoIcons.radiowaves_right,
                        size: 14,
                        color: primaryColor,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${(_radarRadiusMeters / 1000).toStringAsFixed(0)} Km',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: primaryColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterRow({
    required bool isHighContrast,
    required bool isDarkMode,
    required Color primaryColor,
  }) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _buildFilterChip(
            label: 'Semua (${_activeSosList.length})',
            isSelected: _selectedFilter == RadarFilter.all,
            onTap: () => setState(() => _selectedFilter = RadarFilter.all),
            isHighContrast: isHighContrast,
            isDarkMode: isDarkMode,
            primaryColor: primaryColor,
          ),
          const SizedBox(width: 8),
          _buildFilterChip(
            label: 'Radius ${(_radarRadiusMeters / 1000).toStringAsFixed(0)} Km ($_inRadiusCount)',
            isSelected: _selectedFilter == RadarFilter.inRadius,
            onTap: () => setState(() => _selectedFilter = RadarFilter.inRadius),
            isHighContrast: isHighContrast,
            isDarkMode: isDarkMode,
            primaryColor: primaryColor,
          ),
          if (_assignedCount > 0) ...[
            const SizedBox(width: 8),
            _buildFilterChip(
              label: 'Ditugaskan ($_assignedCount)',
              isSelected: _selectedFilter == RadarFilter.assigned,
              onTap: () =>
                  setState(() => _selectedFilter = RadarFilter.assigned),
              isHighContrast: isHighContrast,
              isDarkMode: isDarkMode,
              primaryColor: primaryColor,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildFilterChip({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
    required bool isHighContrast,
    required bool isDarkMode,
    required Color primaryColor,
  }) {
    final bgColor = isSelected
        ? (isHighContrast ? const Color(0xFF00897B) : primaryColor)
        : (isHighContrast
            ? const Color(0xFF1E2430)
            : (isDarkMode ? const Color(0xFF1E1E1E) : Colors.white));
    final fgColor = isSelected
        ? Colors.white
        : (isHighContrast ? Colors.white : Colors.black87);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 48),
        child: Container(
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isSelected
                  ? (isHighContrast ? const Color(0xFF80CBC4) : primaryColor)
                  : (isHighContrast
                      ? const Color(0xFF4B5563)
                      : (isDarkMode
                          ? const Color(0xFF374151)
                          : const Color(0xFFE5E7EB))),
              width: isHighContrast ? 1.5 : 1.0,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
              color: fgColor,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFloatingActionButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback onPressed,
    required bool isHighContrast,
    required bool isDarkMode,
    required Color primaryColor,
  }) {
    return Semantics(
      button: true,
      label: tooltip,
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: isHighContrast
              ? const Color(0xFF121212)
              : (isDarkMode ? const Color(0xFF1E1E1E) : Colors.white),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isHighContrast
                ? const Color(0xFF4B5563)
                : (isDarkMode
                    ? const Color(0xFF374151)
                    : const Color(0xFFE5E7EB)),
            width: isHighContrast ? 1.5 : 1.0,
          ),
          boxShadow: isHighContrast
              ? null
              : [
                  BoxShadow(
                    color: Colors.black.withValues(
                      alpha: isDarkMode ? 0.25 : 0.08,
                    ),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: onPressed,
            child: Icon(
              icon,
              size: 20,
              color: primaryColor,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSolidCard(
    BuildContext context, {
    required Widget child,
    EdgeInsetsGeometry? padding,
    BorderRadius? borderRadius,
    Border? border,
    bool? isHighContrast,
  }) {
    final contrast = isHighContrast ??
        (AccessibilityService.instance.isHighContrastEnabled ||
            Theme.of(context).brightness == Brightness.dark ||
            MediaQuery.of(context).highContrast);
    final isDarkMode =
        contrast || Theme.of(context).brightness == Brightness.dark;
    final radius = borderRadius ?? BorderRadius.circular(16);

    return Container(
      padding: padding ?? const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: contrast
            ? const Color(0xFF121212)
            : (isDarkMode ? const Color(0xFF1E1E1E) : Colors.white),
        borderRadius: radius,
        border: border ??
            Border.all(
              color: contrast
                  ? const Color(0xFF4B5563)
                  : (isDarkMode
                      ? const Color(0xFF374151)
                      : const Color(0xFFE5E7EB)),
              width: contrast ? 1.5 : 1.0,
            ),
        boxShadow: contrast
            ? null
            : [
                BoxShadow(
                  color: Colors.black.withValues(
                    alpha: isDarkMode ? 0.25 : 0.06,
                  ),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
      ),
      child: child,
    );
  }

  /// Menampilkan bottom sheet detail rincian korban saat pin peta ditekan.
  void _showSosDetailSheet(Map<String, dynamic> sos) {
    showVolunteerSosDetailSheet(
      context: context,
      sos: sos,
      volunteerPosition: _locationService.currentPosition.value,
      resolveAddress: (data, lat, lng) => _resolveAddress(data, lat, lng),
      isFetchingRoute: _isFetchingRoute,
      onAcceptOrDetail: () async {
        Navigator.pop(context);
        await _handleAcceptOrViewTask(sos);
      },
    );
  }

  /// Alias kompatibilitas untuk _showSosDetailSheet
  void _showSosDetails(Map<String, dynamic> sos) => _showSosDetailSheet(sos);

  Future<void> _handleAcceptOrViewTask(Map<String, dynamic> sos) async {
    try {
      final dataSource = sl<VolunteerRemoteDataSource>();
      final dynamic rawSosId = sos['id'];
      final int sosId = (rawSosId is int)
          ? rawSosId
          : int.tryParse(rawSosId?.toString() ?? '0') ?? 0;

      final sosLat = double.tryParse(sos['latitude']?.toString() ?? '') ?? 0.0;
      final sosLng = double.tryParse(sos['longitude']?.toString() ?? '') ?? 0.0;
      final volunteerPos = _locationService.currentPosition.value;

      if (sos['is_assigned'] == true) {
        if (mounted) {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => VolunteerActiveTaskPage(
                initialTask: sos,
              ),
            ),
          );
          if (mounted) {
            setState(() {
              _acceptedSos = null;
              _routePoints.clear();
            });
            await _fetchActiveSos();
          }
        }
      } else {
        await dataSource.updateSosStatus(sosId, 'ditangani');
        sos['is_assigned'] = true;
        sos['status_sos'] = 'ditangani';
        setState(() {
          _acceptedSos = sos;
        });
        if (volunteerPos != null && sosLat != 0.0 && sosLng != 0.0) {
          unawaited(_fetchRoute(
            LatLng(volunteerPos.latitude, volunteerPos.longitude),
            LatLng(sosLat, sosLng),
          ));
        }
        event_bus.GlobalEventBus.refreshMap.value =
            !event_bus.GlobalEventBus.refreshMap.value;

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Tugas diterima! Menuju lokasi korban...'),
            ),
          );
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => VolunteerActiveTaskPage(
                initialTask: sos,
              ),
            ),
          );
          if (mounted) {
            setState(() {
              _acceptedSos = null;
              _routePoints.clear();
            });
            await _fetchActiveSos();
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Terjadi kesalahan: $e'),
          ),
        );
      }
    }
  }
}
