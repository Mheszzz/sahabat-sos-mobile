import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import 'package:sahabat_sos_mobile/core/di/injection.dart';
import 'package:sahabat_sos_mobile/core/services/accessibility_service.dart';
import 'package:sahabat_sos_mobile/core/services/location_service.dart';
import 'package:sahabat_sos_mobile/core/theme/accessible_colors.dart';
import 'package:sahabat_sos_mobile/core/utils/global_event_bus.dart'
    as import_event_bus;
import 'package:sahabat_sos_mobile/features/volunteer_task/data/datasources/volunteer_remote_data_source.dart';
import 'package:url_launcher/url_launcher.dart';

class VolunteerActiveTaskPage extends StatefulWidget {
  final Map<String, dynamic>? initialTask;
  const VolunteerActiveTaskPage({super.key, this.initialTask});

  @override
  State<VolunteerActiveTaskPage> createState() =>
      _VolunteerActiveTaskPageState();
}

class _VolunteerActiveTaskPageState extends State<VolunteerActiveTaskPage> {
  static const Color primaryTeal = Color(0xFF006D77);
  static const Color sosRed = Color(0xFFDC2626);

  final _dataSource = sl<VolunteerRemoteDataSource>();
  final _locationService = sl<LocationService>();
  final GlobalKey<SlideToCompleteButtonState> _sliderKey = GlobalKey();
  Map<String, dynamic>? _activeTask;
  bool _isLoading = true;
  bool _isCompleting = false;

  LatLng? _effectiveVolPos;
  List<LatLng> _routePoints = [];
  String _etaText = 'Menghitung...';
  bool _isFetchingRoute = false;
  DateTime? _lastRouteRecalculation;
  LatLng? _lastRouteCalcPos;
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

