import 'package:flutter/cupertino.dart';
import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:dio/dio.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sahabat_sos_mobile/core/constants/api_constants.dart';
import 'package:sahabat_sos_mobile/core/di/injection.dart';
import 'package:sahabat_sos_mobile/core/services/location_service.dart';
import 'package:sahabat_sos_mobile/core/services/websocket_service.dart';
import 'sos_activities_sheet.dart';
import 'widgets/slide_to_cancel_button.dart';

class SosStatusPage extends StatefulWidget {
  final int? initialSosId;
  final String? initialStatus;

  const SosStatusPage({
    super.key,
    this.initialSosId,
    this.initialStatus,
  });

  @override
  State<SosStatusPage> createState() => _SosStatusPageState();
}

class _SosStatusPageState extends State<SosStatusPage> {
  static const Color primaryTeal = Color(0xFF00695C);
  static const Color sosRed = Color(0xFFE50000);

  Timer? _statusTimer;
  Timer? _selesaiTimer;
  bool _isSelesaiTimerStarted = false;
  String _sosStatus = 'belum ditangani';
  int? _sosId;
  double? _relawanDistance;

  bool get _isDitangani => _sosStatus == 'ditangani';
  bool get _isSelesai => _sosStatus == 'selesai';
  bool get _isBatal => _sosStatus == 'batal';

  final LocationService _locationService = sl<LocationService>();
  StreamSubscription<ServiceStatus>? _serviceStatusStream;

  @override
  void initState() {
    super.initState();
    _sosId = widget.initialSosId;
    if (widget.initialStatus != null && widget.initialStatus!.isNotEmpty) {
      _sosStatus = widget.initialStatus!;
    }
    _fetchSosStatus();
    _initWebSocket();
    // Poll for status every 4 seconds
    _statusTimer = Timer.periodic(
      const Duration(seconds: 4),
      (_) => _fetchSosStatus(),
    );
    // Start real-time location tracking so volunteer can see user position
    _startLocationTracking();
  }

  bool _isSubscribedToSos = false;

  Future<void> _initWebSocket() async {
    try {
      final prefs = sl<SharedPreferences>();
      final token = prefs.getString('auth_token');
      if (token == null) return;

      await WebsocketService.init(token);
      if (_sosId != null && mounted) {
        _setupWebSocketListeners(_sosId!);
      }
    } catch (e) {
      debugPrint('WebSocket init error in SosStatusPage: $e');
    }
  }

  void _setupWebSocketListeners(int sosId) {
    if (_isSubscribedToSos) return;
    if (WebsocketService.echo == null) {
      // Menunggu hingga WebsocketService.init selesai
      return;
    }
    _isSubscribedToSos = true;

    WebsocketService.listenToSosStatusUpdate(sosId, (payload) {
      if (!mounted || payload == null) return;
      debugPrint("📢 Status SOS diperbarui via WebSocket: $payload");

      final rawStatus = (payload['status_sos'] ?? 'belum ditangani').toString().toLowerCase();

      setState(() {
        _sosStatus = rawStatus;
      });

      if (_isDitangani && !_isListeningRelawan) {
        _listenToRelawanLocation(sosId);
      }

      if (_isSelesai || _isBatal) {
        _startSelesaiTimer();
      }
    });

    if (_isDitangani && !_isListeningRelawan) {
      _listenToRelawanLocation(sosId);
    }
  }

  void _listenToRelawanLocation(int sosId) {
    _isListeningRelawan = true;
    WebsocketService.listenToRelawanLocation(sosId, (payload) {
      if (mounted && payload != null) {
        setState(() {
          if (payload['distance'] != null) {
            _relawanDistance = (payload['distance'] as num).toDouble();
          }
        });
      }
    });
  }

  /// Mulai tracking lokasi user secara real-time.
  /// LocationService secara otomatis akan menembak endpoint /api/user/update-location
  /// (yang akan dibroadcast oleh backend via Reverb).
  Future<void> _startLocationTracking() async {
    final hasPermission = await _locationService.requestPermission();
    if (hasPermission) {
      _locationService.startTracking();

      // Listen GPS service changes agar jika user mematikan GPS, kita tangkap
      _serviceStatusStream = Geolocator.getServiceStatusStream().listen((
        status,
      ) {
        if (status == ServiceStatus.enabled) {
          _locationService.startTracking();
        } else {
          _locationService.stopTracking();
        }
      });
    }
  }

  int _emptyPollCount = 0;
  bool _isListeningRelawan = false;

