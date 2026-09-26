import 'package:sahabat_sos_mobile/core/utils/global_event_bus.dart' as import_event_bus;
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

class VolunteerMapPage extends StatefulWidget {
  const VolunteerMapPage({super.key});

  @override
  State<VolunteerMapPage> createState() => _VolunteerMapPageState();
}

class _VolunteerMapPageState extends State<VolunteerMapPage>
    with SingleTickerProviderStateMixin {
  static const Color primaryTeal = Color(0xFF00695C);
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
      _mapController.move(LatLng(pos.latitude, pos.longitude), 15.0);
      _isFirstFix = false;
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
    return {
      'Authorization': 'Bearer $token',
      'Accept': 'application/json',
    };
  }

  Future<void> _fetchActiveSos() async {
    try {
      final dio = sl<Dio>();
      final options = Options(headers: _getHeaders());

      // 1. Fetch SOS yang belum diambil
      final responseUnassigned = await dio.get(ApiConstants.sosActiveRelawan, options: options);
      
      // 2. Fetch SOS yang SEDANG diproses oleh relawan ini
      final responseAssigned = await dio.get(ApiConstants.sosRelawanTasks, options: options);

      if (mounted) {
        List<Map<String, dynamic>> combinedList = [];

        // Parse Unassigned
        if (responseUnassigned.statusCode == 200) {
          final dynamic rawData = responseUnassigned.data['data'];
          if (rawData != null && rawData is Map<String, dynamic>) {
            combinedList.add(rawData);
          } else if (rawData is List) {
            combinedList.addAll(rawData.cast<Map<String, dynamic>>());
          }
        }

        // Parse Assigned (yang sudah diterima/diproses relawan ini)
        if (responseAssigned.statusCode == 200) {
          final dynamic rawData = responseAssigned.data['data'];
          if (rawData != null && rawData is Map<String, dynamic>) {
            final dataMap = Map<String, dynamic>.from(rawData);
            dataMap['is_assigned'] = true;
            combinedList.add(dataMap);
          } else if (rawData is List) {
            final assignedList = rawData.cast<Map<String, dynamic>>().map((e) {
              final map = Map<String, dynamic>.from(e);
              map['is_assigned'] = true;
              return map;
            }).toList();
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
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.white.withValues(alpha: 0.5),
        elevation: 0,
        centerTitle: true,
        title: const Text(
          'Peta Relawan',
          style: TextStyle(fontWeight: FontWeight.bold, color: primaryTeal),
        ),
        flexibleSpace: ClipRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(color: Colors.transparent),
          ),
        ),
      ),
      body: ValueListenableBuilder<Position?>(
        valueListenable: _locationService.currentPosition,
        builder: (context, position, _) {
          if (_isLoading || position == null) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: primaryTeal),
                  SizedBox(height: 16),
                  Text('Menunggu Sinyal GPS...',
                      style: TextStyle(color: primaryTeal, fontWeight: FontWeight.w500)),
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
                options: MapOptions(
                  initialCenter: myLatLng,
                  initialZoom: 15.0,
                ),
                children: [
                  TileLayer(
                    urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'com.sahabat_sos_mobile.app',
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
                                    border: Border.all(color: Colors.white, width: 3),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withValues(alpha: 0.2),
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
                      ..._activeSosList.map((sos) {
                        final lat = double.tryParse(sos['latitude'].toString()) ?? 0.0;
                        final lng = double.tryParse(sos['longitude'].toString()) ?? 0.0;
                        final name = sos['pengguna']?['name'] ?? 'SOS';
                        final isAssigned = sos['is_assigned'] == true;

                        return Marker(
                          point: LatLng(lat, lng),
                          width: 90,
                          height: 80,
                          child: GestureDetector(
                            onTap: () => _showSosDetails(sos),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: isAssigned ? Colors.amber.shade100 : Colors.white,
                                    borderRadius: BorderRadius.circular(6),
                                    border: isAssigned ? Border.all(color: Colors.amber.shade800, width: 1.5) : null,
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withValues(alpha: 0.15),
                                        blurRadius: 4,
                                      ),
                                    ],
                                  ),
                                  child: Text(
                                    name,
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: isAssigned ? Colors.amber.shade900 : sosRed,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Icon(
                                  isAssigned ? CupertinoIcons.location_solid : CupertinoIcons.exclamationmark_triangle_fill,
                                  color: isAssigned ? Colors.amber.shade800 : sosRed,
                                  size: 32,
                                ),
                              ],
                            ),
                          ),
                        );
                      }),
                    ],
                  ),
                ],
              ),

              // ── Recenter Button ──
              Positioned(
                bottom: 140,
                right: 16,
                child: FloatingActionButton(
                  heroTag: 'recenter_volunteer',
                  backgroundColor: Colors.white.withValues(alpha: 0.9),
                  elevation: 2,
                  onPressed: _recenterMap,
                  child: const Icon(Icons.my_location, color: primaryTeal),
                ),
              ),

              // ── SOS Counter Badge ──
              if (_activeSosList.isNotEmpty)
                Positioned(
                  top: MediaQuery.of(context).padding.top + kToolbarHeight + 12,
                  left: 16,
                  child: _buildGlassContainer(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
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
                bottom: 24,
                left: 16,
                right: 16,
                child: SafeArea(
                  child: _buildGlassContainer(
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: primaryTeal.withValues(alpha: 0.1),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.gps_fixed, color: primaryTeal, size: 22),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Text(
                                'Lokasi Anda (Relawan)',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                  color: primaryTeal,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${position.latitude.toStringAsFixed(5)}, ${position.longitude.toStringAsFixed(5)}  ·  ±${position.accuracy.toStringAsFixed(0)}m',
                                style: TextStyle(color: Colors.grey[600], fontSize: 12),
                              ),
                            ],
                          ),
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

  // ──────────────────── Glass Container ────────────────────

  Widget _buildGlassContainer({
    required Widget child,
    EdgeInsetsGeometry? padding,
    BorderRadius? borderRadius,
  }) {
    final radius = borderRadius ?? BorderRadius.circular(20);
    return ClipRRect(
      borderRadius: radius,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: padding ?? const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.7),
            borderRadius: radius,
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

  // ──────────────────── SOS Detail Sheet ────────────────────

  void _showSosDetails(Map<String, dynamic> sos) {
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

    final user = sos['user'] as Map<String, dynamic>? ?? {};
    final nama = user['nama'] ?? 'User';
    final noTelp = user['no_telp'] ?? '-';
    final alamat = sos['lokasi_user'] ?? 'Lokasi tidak diketahui';
    final status = sos['status_sos'] ?? 'aktif';

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
              // Handle bar
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.grey.withValues(alpha: 0.4),
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
                    child: const Icon(CupertinoIcons.exclamationmark_triangle_fill,
                        color: sosRed, size: 24),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      nama,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                        color: Colors.black87,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
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
              _buildDetailRow(CupertinoIcons.phone_fill, 'Telepon', noTelp),
              const SizedBox(height: 10),
              _buildDetailRow(
                CupertinoIcons.location_solid,
                'Lokasi',
                alamat,
              ),
              if (distanceKm != null) ...[
                const SizedBox(height: 10),
                _buildDetailRow(
                  CupertinoIcons.arrow_right_arrow_left,
                  'Jarak',
                  '${distanceKm.toStringAsFixed(1)} km dari Anda',
                ),
              ],
              const SizedBox(height: 20),

              // Accept Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  icon: const Icon(CupertinoIcons.checkmark_circle, size: 20),
                  label: const Text(
                    'Terima Tugas',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryTeal,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  onPressed: () {
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Tugas diterima!')),
                    );
                  },
                ),
              ),
              const SizedBox(height: 8),
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
        Icon(icon, size: 18, color: Colors.black54),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(fontSize: 11, color: Colors.black45)),
              const SizedBox(height: 2),
              Text(value,
                  style: const TextStyle(
                      fontSize: 14, color: Colors.black87, fontWeight: FontWeight.w500)),
            ],
          ),
        ),
      ],
    );
  }
}



