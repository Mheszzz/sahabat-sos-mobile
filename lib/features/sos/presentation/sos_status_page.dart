import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:sahabat_sos_mobile/core/di/injection.dart';
import 'package:sahabat_sos_mobile/core/services/location_service.dart';
import 'package:sahabat_sos_mobile/core/services/accessibility_service.dart';
import 'package:sahabat_sos_mobile/core/services/websocket_service.dart';
import 'package:sahabat_sos_mobile/core/theme/accessible_colors.dart';
import 'package:sahabat_sos_mobile/features/sos/data/datasources/sos_remote_data_source.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'widgets/slide_to_cancel_button.dart';

class SosStatusPage extends StatefulWidget {
  const SosStatusPage({super.key});

  @override
  State<SosStatusPage> createState() => _SosStatusPageState();
}

class _SosStatusPageState extends State<SosStatusPage>
    with SingleTickerProviderStateMixin {
  static const Color primaryTeal = Color(0xFF00695C);
  static const Color sosRed = Color(0xFFDC2626);
  static const Color warningOrange = Color(0xFFD97706);
  static const Color bgSurface = Color(0xFFF5F6F8);

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
  final SosRemoteDataSource _sosRemoteDataSource = sl<SosRemoteDataSource>();
  StreamSubscription<ServiceStatus>? _serviceStatusStream;

  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  int _emptyPollCount = 0;
  bool _isListeningRelawan = false;
  bool _isSubscribedToSos = false;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.08).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _fetchSosStatus();
    _initWebSocket();

    // Polling fallback every 4 seconds in case WebSocket drops
    _statusTimer = Timer.periodic(
      const Duration(seconds: 4),
      (_) => _fetchSosStatus(),
    );

    // Continuous location tracking to broadcast user GPS to volunteer
    _startLocationTracking();
  }

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
    if (_isSubscribedToSos || WebsocketService.echo == null) return;
    _isSubscribedToSos = true;

    WebsocketService.listenToSosStatusUpdate(sosId, (payload) {
      if (!mounted || payload == null) return;

      final rawStatus = (payload['status_sos'] ?? 'belum ditangani')
          .toString()
          .toLowerCase();

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
      if (mounted && payload != null && payload['distance'] != null) {
        setState(() {
          _relawanDistance = (payload['distance'] as num).toDouble();
        });
      }
    });
  }

  Future<void> _startLocationTracking() async {
    final hasPermission = await _locationService.requestPermission();
    if (hasPermission) {
      _locationService.startTracking();

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

  Future<void> _fetchSosStatus() async {
    try {
      final data = await _sosRemoteDataSource.getActiveEmergency();

      if (!mounted) return;

      if (data != null) {
        final rawStatus = (data['status_sos'] ?? 'belum ditangani')
            .toString()
            .toLowerCase();

        setState(() {
          _sosId = data['id'];
          _sosStatus = rawStatus;
          _emptyPollCount = 0;
        });

        if (_sosId != null) {
          _setupWebSocketListeners(_sosId!);
        }

        if (_isDitangani && _sosId != null && !_isListeningRelawan) {
          _listenToRelawanLocation(_sosId!);
        }

        if (_isSelesai || _isBatal) {
          _startSelesaiTimer();
        }
      } else {
        // 15-second grace period (3 polls) for async backend processing
        _emptyPollCount++;
        if (_emptyPollCount > 3) {
          setState(() {
            _sosStatus = 'selesai';
          });
          _startSelesaiTimer();
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
      final success = await _sosRemoteDataSource.cancelEmergency(
        _sosId!,
        reason: 'Dibatalkan oleh pengguna',
      );

      if (mounted) {
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Sinyal SOS berhasil dibatalkan.')),
          );
        }
        context.pop();
      }
    } catch (e) {
      debugPrint('Gagal membatalkan SOS: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Gagal membatalkan SOS')),
        );
        context.pop();
      }
    }
  }

  Future<void> _callNumber(String phone) async {
    final clean = phone.replaceAll(RegExp(r'[^0-9+]'), '');
    final uri = Uri.parse('tel:$clean');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Tidak dapat memanggil nomor $phone')),
      );
    }
  }

  void _showEmergencyHotlinesModal(bool isHighContrast) {
    showModalBottomSheet(
      context: context,
      backgroundColor: isHighContrast ? const Color(0xFF1E1E1E) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: isHighContrast
                          ? const Color(0xFF4B5563)
                          : Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Kontak Darurat Nasional',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AccessibleColors.textPrimary(isHighContrast),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Hubungi layanan darurat resmi jika membutuhkan pertolongan cepat.',
                  style: TextStyle(
                    fontSize: 13,
                    color: AccessibleColors.textSecondary(isHighContrast),
                  ),
                ),
                const SizedBox(height: 16),
                _buildHotlineTile(
                  title: '112 - Panggilan Darurat Nasional',
                  subtitle: 'Layanan Terpadu Bebas Pulsa (Semua Keadaan Darurat)',
                  phone: '112',
                  icon: CupertinoIcons.phone_fill,
                  color: sosRed,
                  isHighContrast: isHighContrast,
                ),
                const SizedBox(height: 8),
                _buildHotlineTile(
                  title: '110 - Kepolisian Republik Indonesia',
                  subtitle: 'Keamanan, Kriminalitas, dan Gangguan Ketertiban',
                  phone: '110',
                  icon: CupertinoIcons.shield_fill,
                  color: isHighContrast
                      ? const Color(0xFF60A5FA)
                      : const Color(0xFF1E3A8A),
                  isHighContrast: isHighContrast,
                ),
                const SizedBox(height: 8),
                _buildHotlineTile(
                  title: '119 - Layanan Ambulans / Medis',
                  subtitle: 'Pertolongan Medis Gawat Darurat',
                  phone: '119',
                  icon: CupertinoIcons.heart_fill,
                  color: const Color(0xFFDC2626),
                  isHighContrast: isHighContrast,
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildHotlineTile({
    required String title,
    required String subtitle,
    required String phone,
    required IconData icon,
    required Color color,
    required bool isHighContrast,
  }) {
    final tileBg = isHighContrast ? const Color(0xFF2D3748) : bgSurface;
    final tealColor = isHighContrast ? const Color(0xFF80CBC4) : primaryTeal;

    return Material(
      color: tileBg,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          Navigator.pop(context);
          _callNumber(phone);
        },
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: isHighContrast ? 0.2 : 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: AccessibleColors.textPrimary(isHighContrast),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 11,
                        color: AccessibleColors.textSecondary(isHighContrast),
                      ),
                    ),
                  ],
                ),
              ),
              Icon(CupertinoIcons.phone, color: tealColor, size: 20),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
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

  Color get _statusColor {
    if (_isSelesai) return primaryTeal;
    if (_isDitangani) return warningOrange;
    return sosRed;
  }

  String get _statusHeaderTitle {
    if (_isSelesai) return 'BANTUAN SELESAI';
    if (_isDitangani) return 'RELAWAN DALAM PERJALANAN';
    return 'MENUNGGU RELAWAN';
  }

  String get _statusHeaderSubtitle {
    if (_isSelesai) return 'Panggilan darurat Anda telah selesai ditangani.';
    if (_isDitangani) {
      if (_relawanDistance != null) {
        return 'Relawan sedang menuju ke lokasi Anda (jarak ~${_relawanDistance!.toStringAsFixed(0)} m).';
      }
      return 'Relawan sedang bergerak menuju lokasi Anda.';
    }
    return 'Menunggu relawan terdekat menerima panggilan darurat...';
  }

  IconData get _statusHeaderIcon {
    if (_isSelesai) return CupertinoIcons.checkmark_circle_fill;
    if (_isDitangani) return CupertinoIcons.car_detailed;
    return CupertinoIcons.speaker_3_fill;
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
        final tealColor =
            isHighContrast ? const Color(0xFF80CBC4) : primaryTeal;

        return Scaffold(
          backgroundColor: currentBg,
          appBar: AppBar(
            backgroundColor: currentBg,
            elevation: 0,
            scrolledUnderElevation: 0,
            iconTheme: IconThemeData(color: tealColor),
            leading: IconButton(
              icon: Icon(CupertinoIcons.back, color: tealColor),
              onPressed: () => context.pop(),
            ),
            centerTitle: false,
            titleSpacing: 0,
            title: Row(
              children: [
                Image.asset('assets/images/logo.png', width: 24, height: 24),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Status Keadaan Darurat',
                    style: TextStyle(
                      color: tealColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          body: SafeArea(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding:
                  const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (AccessibilityService.instance.isVisualAlertEnabled &&
                      !_isSelesai) ...[
                    Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: isHighContrast
                            ? const Color(0xFF3B1010)
                            : const Color(0xFFFEF2F2),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color: const Color(0xFFEF4444), width: 1.5),
                      ),
                      child: Row(
                        children: [
                          const Icon(CupertinoIcons.lightbulb_fill,
                              color: Color(0xFFDC2626), size: 20),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'PERINGATAN VISUAL: Sinyal darurat SOS aktif & sedang disiarkan ke relawan terdekat.',
                              style: TextStyle(
                                color: isHighContrast
                                    ? Colors.white
                                    : const Color(0xFF991B1B),
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                                height: 1.35,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  Center(
                    child: AnimatedBuilder(
                      animation: _pulseAnimation,
                      builder: (context, child) {
                        final scale =
                            (!_isSelesai) ? _pulseAnimation.value : 1.0;
                        return Transform.scale(
                          scale: scale,
                          child: Container(
                            width: 110,
                            height: 110,
                            decoration: BoxDecoration(
                              color: _statusColor,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: _statusColor.withValues(alpha: 0.35),
                                  blurRadius: 24,
                                  spreadRadius: 4,
                                ),
                              ],
                            ),
                            child: Icon(
                              _statusHeaderIcon,
                              color: Colors.white,
                              size: 52,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    _statusHeaderTitle,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: _statusColor,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _statusHeaderSubtitle,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AccessibleColors.textSecondary(isHighContrast),
                      fontSize: 14,
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: 28),
                  _buildTimelineCard(isHighContrast),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    onPressed: () =>
                        _showEmergencyHotlinesModal(isHighContrast),
                    icon: const Icon(CupertinoIcons.headphones,
                        color: Colors.white, size: 18),
                    label: const Text(
                      'Hubungi Layanan Darurat',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryTeal,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      minimumSize: const Size(double.infinity, 48),
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (_isSelesai)
                    ElevatedButton(
                      onPressed: () => context.pop(),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryTeal,
                        elevation: 0,
                        minimumSize: const Size(double.infinity, 50),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: const Text(
                        'Selesai',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    )
                  else ...[
                    SlideToCancelButton(
                      onCancelled: _cancelSos,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Geser ke kanan untuk membatalkan keadaan darurat.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: AccessibleColors.textSecondary(isHighContrast),
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildTimelineCard(bool isHighContrast) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AccessibleColors.cardBackground(isHighContrast),
        borderRadius: BorderRadius.circular(16),
        border: AccessibleColors.cardBorder(isHighContrast),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(
              alpha: isHighContrast ? 0.3 : 0.04,
            ),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Alur Penanganan Darurat',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: AccessibleColors.textPrimary(isHighContrast),
            ),
          ),
          const SizedBox(height: 20),
          _buildTimelineStep(
            icon: CupertinoIcons.checkmark_alt,
            isCompleted: true,
            isActive: false,
            title: 'Sinyal & Lokasi Terkirim',
            description: 'Koordinat GPS Anda telah diterima oleh sistem server.',
            showConnector: true,
            isHighContrast: isHighContrast,
          ),
          _buildTimelineStep(
            icon: (_isDitangani || _isSelesai)
                ? CupertinoIcons.checkmark_alt
                : CupertinoIcons.refresh,
            isCompleted: _isSelesai,
            isActive: _isDitangani,
            title: (_isDitangani || _isSelesai)
                ? 'Relawan Menuju Lokasi'
                : 'Mencari Relawan Terdekat',
            description: _isDitangani
                ? (_relawanDistance != null
                    ? 'Relawan telah menerima panggilan dan berjarak ${_relawanDistance!.toStringAsFixed(0)} m.'
                    : 'Relawan telah menerima panggilan dan sedang dalam perjalanan.')
                : (_isSelesai
                    ? 'Relawan telah tiba di lokasi kejadian.'
                    : 'Sistem sedang mencarikan relawan terdekat.'),
            showConnector: true,
            isHighContrast: isHighContrast,
          ),
          _buildTimelineStep(
            icon: _isSelesai
                ? CupertinoIcons.checkmark_alt
                : CupertinoIcons.flag,
            isCompleted: _isSelesai,
            isActive: false,
            title: 'Bantuan Selesai',
            description: _isSelesai
                ? 'Proses penanganan darurat telah tuntas.'
                : 'Menunggu penanganan selesai oleh relawan/tim medis.',
            showConnector: false,
            isHighContrast: isHighContrast,
          ),
        ],
      ),
    );
  }

  Widget _buildTimelineStep({
    required IconData icon,
    required bool isCompleted,
    required bool isActive,
    required String title,
    required String description,
    required bool showConnector,
    required bool isHighContrast,
  }) {
    Color stepColor;
    Color stepBgColor;

    if (isCompleted) {
      stepColor = isHighContrast ? const Color(0xFF80CBC4) : primaryTeal;
      stepBgColor = isHighContrast
          ? const Color(0xFF004D40)
          : const Color(0xFFE0F2F1);
    } else if (isActive) {
      stepColor = warningOrange;
      stepBgColor = isHighContrast
          ? const Color(0xFF78350F)
          : const Color(0xFFFEF3C7);
    } else {
      stepColor = const Color(0xFF9CA3AF);
      stepBgColor = isHighContrast
          ? const Color(0xFF374151)
          : const Color(0xFFF3F4F6);
    }

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: stepBgColor,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: stepColor.withValues(alpha: 0.5),
                    width: 1.5,
                  ),
                ),
                child: Icon(icon, color: stepColor, size: 16),
              ),
              if (showConnector)
                Expanded(
                  child: Container(
                    width: 2,
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    color: isCompleted
                        ? (isHighContrast
                            ? const Color(0xFF80CBC4)
                            : primaryTeal.withValues(alpha: 0.4))
                        : (isHighContrast
                            ? const Color(0xFF4B5563)
                            : const Color(0xFFE5E7EB)),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: showConnector ? 20.0 : 4.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: (isCompleted || isActive)
                          ? AccessibleColors.textPrimary(isHighContrast)
                          : AccessibleColors.textSecondary(isHighContrast),
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    description,
                    style: TextStyle(
                      fontSize: 13,
                      color: AccessibleColors.textSecondary(isHighContrast),
                      height: 1.35,
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
}