  Future<void> _fetchSosStatus() async {
    try {
      final prefs = sl<SharedPreferences>();
      final token = prefs.getString('auth_token');
      if (token == null) return;

      final response = await sl<Dio>().get(
        ApiConstants.emergencyActive,
        options: Options(
          headers: {
            'Authorization': 'Bearer $token',
            'Accept': 'application/json',
          },
        ),
      );

      if (response.statusCode == 200 && mounted) {
        final data = response.data['data'];
        if (data != null) {
          final rawStatus = (data['status_sos'] ?? 'belum ditangani').toString().toLowerCase();

          setState(() {
            _sosId = data['id'];
            _sosStatus = rawStatus;
            _emptyPollCount = 0; // reset
          });

          if (_sosId != null) {
            _setupWebSocketListeners(_sosId!);
          }

          if (_isDitangani &&
              _sosId != null &&
              !_isListeningRelawan) {
            _listenToRelawanLocation(_sosId!);
          }

          if (_isSelesai || _isBatal) {
            _startSelesaiTimer();
          }
        } else {
          // Give it a 15-second grace period (3 polls) to allow background API to finish
          _emptyPollCount++;
          if (_emptyPollCount > 3) {
            setState(() {
              _sosStatus = 'selesai';
            });
            _startSelesaiTimer();
          }
        }
      }
    } catch (e) {
      debugPrint('Gagal fetch status SOS: $e');
    }
  }

  void _startSelesaiTimer() {
    if (_isSelesaiTimerStarted) return;
    _isSelesaiTimerStarted = true;
    _selesaiTimer = Timer(const Duration(seconds: 10), () {
      if (mounted) {
        context.pop();
      }
    });
  }