    _locationService.startTracking();
    _locationService.currentPosition.addListener(_onLivePositionChanged);
    _locationService.latestReroute.addListener(_onServerRerouteReceived);
  }

  @override
  void dispose() {
    _locationService.currentPosition.removeListener(_onLivePositionChanged);
    _locationService.latestReroute.removeListener(_onServerRerouteReceived);
    import_event_bus.GlobalEventBus.refreshMap.removeListener(_fetchTask);
    _mapController.dispose();
    super.dispose();
  }

  void _onServerRerouteReceived() {
    final newRoute = _locationService.latestReroute.value;
    if (newRoute == null || !mounted) return;

    final polylineData = newRoute['polyline'] as List?;
    final durationStr = newRoute['duration_formatted']?.toString();
    final distanceStr = newRoute['distance_formatted']?.toString();

    if (polylineData != null && polylineData.isNotEmpty) {
      setState(() {
        if (durationStr != null && distanceStr != null) {
          _etaText = '$durationStr ($distanceStr)';
        }
        _routePoints = polylineData.map((coord) {
          final num latVal = coord[1] as num;
          final num lngVal = coord[0] as num;
          return LatLng(latVal.toDouble(), lngVal.toDouble());
        }).toList();
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Rute diperbarui otomatis (rerouting terdeteksi server)'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    }
  }

  double? _extractCoordinate(String key) {
    if (_activeTask == null) return null;
    final val = _activeTask![key];
    if (val != null) {
      final parsed = double.tryParse(val.toString());
      if (parsed != null) return parsed;
    }
    final lokasi = _activeTask!['lokasi'];
    if (lokasi is Map && lokasi[key] != null) {
      return double.tryParse(lokasi[key].toString());
    }
    return null;
  }

  void _onLivePositionChanged() {
    final pos = _locationService.currentPosition.value;
    if (pos == null || !mounted) return;

    final currentPos = LatLng(pos.latitude, pos.longitude);
    setState(() {
      _effectiveVolPos = currentPos;
    });

    final targetLat = _extractCoordinate('latitude');
    final targetLng = _extractCoordinate('longitude');

    if (targetLat != null && targetLng != null && !_isFetchingRoute) {
      final now = DateTime.now();
      final shouldRecalculate = _routePoints.isEmpty ||
          _lastRouteRecalculation == null ||
          now.difference(_lastRouteRecalculation!).inSeconds >= 30 ||
          (_lastRouteCalcPos != null &&
              const Distance().as(
                    LengthUnit.Meter,
                    _lastRouteCalcPos!,
                    currentPos,
                  ) >=
                  50);

      if (shouldRecalculate) {
        _lastRouteRecalculation = now;
        _lastRouteCalcPos = currentPos;
        _fetchRoute(currentPos, LatLng(targetLat, targetLng));
      }
    }
  }

  Future<void> _fetchRoute(LatLng start, LatLng end) async {
    if (!mounted) return;
    setState(() {
      _isFetchingRoute = true;
    });

    try {
      final routeData = await _dataSource.fetchDrivingRoute(
        startLat: start.latitude,
        startLng: start.longitude,
        endLat: end.latitude,
        endLng: end.longitude,
      );

      if (mounted) {
        final routes = routeData['routes'] as List?;
        if (routes == null || routes.isEmpty) {
          setState(() {
            _etaText = 'Tidak ditemukan';
          });
          return;
        }

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
    } catch (e) {
      debugPrint('Error fetching route: $e');
      if (mounted) {
        setState(() {
          _etaText = 'Gagal memuat rute';
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

    final lat = _extractCoordinate('latitude');
    final lng = _extractCoordinate('longitude');
    final volPos = _locationService.currentPosition.value;

    if (lat != null && lng != null) {
      if (volPos != null) {
        _effectiveVolPos = LatLng(volPos.latitude, volPos.longitude);
      } else {
        _effectiveVolPos = null;
      }

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
        _etaText = 'Lokasi tidak valid';
      });
    }
  }

  Future<void> _fetchTask() async {
    if (!mounted || _isCompleting) return;
    if (_activeTask == null) {
      setState(() {
        _isLoading = true;
        _routePoints.clear();
        _etaText = 'Menghitung...';
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

  Future<void> _callVictim(String phone) async {
    final cleanPhone = phone.replaceAll(RegExp(r'[^0-9+]'), '');
    if (cleanPhone.isEmpty || cleanPhone == '-') {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Nomor telepon pelapor tidak tersedia')),
        );
      }
      return;
    }
    final uri = Uri.parse('tel:$cleanPhone');
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      } else {
        await launchUrl(uri);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Tidak dapat membuka aplikasi panggilan telepon'),
          ),
        );
      }
    }
  }

  Future<void> _chatVictim(String phone, {String? victimName}) async {
    final cleanPhone = phone.replaceAll(RegExp(r'[^0-9+]'), '');

    // 1. Coba hubungi via endpoint API chat-wa relawan (mencatat aktivitas & pesan template resmi backend)
    if (_activeTask != null && _activeTask!['id'] != null) {
      try {
        final idSos = _activeTask!['id'];
        final isLaporan = _activeTask!['tipe'] == 'laporan' ||
            (_activeTask!['tipe'] != 'sos' &&
                _activeTask!['kategori_laporan'] != 'SOS' &&
                _activeTask!['kategori_laporan'] != null);
        final tipe = isLaporan ? 'laporan' : 'sos';
        final idInt = idSos is int ? idSos : int.tryParse(idSos.toString());

        if (idInt != null) {
          final waUrl = await _dataSource.getChatWaPengguna(tipe, idInt);
          if (waUrl != null && waUrl.isNotEmpty) {
            final uri = Uri.parse(waUrl);
            if (await canLaunchUrl(uri)) {
              await launchUrl(uri, mode: LaunchMode.externalApplication);
              return;
            } else {
              try {
                await launchUrl(uri, mode: LaunchMode.externalApplication);
                return;
              } catch (_) {}
            }
          }
        }
      } catch (e) {
        debugPrint('Catatan: Gagal mendapatkan WhatsApp URL via endpoint backend: $e');
      }
    }

    // 2. Fallback: Langsung buka WhatsApp via nomor telepon pelapor
    if (cleanPhone.isEmpty || cleanPhone == '-') {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Nomor kontak pelapor tidak tersedia')),
        );
      }
      return;
    }

    String waPhone = cleanPhone;
    if (waPhone.startsWith('0')) {
      waPhone = '62${waPhone.substring(1)}';
    } else if (waPhone.startsWith('+')) {
      waPhone = waPhone.substring(1);
    }

    final targetNama = victimName ?? 'Warga';
    final message = Uri.encodeComponent(
      'Halo $targetNama, saya Relawan Sahabat SOS yang sedang merespon laporan Anda. Mohon tetap tenang, saya sedang bergerak membantu Anda.',
    );
    final waUri = Uri.parse('https://wa.me/$waPhone?text=$message');

    try {
      if (await canLaunchUrl(waUri)) {
        await launchUrl(waUri, mode: LaunchMode.externalApplication);
        return;
      } else {
        await launchUrl(waUri, mode: LaunchMode.externalApplication);
        return;
      }
    } catch (_) {
      // 3. Fallback: Buka SMS jika WhatsApp tidak tersedia
      final smsUri = Uri.parse('sms:$cleanPhone');
      try {
        if (await canLaunchUrl(smsUri)) {
          await launchUrl(smsUri);
          return;
        } else {
          await launchUrl(smsUri);
          return;
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Tidak dapat membuka WhatsApp maupun SMS'),
            ),
          );
        }
      }
    }
  }

  Future<void> _hubungiKontakDarurat() async {
    if (_activeTask == null) return;

    final idSos = _activeTask!['id'];
    final isLaporan = _activeTask!['tipe'] == 'laporan' ||
        (_activeTask!['tipe'] != 'sos' &&
            _activeTask!['kategori_laporan'] != 'SOS' &&
            _activeTask!['kategori_laporan'] != null);

    final isHighContrast =
        AccessibilityService.instance.isHighContrastEnabled ||
        Theme.of(context).brightness == Brightness.dark ||
        MediaQuery.of(context).highContrast;
    final dialogBg = AccessibleColors.cardBackground(isHighContrast);
    final textPrimary = AccessibleColors.textPrimary(isHighContrast);
    final textSecondary = AccessibleColors.textSecondary(isHighContrast);

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
          'Kirim notifikasi peringatan ke kontak darurat terdaftar korban?',
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
              backgroundColor: sosRed,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text('Kirim Notifikasi'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) =>
            const Center(child: CupertinoActivityIndicator(radius: 16)),
      );

      final tipe = isLaporan ? 'laporan' : 'sos';
      final idInt = idSos is int ? idSos : int.parse(idSos.toString());
      final waUrl = await _dataSource.hubungiKontakDarurat(tipe, idInt);

      if (!mounted) return;
      Navigator.pop(context);

      if (waUrl != null && waUrl.isNotEmpty) {
        final uri = Uri.parse(waUrl);
        try {
          if (await canLaunchUrl(uri)) {
            await launchUrl(uri, mode: LaunchMode.externalApplication);
          } else {
            await launchUrl(uri, mode: LaunchMode.externalApplication);
          }
        } catch (err) {
          debugPrint('Error membuka WhatsApp kontak darurat: $err');
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Notifikasi telah dikirim ke kontak darurat korban'),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal menghubungi kontak darurat: $e')),
      );
    }
  }

  Future<void> _completeTask(dynamic idSos, bool isLaporan, {String? catatan}) async {
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);

    try {
      _isCompleting = true;
      if (isLaporan) {
        await _dataSource.updateLaporanStatus(idSos, 'selesai', catatan: catatan);
      } else {
        final sosIdInt = idSos is int ? idSos : int.parse(idSos.toString());
        await _dataSource.updateSosStatus(sosIdInt, 'selesai', catatan: catatan);
      }

      import_event_bus.GlobalEventBus.changeVolunteerTab.value = 1;
      import_event_bus.GlobalEventBus.refreshMap.value =
          !import_event_bus.GlobalEventBus.refreshMap.value;

      if (!mounted) return;
      messenger.showSnackBar(
        const SnackBar(content: Text('Tugas telah berhasil diselesaikan dengan catatan tersimpan.')),
      );
      navigator.popUntil((route) => route.isFirst);
    } catch (e) {
      _isCompleting = false;
      _sliderKey.currentState?.reset();
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text('Gagal menyelesaikan tugas: $e')),
      );
    }
  }

  Future<void> _showCompletionDialog(dynamic idSos, bool isLaporan) async {
    final isHighContrast =
        AccessibilityService.instance.isHighContrastEnabled ||
        Theme.of(context).brightness == Brightness.dark ||
        MediaQuery.of(context).highContrast;
    final dialogBg = AccessibleColors.cardBackground(isHighContrast);
    final textPrimary = AccessibleColors.textPrimary(isHighContrast);
    final textSecondary = AccessibleColors.textSecondary(isHighContrast);
    final tealColor = AccessibleColors.primaryTeal(isHighContrast);

    final TextEditingController notesController = TextEditingController();
    final List<String> presetChips = [
      'Pertolongan Pertama Selesai',
      'Pemberian Obat / Rawat Luka',
      'Didampingi ke Lokasi Aman',
      'Dirujuk ke Puskesmas / RS',
      'Kondisi Korban Stabil & Terkendali',
    ];
    final Set<String> selectedChips = {};

    final bool? result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: dialogBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
                top: 20,
                left: 20,
                right: 20,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade400,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: tealColor.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            CupertinoIcons.checkmark_shield_fill,
                            color: tealColor,
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Catatan Penutupan Kasus',
                                style: TextStyle(
                                  color: textPrimary,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 18,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Catatan tindakan lapangan & medis relawan',
                                style: TextStyle(
                                  color: textSecondary,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Tindakan Cepat (Pilih yang sesuai):',
                      style: TextStyle(
                        color: textPrimary,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: presetChips.map((chip) {
                        final isSelected = selectedChips.contains(chip);
                        return FilterChip(
                          label: Text(
                            chip,
                            style: TextStyle(
                              color: isSelected ? Colors.white : textPrimary,
                              fontSize: 12,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                            ),
                          ),
                          selected: isSelected,
                          onSelected: (selected) {
                            setModalState(() {
                              if (selected) {
                                selectedChips.add(chip);
                              } else {
                                selectedChips.remove(chip);
                              }
                              final chipText = selectedChips.map((c) => '• $c').join('\n');
                              final currentLines = notesController.text
                                  .split('\n')
                                  .where((l) => !presetChips.any((p) => l.contains(p)))
                                  .where((l) => l.trim().isNotEmpty)
                                  .join('\n');

                              if (currentLines.isNotEmpty) {
                                notesController.text = chipText.isNotEmpty
                                    ? '$chipText\n$currentLines'
                                    : currentLines;
                              } else {
                                notesController.text = chipText;
                              }
                            });
                          },
                          selectedColor: tealColor,
                          backgroundColor: isHighContrast
                              ? const Color(0xFF1E2430)
                              : const Color(0xFFF3F4F6),
                          checkmarkColor: Colors.white,
                          side: BorderSide(
                            color: isSelected
                                ? tealColor
                                : (isHighContrast
                                    ? const Color(0xFF4B5563)
                                    : const Color(0xFFD1D5DB)),
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Rincian Tindakan / Catatan Medis Lapangan:',
                      style: TextStyle(
                        color: textPrimary,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: notesController,
                      maxLines: 4,
                      style: TextStyle(color: textPrimary, fontSize: 13),
                      decoration: InputDecoration(
                        hintText: 'Tuliskan tindakan yang diberikan, kondisi korban, atau rujukan faskes...',
                        hintStyle: TextStyle(
                          color: textSecondary.withValues(alpha: 0.6),
                          fontSize: 12,
                        ),
                        filled: true,
                        fillColor: isHighContrast
                            ? const Color(0xFF1E2430)
                            : const Color(0xFFF9FAFB),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: isHighContrast
                                ? const Color(0xFF4B5563)
                                : const Color(0xFFD1D5DB),
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: tealColor, width: 1.5),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(
                          child: SizedBox(
                            height: 48,
                            child: OutlinedButton(
                              onPressed: () => Navigator.pop(ctx, false),
                              style: OutlinedButton.styleFrom(
                                side: BorderSide(
                                  color: isHighContrast
                                      ? const Color(0xFF4B5563)
                                      : const Color(0xFFD1D5DB),
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: Text(
                                'Batal',
                                style: TextStyle(
                                  color: textSecondary,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: SizedBox(
                            height: 48,
                            child: ElevatedButton(
                              onPressed: () {
                                Navigator.pop(ctx, true);
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: tealColor,
                                foregroundColor: Colors.white,
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: const Text(
                                'Selesaikan Kasus',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    if (result == true) {
      final catatan = notesController.text.trim();
      await _completeTask(idSos, isLaporan, catatan: catatan.isNotEmpty ? catatan : null);
    } else {
      _sliderKey.currentState?.reset();
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
        final currentBg = AccessibleColors.scaffoldBackground(isHighContrast);
        final cardBg = AccessibleColors.cardBackground(isHighContrast);
        final tealColor = AccessibleColors.primaryTeal(isHighContrast);
        final textPrimary = AccessibleColors.textPrimary(isHighContrast);
        final textSecondary = AccessibleColors.textSecondary(isHighContrast);

        if (_isLoading) {
          return Scaffold(
            backgroundColor: currentBg,
            appBar: AppBar(
              backgroundColor: cardBg,
              elevation: 0,
              leading: BackButton(
                color: tealColor,
                onPressed: () => context.pop(),
              ),
              title: Text(
                'Detail Penanganan Tugas',
                style: TextStyle(
                  color: tealColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
            body: Center(
              child: CupertinoActivityIndicator(
                radius: 16,
                color: tealColor,
              ),
            ),
          );
        }

        if (_activeTask == null) {
          return Scaffold(
            backgroundColor: currentBg,
            appBar: AppBar(
              backgroundColor: cardBg,
              elevation: 0,
              leading: BackButton(
                color: tealColor,
                onPressed: () => context.pop(),
              ),
              title: Text(
                'Detail Tugas',
                style: TextStyle(
                  color: tealColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Container(
                  padding: const EdgeInsets.all(28),
                  decoration: BoxDecoration(
                    color: cardBg,
                    borderRadius: BorderRadius.circular(16),
                    border: AccessibleColors.cardBorder(isHighContrast),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(
                          alpha: isHighContrast ? 0.35 : 0.04,
                        ),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        CupertinoIcons.doc_text_search,
                        size: 56,
                        color: tealColor,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Tidak Ada Tugas Aktif',
                        style: TextStyle(
                          color: textPrimary,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Belum ada tugas darurat yang sedang Anda tangani saat ini.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: textSecondary,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 20),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          OutlinedButton.icon(
                            onPressed: () => context.pop(),
                            icon: const Icon(CupertinoIcons.arrow_left, size: 16),
                            label: const Text('Kembali'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: tealColor,
                              minimumSize: const Size(110, 48),
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
                              backgroundColor: tealColor,
                              foregroundColor: Colors.white,
                              minimumSize: const Size(120, 48),
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
            ),
          );
        }

        final idSos = _activeTask!['id'] ?? '-';
        final isLaporan = _activeTask!['tipe'] == 'laporan' ||
            (_activeTask!['tipe'] != 'sos' &&
                _activeTask!['kategori_laporan'] != 'SOS' &&
                _activeTask!['kategori_laporan'] != null);
        final idKasus = _activeTask!['id_kasus'] ??
            _activeTask!['nomor_kasus'] ??
            (isLaporan ? 'LAP-$idSos' : 'SOS-$idSos');
        final pengguna = (_activeTask!['pengguna'] is Map ? _activeTask!['pengguna'] : null) ??
            (_activeTask!['pelapor'] is Map ? _activeTask!['pelapor'] : null) ??
            {};
        final nama = pengguna['name']?.toString() ??
            pengguna['nama']?.toString() ??
            'Warga / Pelapor';
        final phone = (pengguna['phone'] ??
                pengguna['nomor_telepon'] ??
                pengguna['no_telp'] ??
                pengguna['no_telp_wa'] ??
                pengguna['telepon'] ??
                '')
            .toString();

        String lokasi = 'Lokasi tidak diketahui';
        final rawLokasi = _activeTask!['lokasi_user'] ??
            _activeTask!['lokasi_laporan'] ??
            _activeTask!['lokasi'] ??
            _activeTask!['alamat'];
        if (rawLokasi is Map) {
          lokasi = rawLokasi['alamat']?.toString() ??
              rawLokasi['nama']?.toString() ??
              rawLokasi['lokasi']?.toString() ??
              'Lokasi tidak diketahui';
        } else if (rawLokasi != null && rawLokasi.toString().isNotEmpty) {
          lokasi = rawLokasi.toString();
        }

        final targetLat = _extractCoordinate('latitude');
        final targetLng = _extractCoordinate('longitude');

        final kategoriUser = pengguna['kategori_user']?.toString() ?? 'Umum';
        final catatanMedis = (pengguna['catatan_medis'] != null &&
                pengguna['catatan_medis'].toString().isNotEmpty)
            ? pengguna['catatan_medis'].toString()
            : ((pengguna['keterangan_medis'] != null &&
                    pengguna['keterangan_medis'].toString().isNotEmpty)
                ? pengguna['keterangan_medis'].toString()
                : 'Tidak ada catatan medis spesifik');

        String protocolText =
            'Tetap tenang, perkenalkan diri Anda dengan ramah, dan tanyakan bantuan yang dibutuhkan.';
        if (kategoriUser.toString().toLowerCase().contains('tunanetra')) {
          protocolText =
              'Dekati dari arah depan, sebutkan nama dan identitas relawan Sahabat SOS secara artikulatif sebelum menyentuh atau memandu korban.';
        } else if (kategoriUser.toString().toLowerCase().contains('tunarungu') ||
            kategoriUser.toString().toLowerCase().contains('tuli')) {
          protocolText =
              'Sentuh pundak dengan lembut untuk menarik perhatian, bicara berhadapan agar gerak bibir terlihat, atau gunakan tulisan di ponsel.';
        } else if (kategoriUser.toString().toLowerCase().contains('tunadaksa')) {
          protocolText =
              'Tanyakan terlebih dahulu cara terbaik membantu mobilitas mereka. Jangan memindahkan atau menarik tubuh tanpa persetujuan.';
        }

        const int currentStep = 2;
        const int totalSteps = 3;

        return Scaffold(
          backgroundColor: currentBg,
          appBar: AppBar(
            backgroundColor: cardBg,
            elevation: 0,
            leading: BackButton(
              color: tealColor,
              onPressed: () => context.pop(),
            ),
            title: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Image.asset('assets/images/logo.png', height: 24),
                const SizedBox(width: 8),
                Text(
                  'Penanganan Tugas',
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
              Semantics(
                label: 'Hubungi pelapor via telepon',
                button: true,
                child: Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: Material(
                    color: isHighContrast
                        ? const Color(0xFF1E2430)
                        : const Color(0xFFFEE2E2),
                    shape: const CircleBorder(),
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      onTap: () => _callVictim(phone),
                      child: Container(
                        width: 44,
                        height: 44,
                        alignment: Alignment.center,
                        child: const Icon(
                          CupertinoIcons.phone_fill,
                          color: sosRed,
                          size: 20,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          body: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: isHighContrast
                          ? const Color(0xFF450A0A)
                          : const Color(0xFFDC2626),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isHighContrast
                            ? const Color(0xFFEF4444)
                            : const Color(0xFFB91C1C),
                        width: isHighContrast ? 1.5 : 1.0,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFDC2626).withValues(
                            alpha: isHighContrast ? 0.35 : 0.2,
                          ),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(
                              CupertinoIcons.time,
                              color: Colors.white,
                              size: 14,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'Nomor Tugas: $idKasus',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          isLaporan ? 'Laporan Warga' : 'Panggilan Darurat SOS',
                          style: const TextStyle(
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
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                lokasi,
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.95),
                                  fontSize: 13,
                                  height: 1.3,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),

                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: cardBg,
                      borderRadius: BorderRadius.circular(16),
                      border: AccessibleColors.cardBorder(isHighContrast),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(
                            alpha: isHighContrast ? 0.35 : 0.04,
                          ),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
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
                                color: textSecondary,
                                letterSpacing: 0.5,
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
                                    : primaryTeal.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(12),
                                border: isHighContrast
                                    ? Border.all(color: const Color(0xFF00897B))
                                    : null,
                              ),
                              child: Text(
                                'Tahap $currentStep dari $totalSteps',
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
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),

                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: cardBg,
                      borderRadius: BorderRadius.circular(16),
                      border: AccessibleColors.cardBorder(isHighContrast),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(
                            alpha: isHighContrast ? 0.35 : 0.04,
                          ),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
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
                                  'Rute Tercepat ke Lokasi',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                    color: textPrimary,
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
                                    : const Color(0xFFE6F4EA),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: isHighContrast
                                      ? const Color(0xFF00897B)
                                      : const Color(0xFFCEEAD6),
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
                        const SizedBox(height: 14),
                        Container(
                          height: 180,
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: isHighContrast
                                ? const Color(0xFF1E2430)
                                : Colors.grey[200],
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: isHighContrast
                                  ? const Color(0xFF4B5563)
                                  : const Color(0xFFE5E7EB),
                            ),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(14),
                            child: Stack(
                              children: [
                                FlutterMap(
                                  mapController: _mapController,
                                  options: MapOptions(
                                    initialCenter: _routePoints.isNotEmpty
                                        ? _routePoints.first
                                        : (targetLat != null && targetLng != null)
                                            ? LatLng(targetLat, targetLng)
                                            : _effectiveVolPos ??
                                                const LatLng(-6.200000, 106.816666),
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
                                        if (targetLat != null && targetLng != null)
                                          Marker(
                                            point: LatLng(targetLat, targetLng),
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
                                if (_isFetchingRoute)
                                  const Center(
                                    child: CupertinoActivityIndicator(
                                        radius: 16),
                                  ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          height: 48,
                          child: OutlinedButton.icon(
                            onPressed: () {
                              if (targetLat != null && targetLng != null) {
                                _openExternalNavigation(targetLat, targetLng);
                              } else {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Titik koordinat lokasi belum lengkap'),
                                  ),
                                );
                              }
                            },
                            icon: Icon(
                              CupertinoIcons.arrow_up_right_square,
                              size: 16,
                              color: tealColor,
                            ),
                            label: Text(
                              'Buka Navigasi Google Maps',
                              style: TextStyle(
                                color: tealColor,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: tealColor,
                              side: BorderSide(
                                color: isHighContrast
                                    ? const Color(0xFF4B5563)
                                    : const Color(0xFFD1D5DB),
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),

                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: cardBg,
                      borderRadius: BorderRadius.circular(16),
                      border: AccessibleColors.cardBorder(isHighContrast),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(
                            alpha: isHighContrast ? 0.35 : 0.04,
                          ),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            CircleAvatar(
                              backgroundColor: isHighContrast
                                  ? const Color(0xFF1E3A34)
                                  : primaryTeal.withValues(alpha: 0.12),
                              radius: 24,
                              child: Icon(
                                CupertinoIcons.person_solid,
                                color: tealColor,
                                size: 22,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          nama,
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 16,
                                            color: textPrimary,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      if (kategoriUser.toLowerCase() !=
                                              'umum' &&
                                          kategoriUser != '')
                                        Container(
                                          margin: const EdgeInsets.only(left: 6),
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 3,
                                          ),
                                          decoration: BoxDecoration(
                                            color: isHighContrast
                                                ? const Color(0xFF1E3A5F)
                                                : const Color(0xFFEFF6FF),
                                            borderRadius:
                                                BorderRadius.circular(8),
                                            border: Border.all(
                                              color: isHighContrast
                                                  ? const Color(0xFF3B82F6)
                                                  : const Color(0xFFBFDBFE),
                                            ),
                                          ),
                                          child: Text(
                                            kategoriUser,
                                            style: TextStyle(
                                              color: isHighContrast
                                                  ? const Color(0xFF93C5FD)
                                                  : const Color(0xFF1D4ED8),
                                              fontSize: 11,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    catatanMedis,
                                    style: TextStyle(
                                      color: textSecondary,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),

                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: isHighContrast
                                ? const Color(0xFF3B2904)
                                : const Color(0xFFFFFBEB),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isHighContrast
                                  ? const Color(0xFFD97706)
                                  : const Color(0xFFFDE68A),
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
                                        : const Color(0xFFD97706),
                                    size: 16,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    'Panduan Interaksi:',
                                    style: TextStyle(
                                      color: isHighContrast
                                          ? const Color(0xFFFDE68A)
                                          : const Color(0xFF92400E),
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
                                      : const Color(0xFF92400E),
                                  fontSize: 12,
                                  height: 1.35,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),

                        Row(
                          children: [
                            Expanded(
                              child: SizedBox(
                                height: 48,
                                child: OutlinedButton.icon(
                                  onPressed: () => _callVictim(phone),
                                  icon: Icon(
                                    CupertinoIcons.phone,
                                    size: 16,
                                    color: tealColor,
                                  ),
                                  label: Text(
                                    'Panggil',
                                    style: TextStyle(
                                      color: tealColor,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: tealColor,
                                    side: BorderSide(
                                      color: isHighContrast
                                          ? const Color(0xFF4B5563)
                                          : const Color(0xFFD1D5DB),
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: SizedBox(
                                height: 48,
                                child: OutlinedButton.icon(
                                  onPressed: () => _chatVictim(phone, victimName: nama),
                                  icon: Icon(
                                    CupertinoIcons.chat_bubble,
                                    size: 16,
                                    color: tealColor,
                                  ),
                                  label: Text(
                                    'Pesan/WA',
                                    style: TextStyle(
                                      color: tealColor,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: tealColor,
                                    side: BorderSide(
                                      color: isHighContrast
                                          ? const Color(0xFF4B5563)
                                          : const Color(0xFFD1D5DB),
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        SizedBox(
                          width: double.infinity,
                          height: 48,
                          child: ElevatedButton.icon(
                            onPressed: _hubungiKontakDarurat,
                            icon: const Icon(
                              CupertinoIcons.exclamationmark_triangle_fill,
                              color: sosRed,
                              size: 16,
                            ),
                            label: const Text(
                              'Kirim Peringatan ke Kontak Darurat',
                              style: TextStyle(
                                color: sosRed,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: isHighContrast
                                  ? const Color(0xFF450A0A)
                                  : const Color(0xFFFEE2E2),
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                                side: BorderSide(
                                  color: isHighContrast
                                      ? const Color(0xFFEF4444)
                                      : const Color(0xFFFCA5A5),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  SizedBox(
                    width: double.infinity,
                    child: SlideToCompleteButton(
                      key: _sliderKey,
                      label: 'Geser Jika Tugas Selesai',
                      onCompleted: () => _showCompletionDialog(idSos, isLaporan),
                    ),
                  ),
                  const SizedBox(height: 80),
                ],
              ),
            ),
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
  }) {
    final bool isCompleted = stepNum < currentStep;
    final bool isActive = stepNum == currentStep;
    final tealColor = AccessibleColors.primaryTeal(isHighContrast);
    final activeBg = isHighContrast ? const Color(0xFF00897B) : primaryTeal;

    IconData? icon;
    if (isCompleted) {
      icon = CupertinoIcons.check_mark;
    } else if (isActive && stepNum == 2) {
      icon = CupertinoIcons.location_solid;
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
                    : const Color(0xFFF3F4F6)),
            shape: BoxShape.circle,
            border: Border.all(
              color: isCompleted || isActive
                  ? Colors.transparent
                  : (isHighContrast
                      ? const Color(0xFF4B5563)
                      : const Color(0xFFD1D5DB)),
              width: 1.5,
            ),
            boxShadow: [
              if (isActive)
                BoxShadow(
                  color: primaryTeal.withValues(alpha: 0.25),
                  blurRadius: 6,
                  spreadRadius: 1,
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
                              : const Color(0xFF6B7280)),
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
                        : const Color(0xFF6B7280))),
            fontWeight: isActive || isCompleted
                ? FontWeight.bold
                : FontWeight.w500,
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
        margin: const EdgeInsets.only(bottom: 14),
        color: isCompleted
            ? (isHighContrast ? const Color(0xFF00897B) : primaryTeal)
            : (isHighContrast ? const Color(0xFF4B5563) : const Color(0xFFE5E7EB)),
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
  State<SlideToCompleteButton> createState() => SlideToCompleteButtonState();
}

class SlideToCompleteButtonState extends State<SlideToCompleteButton> {
  double _dragPosition = 0.0;
  bool _isCompleted = false;
  final double _thumbSize = 56.0;

  void reset() {
    if (mounted) {
      setState(() {
        _dragPosition = 0.0;
        _isCompleted = false;
      });
    }
  }

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
              Center(
                child: Text(
                  _isCompleted ? 'Menyelesaikan kasus...' : widget.label,
                  style: TextStyle(
                    color: labelColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
              ),
              AnimatedContainer(
                duration: _dragPosition == 0.0
                    ? const Duration(milliseconds: 250)
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
                      Positioned(
                        left: 0,
                        width: maxWidth,
                        child: Container(
                          height: _thumbSize,
                          alignment: Alignment.center,
                          child: Text(
                            _isCompleted ? 'Menyelesaikan kasus...' : widget.label,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              AnimatedPositioned(
                duration: _dragPosition == 0.0
                    ? const Duration(milliseconds: 250)
                    : Duration.zero,
                curve: Curves.easeOutCubic,
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
                      HapticFeedback.heavyImpact();
                      setState(() {
                        _dragPosition = maxDrag;
                        _isCompleted = true;
                      });
                      widget.onCompleted();
                    } else {
                      HapticFeedback.selectionClick();
                      setState(() {
                        _dragPosition = 0.0;
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
                          color: Colors.black.withValues(alpha: 0.2),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: const Icon(
                      CupertinoIcons.chevron_right_2,
                      color: Colors.white,
                      size: 28,
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
