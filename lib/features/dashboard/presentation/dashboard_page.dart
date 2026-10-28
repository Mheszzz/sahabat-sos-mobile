import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:dio/dio.dart';
import 'package:go_router/go_router.dart';
import 'package:geolocator/geolocator.dart';
import 'package:sahabat_sos_mobile/core/di/injection.dart';
import 'package:sahabat_sos_mobile/core/services/location_service.dart';
import 'package:sahabat_sos_mobile/core/services/accessibility_service.dart';
import 'package:sahabat_sos_mobile/core/theme/accessible_colors.dart';
import 'package:sahabat_sos_mobile/core/utils/device_info_helper.dart';
import 'package:sahabat_sos_mobile/core/utils/global_event_bus.dart';
import 'package:sahabat_sos_mobile/core/widgets/app_loading_indicator.dart';
import 'package:sahabat_sos_mobile/features/dashboard/data/datasources/dashboard_remote_data_source.dart';
import 'package:sahabat_sos_mobile/features/tuya_device/data/services/tuya_channel_service.dart';
import 'package:sahabat_sos_mobile/features/tuya_device/data/models/tuya_device_model.dart';
import 'package:sahabat_sos_mobile/core/services/health_connect_service.dart';
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

    return ListenableBuilder(
      listenable: AccessibilityService.instance,
      builder: (context, _) {
        final isHighContrast =
            AccessibilityService.instance.isHighContrastEnabled ||
            Theme.of(context).brightness == Brightness.dark ||
            MediaQuery.of(context).highContrast;
        final currentBg = isHighContrast ? Colors.black : bgSurface;
        final currentPrimaryTeal =
            isHighContrast ? const Color(0xFF80CBC4) : primaryTeal;

        return Scaffold(
          backgroundColor: currentBg,
          appBar: _buildAppBar(context, isHighContrast, currentPrimaryTeal),
          body: SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final sosHeight =
                    (constraints.maxHeight * 0.36).clamp(180.0, 300.0);
                return SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: ConstrainedBox(
                    constraints:
                        BoxConstraints(minHeight: constraints.maxHeight),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const SizedBox(height: 12),
                        SizedBox(
                          height: sosHeight,
                          child: _buildSosButton(),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Tekan tombol 5 kali dengan cepat\nuntuk meminta bantuan.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 13,
                            color: isHighContrast
                                ? const Color(0xFFD1D5DB)
                                : const Color(0xFF4B5563),
                            fontWeight: FontWeight.w500,
                            height: 1.35,
                          ),
                        ),
                        const SizedBox(height: 14),
                        _buildHeartRateBanner(isHighContrast),
                        _buildDeviceStatusCard(isHighContrast),
                        const SizedBox(height: 12),
                        _buildMenuGrid(isHighContrast),
                        // Space for floating bottom navigation bar
                        SizedBox(
                          height: MediaQuery.of(context).padding.bottom + 100,
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }

  PreferredSizeWidget _buildAppBar(
    BuildContext context,
    bool isHighContrast,
    Color currentPrimaryTeal,
  ) {
    return AppBar(
      backgroundColor: isHighContrast ? Colors.black : bgSurface,
      elevation: 0,
      scrolledUnderElevation: 0,
      iconTheme: IconThemeData(color: currentPrimaryTeal),
      centerTitle: false,
      titleSpacing: 16,
      title: Row(
        children: [
          Image.asset('assets/images/logo.png', width: 24, height: 24),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _userName.isNotEmpty ? 'Halo, $_userName' : 'Sahabat SOS',
              style: TextStyle(
                color: currentPrimaryTeal,
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
          icon: Icon(CupertinoIcons.refresh, color: currentPrimaryTeal),
          tooltip: 'Refresh',
          onPressed: () {
            AccessibilityService.instance.handleTalkbackTap(
              id: 'dashboard_refresh_btn',
              speakText: "Memperbarui data beranda",
              hintText: "Tekan sekali lagi untuk memperbarui data.",
              onAction: () {
                setState(() => _isBerandaLoading = true);
                _fetchBeranda();
              },
            );
          },
        ),
        Padding(
          padding: const EdgeInsets.only(right: 12.0),
          child: Tooltip(
            message: 'Lihat Peta',
            child: Material(
              color: isHighContrast
                  ? const Color(0xFF1E2430)
                  : currentPrimaryTeal.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(8),
              child: InkWell(
                onTap: () {
                  AccessibilityService.instance.handleTalkbackTap(
                    id: 'dashboard_map_btn',
                    speakText: "Membuka Peta",
                    hintText: "Tekan sekali lagi untuk membuka peta.",
                    onAction: () => context.push(AppRoutes.map),
                  );
                },
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isHighContrast
                          ? const Color(0xFF4B5563)
                          : currentPrimaryTeal.withValues(alpha: 0.25),
                      width: isHighContrast ? 1.5 : 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(CupertinoIcons.map,
                          color: currentPrimaryTeal, size: 16),
                      const SizedBox(width: 4),
                      Text(
                        'Peta',
                        style: TextStyle(
                          color: currentPrimaryTeal,
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
      child: Semantics(
        label:
            'Tombol Darurat SOS. Tekan dan tahan atau ketuk lima kali dengan cepat untuk memicu bantuan darurat.',
        button: true,
        child: Listener(
          onPointerDown: (_) => _animationController.forward(),
          onPointerUp: (_) => _animationController.reverse(),
          onPointerCancel: (_) => _animationController.reverse(),
          child: GestureDetector(
            onTap: _handleSosTap,
            onLongPress: _handleSosLongPress,
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
    ),
  );
}

  // 5 taps within 2 seconds are required to prevent accidental triggers
  void _handleSosTap() async {
    _tapCount++;
    if (_tapCount >= 5) {
      _tapCount = 0;
      AccessibilityService.instance.hapticHeavy();
      unawaited(
        AccessibilityService.instance.speak("Sinyal darurat SOS diaktifkan!"),
      );
      await _executeEmergencySos();
    } else {
      AccessibilityService.instance.hapticMedium();
      unawaited(
        AccessibilityService.instance.speak("Ketukan $_tapCount"),
      );
    }

    _tapTimer?.cancel();
    _tapTimer = Timer(const Duration(seconds: 2), () {
      _tapCount = 0;
    });
  }

  // Alternatif aksesibilitas: Tekan tahan tombol SOS untuk memicu darurat langsung
  void _handleSosLongPress() async {
    _tapTimer?.cancel();
    _tapCount = 0;
    AccessibilityService.instance.hapticHeavy();
    unawaited(
      AccessibilityService.instance.speak("Sinyal darurat SOS diaktifkan melalui tekan tahan!"),
    );
    await _executeEmergencySos();
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
    bool hasPermission = false;
    try {
      hasPermission = await locationService.requestPermission();
    } catch (_) {}

    // Geolocation fallback hierarchy: cached -> lastKnown -> quick getCurrent -> default (0.0)
    double latitude = 0.0;
    double longitude = 0.0;

    if (hasPermission) {
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
            ).timeout(const Duration(seconds: 4));
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
      final newSosId = await dashboardSource.triggerEmergency(
        latitude: latitude,
        longitude: longitude,
        address: locationService.lastGeocodedAddress,
        telemetryData: telemetryData,
        tuyaDeviceInfo: tuyaDeviceInfo,
      );

      if (!mounted) return;
      Navigator.of(context, rootNavigator: true).pop();

      final isGpsLocked = latitude != 0.0 && longitude != 0.0;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isGpsLocked
                ? 'Sinyal SOS darurat berhasil dikirim.'
                : 'Sinyal SOS darurat berhasil dikirim menggunakan koordinat fallback profil (GPS tidak aktif/belum terkunci).',
          ),
          duration: const Duration(seconds: 4),
        ),
      );
      unawaited(
        context.push(
          AppRoutes.sosStatus,
          extra: {'sos_id': newSosId},
        ),
      );
    } catch (e) {
      if (!mounted) return;
      Navigator.of(context, rootNavigator: true).pop();

      if (e is DioException && e.response?.statusCode == 422) {
        final message =
            e.response?.data['message'] ?? 'Sinyal SOS darurat masih aktif';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message.toString()),
            backgroundColor: Colors.red.shade700,
          ),
        );
        final existingData = e.response?.data is Map ? e.response?.data['data'] : null;
        final existingSosId = (existingData is Map && existingData['id'] != null)
            ? (existingData['id'] as num).toInt()
            : null;

        // Hanya arahkan ke halaman status jika benar-benar ada ID kasus SOS aktif
        if (existingSosId != null) {
          unawaited(
            context.push(
              AppRoutes.sosStatus,
              extra: {'sos_id': existingSosId},
            ),
          );
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal mengirim SOS: $e')),
        );
      }
    }
  }

  Widget _buildHeartRateBanner(bool isHighContrast) {
    final healthService = sl<HealthConnectService>();
    return ValueListenableBuilder<int?>(
      valueListenable: healthService.currentBpm,
      builder: (context, bpm, _) {
        if (bpm == null) return const SizedBox.shrink();

        return ValueListenableBuilder<HeartRateStatus>(
          valueListenable: healthService.currentStatus,
          builder: (context, status, _) {
            Color color;
            String statusText;
            switch (status) {
              case HeartRateStatus.normal:
                color = isHighContrast
                    ? const Color(0xFF4ADE80)
                    : Colors.green;
                statusText = 'Normal';
                break;
              case HeartRateStatus.warning:
                color = isHighContrast
                    ? const Color(0xFFFB923C)
                    : Colors.orange;
                statusText = 'Waspada';
                break;
              case HeartRateStatus.critical:
                color = isHighContrast
                    ? const Color(0xFFF87171)
                    : Colors.red;
                statusText = 'Kritis';
                break;
              case HeartRateStatus.unknown:
                color = Colors.grey;
                statusText = 'Terhubung';
                break;
            }

            final cardBg = AccessibleColors.cardBackground(isHighContrast);
            final cardBorder = isHighContrast
                ? Border.all(color: color, width: 1.5)
                : Border.all(color: color.withValues(alpha: 0.3));

            return InkWell(
              onTap: () => unawaited(context.push(AppRoutes.smartband)),
              borderRadius: BorderRadius.circular(14),
              child: Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: cardBg,
                  borderRadius: BorderRadius.circular(14),
                  border: cardBorder,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(
                        alpha: isHighContrast ? 0.3 : 0.03,
                      ),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Icon(Icons.favorite, color: color, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      '$bpm BPM',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: color,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: color.withValues(
                          alpha: isHighContrast ? 0.25 : 0.1,
                        ),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        statusText,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: color,
                        ),
                      ),
                    ),
                    const Spacer(),
                    ValueListenableBuilder<String>(
                      valueListenable: healthService.connectedDeviceName,
                      builder: (context, deviceName, _) {
                        return Text(
                          deviceName,
                          style: TextStyle(
                            fontSize: 11,
                            color: AccessibleColors.textSecondary(isHighContrast),
                          ),
                        );
                      },
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      CupertinoIcons.chevron_right,
                      size: 14,
                      color: isHighContrast
                          ? const Color(0xFF9CA3AF)
                          : Colors.grey.shade400,
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildDeviceStatusCard(bool isHighContrast) {
    final cardBg = AccessibleColors.cardBackground(isHighContrast);
    final cardBorder = AccessibleColors.cardBorder(isHighContrast);
    final dividerColor =
        isHighContrast ? const Color(0xFF4B5563) : const Color(0xFFE5E7EB);
    final tealColor = isHighContrast ? const Color(0xFF80CBC4) : primaryTeal;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: cardBorder,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isHighContrast ? 0.3 : 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
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
                  color: isHighContrast ? const Color(0xFF4ADE80) : const Color(0xFF16A34A),
                  isHighContrast: isHighContrast,
                ),
                Container(
                  width: 1,
                  height: 38,
                  color: dividerColor,
                ),
                _buildStatItem(
                  icon: CupertinoIcons.wifi,
                  label: 'Koneksi',
                  value: _tuyaDevice != null
                      ? (_tuyaDevice!.isOnline ? 'Terhubung' : 'Terputus')
                      : 'N/A',
                  color: tealColor,
                  isHighContrast: isHighContrast,
                ),
                Container(
                  width: 1,
                  height: 38,
                  color: dividerColor,
                ),
                _buildStatItem(
                  icon: CupertinoIcons.antenna_radiowaves_left_right,
                  label: 'Sinyal',
                  value: _tuyaDevice?.signalStrengthFormatted ?? 'N/A',
                  color: isHighContrast ? const Color(0xFF60A5FA) : const Color(0xFF2563EB),
                  isHighContrast: isHighContrast,
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
    required bool isHighContrast,
  }) {
    return Expanded(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: color.withValues(alpha: isHighContrast ? 0.25 : 0.1),
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
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: AccessibleColors.textSecondary(isHighContrast),
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildMenuGrid(bool isHighContrast) {
    final items = [
      _MenuItemData(
        icon: CupertinoIcons.exclamationmark_bubble,
        label: 'Kirim Laporan',
        route: AppRoutes.quickReport,
      ),
      _MenuItemData(
        icon: CupertinoIcons.antenna_radiowaves_left_right,
        label: 'Perangkat Saya',
        route: AppRoutes.smartband,
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
            Expanded(child: _buildMenuCard(items[0], isHighContrast)),
            const SizedBox(width: 10),
            Expanded(child: _buildMenuCard(items[1], isHighContrast)),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(child: _buildMenuCard(items[2], isHighContrast)),
            const SizedBox(width: 10),
            Expanded(child: _buildMenuCard(items[3], isHighContrast)),
          ],
        ),
      ],
    );
  }

  Widget _buildMenuCard(_MenuItemData item, bool isHighContrast) {
    final cardBg = AccessibleColors.cardBackground(isHighContrast);
    final cardBorder = AccessibleColors.cardBorder(isHighContrast);
    final tealColor = isHighContrast ? const Color(0xFF80CBC4) : primaryTeal;
    final elementId = 'dashboard_menu_${item.label}';

    return ListenableBuilder(
      listenable: AccessibilityService.instance,
      builder: (context, _) {
        final isFocused =
            AccessibilityService.instance.isElementFocused(elementId);
        return Container(
          height: 72,
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(16),
            border: isFocused
                ? Border.all(
                    color: isHighContrast
                        ? const Color(0xFF00FFCC)
                        : const Color(0xFF00897B),
                    width: 2.5,
                  )
                : cardBorder,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isHighContrast ? 0.3 : 0.04),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () {
                AccessibilityService.instance.handleTalkbackTap(
                  id: elementId,
                  speakText: "Membuka ${item.label}",
                  hintText: "Tekan sekali lagi untuk membuka.",
                  onAction: () {
                    if (item.onTap != null) {
                      item.onTap!();
                    } else if (item.route != null) {
                      context.push(item.route!);
                    }
                  },
                );
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(item.icon, color: tealColor, size: 28),
                    const SizedBox(height: 6),
                    Text(
                      item.label,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                        color: AccessibleColors.textPrimary(isHighContrast),
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
      },
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