  Future<void> _cancelSos() async {
    if (_sosId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Tidak dapat membatalkan: ID SOS tidak ditemukan'),
        ),
      );
      context.pop();
      return;
    }

    try {
      final prefs = sl<SharedPreferences>();
      final token = prefs.getString('auth_token');
      if (token == null) return;

      final response = await sl<Dio>().post(
        ApiConstants.emergencyCancel(_sosId),
        data: {'alasan_batal': 'Dibatalkan oleh pengguna'},
        options: Options(
          headers: {
            'Authorization': 'Bearer $token',
            'Accept': 'application/json',
          },
        ),
      );

      if (response.statusCode == 200 && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('SOS Berhasil Dibatalkan')),
        );
        context.pop();
      }
    } catch (e) {
      debugPrint('Gagal membatalkan SOS: $e');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Gagal membatalkan SOS')));
        context.pop();
      }
    }
  }

  @override
  void dispose() {
    _statusTimer?.cancel();
    _selesaiTimer?.cancel();
    _serviceStatusStream?.cancel();
    _locationService.stopTracking();
    if (_sosId != null) {
      WebsocketService.stopListeningSosStatusUpdate(_sosId!);
      WebsocketService.stopListeningRelawanLocation(_sosId!);
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: const Color(0xFFF5F6F8),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(CupertinoIcons.chevron_left, color: Colors.black87),
          onPressed: () => context.pop(),
        ),
      ),
      body: Container(
        color: const Color(0xFFF5F6F8),
        child: SafeArea(
          child: CustomScrollView(
            slivers: [
              SliverFillRemaining(
                hasScrollBody: false,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0),
                  child: IntrinsicHeight(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const SizedBox(height: 16),

                      // Icon
                      Center(
                        child: Container(
                          width: 120,
                          height: 120,
                          decoration: BoxDecoration(
                            color: _isSelesai
                                ? primaryTeal
                                : (_isDitangani
                                      ? const Color(0xFFF57F17)
                                      : sosRed),
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color:
                                    (_isSelesai
                                            ? primaryTeal
                                            : (_isDitangani
                                                  ? const Color(0xFFF57F17)
                                                  : sosRed))
                                        .withValues(alpha: 0.3),
                                blurRadius: 20,
                                spreadRadius: 5,
                              ),
                            ],
                          ),
                          child: Icon(
                            _isSelesai
                                ? CupertinoIcons.checkmark_circle_fill
                                : (_isDitangani
                                      ? CupertinoIcons.car_detailed
                                      : CupertinoIcons.speaker_3_fill),
                            color: Colors.white,
                            size: 60,
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),

                      Text(
                        _isSelesai
                            ? 'BANTUAN SELESAI'
                            : (_isDitangani
                                  ? 'RELAWAN DALAM PERJALANAN'
                                  : 'SOS SEDANG DIKIRIM'),
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: _isSelesai
                              ? primaryTeal
                              : (_isDitangani
                                    ? const Color(0xFFF57F17)
                                    : sosRed),
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _isSelesai
                            ? 'Panggilan darurat telah ditangani.'
                            : (_isDitangani
                                  ? 'Relawan sedang menuju ke lokasi Anda.'
                                  : 'Bantuan sedang dicari...'),
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.black54,
                          fontSize: 18,
                        ),
                      ),
                      const SizedBox(height: 32),

                      // Card
                      Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.05),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: BackdropFilter(
                            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                            child: Container(
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.4),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.6),
                                  width: 1.5,
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Status Laporan',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.black87,
                                    ),
                                  ),
                                  const SizedBox(height: 20),
                                  _buildStatusItem(
                                    icon: CupertinoIcons.checkmark_circle,
                                    iconColor: const Color(0xFF00695C),
                                    iconBgColor: const Color(0xFFE0F2F1),
                                    title: 'Lokasi terkirim',
                                    description:
                                        'Koordinat GPS Anda telah diterima oleh sistem.',
                                  ),
                                  const SizedBox(height: 20),
                                  _buildStatusItem(
                                    icon: (_isDitangani || _isSelesai)
                                        ? CupertinoIcons.checkmark_circle
                                        : CupertinoIcons.refresh,
                                    iconColor: (_isDitangani || _isSelesai)
                                        ? const Color(0xFF00695C)
                                        : const Color(0xFFF57F17),
                                    iconBgColor: (_isDitangani || _isSelesai)
                                        ? const Color(0xFFE0F2F1)
                                        : const Color(0xFFFFF9C4),
                                    title: (_isDitangani || _isSelesai)
                                        ? 'Relawan Menuju Lokasi'
                                        : 'Mencari Relawan',
                                    description: _isDitangani
                                        ? (_relawanDistance != null
                                              ? 'Relawan berjarak ${_relawanDistance!.toStringAsFixed(0)} meter dari Anda.'
                                              : 'Relawan telah menerima panggilan dan sedang dalam perjalanan.')
                                        : (_isSelesai
                                              ? 'Relawan telah tiba.'
                                              : 'Sistem sedang mencari relawan terdekat.'),
                                  ),
                                  const SizedBox(height: 20),
                                  _buildStatusItem(
                                    icon: _isSelesai
                                        ? CupertinoIcons.checkmark_circle
                                        : CupertinoIcons.ellipsis,
                                    iconColor: _isSelesai
                                        ? const Color(0xFF00695C)
                                        : Colors.grey.shade700,
                                    iconBgColor: _isSelesai
                                        ? const Color(0xFFE0F2F1)
                                        : Colors.grey.shade200,
                                    title: 'Bantuan Selesai',
                                    description: _isSelesai
                                        ? 'Bantuan telah tiba dan selesai.'
                                        : 'Menunggu relawan tiba.',
                                    isFaded: !_isSelesai,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),

                      const Spacer(),

                      // Lihat Riwayat Aktivitas Button
                      if (_sosId != null)
                        OutlinedButton.icon(
                          onPressed: () {
                            SosActivitiesSheet.show(context, _sosId!);
                          },
                          icon: const Icon(
                            CupertinoIcons.clock,
                            color: primaryTeal,
                          ),
                          label: const Text(
                            'Lihat Riwayat Aktivitas',
                            style: TextStyle(
                              color: primaryTeal,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: primaryTeal),
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            minimumSize: const Size(double.infinity, 50),
                          ),
                        ),
                      const SizedBox(height: 12),

                      // Hubungi Customer Services Button
                      ElevatedButton.icon(
                        onPressed: () {},
                        icon: const Icon(
                          CupertinoIcons.headphones,
                          color: Colors.white,
                        ),
                        label: const Text(
                          'Hubungi Customer Services',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryTeal,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      if (_isSelesai)
                        ElevatedButton(
                          onPressed: () => context.pop(),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: primaryTeal,
                            minimumSize: const Size(double.infinity, 56),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text(
                            'Selesai',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        )
                      else ...[
                        // Slide to Cancel SOS Button
                        SlideToCancelButton(
                          onCancelled: _cancelSos,
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'Geser ke kanan untuk membatalkan keadaan darurat.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.black45, fontSize: 12),
                        ),
                      ],
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
            ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusItem({
    required IconData icon,
    required Color iconColor,
    required Color iconBgColor,
    required String title,
    required String description,
    bool isFaded = false,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(color: iconBgColor, shape: BoxShape.circle),
          child: Icon(icon, color: iconColor, size: 24),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: isFaded ? Colors.black54 : Colors.black87,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                description,
                style: TextStyle(
                  fontSize: 14,
                  color: isFaded ? Colors.black38 : Colors.black54,
                  height: 1.3,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
