import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:dio/dio.dart';
import 'package:go_router/go_router.dart';
import 'package:geolocator/geolocator.dart';
import 'package:sahabat_sos_mobile/core/di/injection.dart';
import 'package:sahabat_sos_mobile/core/services/location_service.dart';
import 'package:sahabat_sos_mobile/core/utils/device_info_helper.dart';
import 'package:sahabat_sos_mobile/core/utils/global_event_bus.dart';
import 'package:sahabat_sos_mobile/core/widgets/app_loading_indicator.dart';
import 'package:sahabat_sos_mobile/features/dashboard/data/datasources/dashboard_remote_data_source.dart';
import 'package:sahabat_sos_mobile/features/tuya_device/data/services/tuya_channel_service.dart';
import 'package:sahabat_sos_mobile/features/tuya_device/data/models/tuya_device_model.dart';
import 'package:sahabat_sos_mobile/routing/routes.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage>
    with SingleTickerProviderStateMixin {
  static const Color primaryTeal = Color(0xFF00695C);
  static const Color sosRed = Color(0xFFDC2626);
  static const Color bgSurface = Color(0xFFF5F6F8);
  static const Color cardBorder = Color(0xFFE5E7EB);

  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  int _tapCount = 0;
  Timer? _tapTimer;

  String _userName = '';
  bool _isBerandaLoading = true;
  TuyaDeviceModel? _tuyaDevice;
  StreamSubscription? _deviceSubscription;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.92).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    _fetchBeranda();

    final tuyaService = sl<TuyaChannelService>();
    _deviceSubscription = tuyaService.dpEventStream.listen((event) {
      if (mounted &&
          _tuyaDevice != null &&
          event.deviceId == _tuyaDevice!.deviceId) {
        setState(() {
          final newDps = Map<String, dynamic>.from(_tuyaDevice!.dps)
            ..addAll(event.dps);
          _tuyaDevice = _tuyaDevice!.copyWith(dps: newDps);
        });
      }
    });
  }

  Future<void> _fetchBeranda() async {
    try {
      final dashboardSource = sl<DashboardRemoteDataSource>();
      final data = await dashboardSource.getBerandaData();

      final tuyaService = sl<TuyaChannelService>();
      var devices = await tuyaService.getDeviceList();

      if (devices.isEmpty) {
        try {
          await tuyaService.initTuya();
          devices = await tuyaService.getDeviceList();
        } catch (_) {}
      }

      if (mounted) {
        setState(() {
          _userName = data['user']?['name'] ?? '';
          if (devices.isNotEmpty) {
            _tuyaDevice = devices.first;
          }
          _isBerandaLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Gagal fetch beranda: $e');
      if (mounted) {
        setState(() => _isBerandaLoading = false);
      }
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    _tapTimer?.cancel();
    _deviceSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isBerandaLoading) {
      return const AppLoadingScreen();
    }

    return Scaffold(
      backgroundColor: bgSurface,
      appBar: _buildAppBar(context),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 12),
              Expanded(
                flex: 10,
                child: _buildSosButton(),
              ),
              const SizedBox(height: 8),
              const Text(
                'Tekan tombol 5 kali dengan cepat\nuntuk meminta bantuan.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  color: Color(0xFF4B5563),
                  fontWeight: FontWeight.w500,
                  height: 1.35,
                ),
              ),
              const Spacer(flex: 1),
              _buildDeviceStatusCard(),
              const SizedBox(height: 12),
              _buildMenuGrid(),
              // Space for floating bottom navigation bar
              const SizedBox(height: 120),
            ],
          ),
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(BuildContext context) {
    return AppBar(
      backgroundColor: bgSurface,
      elevation: 0,
      scrolledUnderElevation: 0,
      iconTheme: const IconThemeData(color: primaryTeal),
      centerTitle: false,
      titleSpacing: 16,
      title: Row(
        children: [
          Image.asset('assets/images/logo.png', width: 24, height: 24),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _userName.isNotEmpty ? 'Halo, $_userName' : 'Sahabat SOS',
              style: const TextStyle(
                color: primaryTeal,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
      actions: [
        IconButton(
          icon: const Icon(CupertinoIcons.refresh, color: primaryTeal),
          tooltip: 'Refresh',
          onPressed: () {
            setState(() => _isBerandaLoading = true);
            _fetchBeranda();
          },
        ),
        Padding(
          padding: const EdgeInsets.only(right: 12.0),
          child: Tooltip(
            message: 'Lihat Peta',
            child: Material(
              color: primaryTeal.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(8),
              child: InkWell(
                onTap: () => context.push('/map'),
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: primaryTeal.withValues(alpha: 0.25),
                      width: 1,
                    ),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(CupertinoIcons.map, color: primaryTeal, size: 16),
                      SizedBox(width: 4),
                      Text(
                        'Peta',
                        style: TextStyle(
                          color: primaryTeal,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSosButton() {
    return Center(
      child: Listener(
        onPointerDown: (_) => _animationController.forward(),
        onPointerUp: (_) => _animationController.reverse(),
        onPointerCancel: (_) => _animationController.reverse(),
        child: GestureDetector(
          onTap: _handleSosTap,
          child: ScaleTransition(
            scale: _scaleAnimation,
            child: FittedBox(
              fit: BoxFit.contain,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Container(
                  width: 300,
                  height: 300,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const RadialGradient(
                      center: Alignment(-0.25, -0.35),
                      radius: 0.85,
                      colors: [
                        Color(0xFFEF4444),
                        sosRed,
                        Color(0xFFB91C1C),
                      ],
                    ),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.35),
                      width: 4,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFB91C1C).withValues(alpha: 0.4),
                        blurRadius: 24,
                        offset: const Offset(0, 10),
                      ),
                      BoxShadow(
                        color: sosRed.withValues(alpha: 0.2),
                        blurRadius: 36,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: const Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        CupertinoIcons.exclamationmark_triangle_fill,
                        color: Colors.white,
                        size: 72,
                        shadows: [
                          Shadow(
                            color: Colors.black26,
                            offset: Offset(0, 2),
                            blurRadius: 4,
                          ),
                        ],
                      ),
                      SizedBox(height: 12),
                      Text(
                        'SOS',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 42,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 2.0,
                          shadows: [
                            Shadow(
                              color: Colors.black26,
                              offset: Offset(0, 2),
                              blurRadius: 4,
                            ),
                          ],
                        ),
                      ),
                      Text(
                        'DARURAT',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.8,
                          shadows: [
                            Shadow(
                              color: Colors.black26,
                              offset: Offset(0, 2),
                              blurRadius: 4,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // 5 taps within 2 seconds are required to prevent accidental triggers
  void _handleSosTap() async {
    _tapCount++;
    if (_tapCount >= 5) {
      _tapCount = 0;
      await _executeEmergencySos();
    }

    _tapTimer?.cancel();
    _tapTimer = Timer(const Duration(seconds: 2), () {
      _tapCount = 0;
    });
  }

  Future<void> _executeEmergencySos() async {
    unawaited(
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) =>
            const Center(child: CupertinoActivityIndicator(radius: 16)),
      ),
    );

    final locationService = sl<LocationService>();
    final hasPermission = await locationService.requestPermission();
    if (!hasPermission) {
      if (!mounted) return;
      Navigator.of(context, rootNavigator: true).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Izin lokasi dibutuhkan untuk mengirim sinyal SOS.'),
        ),
      );
      return;
    }

    // Geolocation fallback hierarchy: cached -> lastKnown -> quick getCurrent -> default
    double latitude = 0.0;
    double longitude = 0.0;

    try {
      final cachedPos = locationService.currentPosition.value;
      if (cachedPos != null && cachedPos.latitude != 0.0) {
        latitude = cachedPos.latitude;
        longitude = cachedPos.longitude;
      } else {
        final lastPos = await Geolocator.getLastKnownPosition();
        if (lastPos != null && lastPos.latitude != 0.0) {
          latitude = lastPos.latitude;
          longitude = lastPos.longitude;
        } else {
          final pos = await Geolocator.getCurrentPosition(
            locationSettings: const LocationSettings(
              accuracy: LocationAccuracy.medium,
            ),
          ).timeout(const Duration(seconds: 5));
          latitude = pos.latitude;
          longitude = pos.longitude;
        }
      }
    } catch (_) {
      try {
        final fallbackPos = await Geolocator.getLastKnownPosition();
        if (fallbackPos != null) {
          latitude = fallbackPos.latitude;
          longitude = fallbackPos.longitude;
        }
      } catch (_) {}
    }

    final telemetryData = await DeviceInfoHelper.getSosTelemetryData();

    Map<String, dynamic>? tuyaDeviceInfo;
    if (_tuyaDevice != null) {
      tuyaDeviceInfo = {
        'device_id': _tuyaDevice!.deviceId,
        'device_name': _tuyaDevice!.name,
        'product_id': _tuyaDevice!.productId,
        'is_online': _tuyaDevice!.isOnline,
        'battery_level': _tuyaDevice!.batteryLevel,
        'signal_strength': _tuyaDevice!.signalStrengthFormatted,
        'trigger_type': 'Tombol Aplikasi Layar',
        'last_seen': _tuyaDevice!.lastEventAt?.toIso8601String() ??
            DateTime.now().toIso8601String(),
        'location_updated_at': DateTime.now().toIso8601String(),
      };
    }

    try {
      final dashboardSource = sl<DashboardRemoteDataSource>();
      await dashboardSource.triggerEmergency(
        latitude: latitude,
        longitude: longitude,
        address: locationService.lastGeocodedAddress,
        telemetryData: telemetryData,
        tuyaDeviceInfo: tuyaDeviceInfo,
      );

      if (!mounted) return;
      Navigator.of(context, rootNavigator: true).pop();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sinyal SOS darurat berhasil dikirim.')),
      );
      unawaited(context.push(AppRoutes.sosStatus));
    } catch (e) {
      if (!mounted) return;
      Navigator.of(context, rootNavigator: true).pop();

      if (e is DioException && e.response?.statusCode == 422) {
        final message =
            e.response?.data['message'] ?? 'Sinyal SOS darurat masih aktif';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message.toString())),
        );
        unawaited(context.push(AppRoutes.sosStatus));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal mengirim SOS: $e')),
        );
      }
    }
  }

  Widget _buildDeviceStatusCard() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cardBorder, width: 1.0),
        boxShadow: const [
          BoxShadow(
            color: Color(0x08000000),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: _isBerandaLoading
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(8.0),
                child: CupertinoActivityIndicator(radius: 12),
              ),
            )
          : Row(
              children: [
                _buildStatItem(
                  icon: CupertinoIcons.battery_100,
                  label: 'Baterai',
                  value: _tuyaDevice?.batteryLevel != null
                      ? '${_tuyaDevice!.batteryLevel}%'
                      : 'N/A',
                  color: const Color(0xFF16A34A),
                ),
                Container(
                  width: 1,
                  height: 38,
                  color: cardBorder,
                ),
                _buildStatItem(
                  icon: CupertinoIcons.wifi,
                  label: 'Koneksi',
                  value: _tuyaDevice != null
                      ? (_tuyaDevice!.isOnline ? 'Terhubung' : 'Terputus')
                      : 'N/A',
                  color: primaryTeal,
                ),
                Container(
                  width: 1,
                  height: 38,
                  color: cardBorder,
                ),
                _buildStatItem(
                  icon: CupertinoIcons.antenna_radiowaves_left_right,
                  label: 'Sinyal',
                  value: _tuyaDevice?.signalStrengthFormatted ?? 'N/A',
                  color: const Color(0xFF2563EB),
                ),
              ],
            ),
    );
  }

  Widget _buildStatItem({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Expanded(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 16),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: color,
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: Color(0xFF6B7280),
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildMenuGrid() {
    final items = [
      _MenuItemData(
        icon: CupertinoIcons.exclamationmark_bubble,
        label: 'Kirim Laporan',
        route: AppRoutes.quickReport,
      ),
      _MenuItemData(
        icon: CupertinoIcons.antenna_radiowaves_left_right,
        label: 'Perangkat Saya',
        route: AppRoutes.tuyaDevices,
      ),
      _MenuItemData(
        icon: CupertinoIcons.phone,
        label: 'Kontak Darurat',
        route: AppRoutes.emergencyContacts,
      ),
      _MenuItemData(
        icon: CupertinoIcons.clock,
        label: 'Riwayat Bantuan',
        onTap: () {
          GlobalEventBus.changeUserTab.value = 3;
        },
      ),
    ];

    return Column(
      children: [
        Row(
          children: [
            Expanded(child: _buildMenuCard(items[0])),
            const SizedBox(width: 10),
            Expanded(child: _buildMenuCard(items[1])),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(child: _buildMenuCard(items[2])),
            const SizedBox(width: 10),
            Expanded(child: _buildMenuCard(items[3])),
          ],
        ),
      ],
    );
  }

  Widget _buildMenuCard(_MenuItemData item) {
    return Container(
      height: 72,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cardBorder, width: 1.0),
        boxShadow: const [
          BoxShadow(
            color: Color(0x06000000),
            blurRadius: 6,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            if (item.onTap != null) {
              item.onTap!();
            } else if (item.route != null) {
              context.push(item.route!);
            }
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(item.icon, color: primaryTeal, size: 28),
                const SizedBox(height: 6),
                Text(
                  item.label,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                    color: Color(0xFF1F2937),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MenuItemData {
  final IconData icon;
  final String label;
  final String? route;
  final VoidCallback? onTap;

  _MenuItemData({
    required this.icon,
    required this.label,
    this.route,
    this.onTap,
  });
}
