import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:sahabat_sos_mobile/core/di/injection.dart';
import 'package:sahabat_sos_mobile/core/services/accessibility_service.dart';
import 'package:sahabat_sos_mobile/core/theme/accessible_colors.dart';
import '../../data/models/tuya_device_model.dart';
import '../../data/models/tuya_dp_event_model.dart';
import '../../data/services/tuya_channel_service.dart';

class TuyaDeviceListScreen extends StatefulWidget {
  final bool showBackButton;

  const TuyaDeviceListScreen({super.key, this.showBackButton = true});

  @override
  State<TuyaDeviceListScreen> createState() => _TuyaDeviceListScreenState();
}

class _TuyaDeviceListScreenState extends State<TuyaDeviceListScreen> {
  static const Color primaryTeal = Color(0xFF00695C);
  static const Color primaryLightTeal = Color(0xFFE0F2F1);

  final _tuyaService = sl<TuyaChannelService>();

  List<TuyaDeviceModel> _devices = [];
  bool _isLoading = false;
  bool _isSimulating = false;
  StreamSubscription<TuyaDpEvent>? _eventSubscription;
  final List<TuyaDpEvent> _recentEvents = [];

  @override
  void initState() {
    super.initState();
    _initializeService();
  }

  Future<void> _initializeService() async {
    setState(() => _isLoading = true);
    try {
      await _tuyaService.initTuya();

      final prefs = sl<SharedPreferences>();
      final token = prefs.getString('auth_token') ?? '';
      if (token.isNotEmpty) {
        await _tuyaService.loginAnonymous(token);
      }

      _tuyaService.startEventListening();
      _eventSubscription = _tuyaService.dpEventStream.listen(_handleDpEvent);

      await _loadDevices();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal inisialisasi: $e'),
            backgroundColor: const Color(0xFFDC2626),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadDevices() async {
    try {
      final devices = await _tuyaService.getDeviceList();
      if (mounted) {
        setState(() => _devices = devices);
        // Make sure we are listening to all registered devices to receive events
        for (final device in devices) {
          await _tuyaService.listenDevice(device.deviceId);
        }
      }
    } catch (e) {
      // Device list may be empty initially
    }
  }

  DateTime? _lastSnackbarTime;

  void _handleDpEvent(TuyaDpEvent event) {
    if (!mounted) return;

    setState(() {
      // Prevent spamming identical events in the list within a short time window
      if (_recentEvents.isNotEmpty) {
        final lastEvent = _recentEvents.first;
        if (event.eventType == lastEvent.eventType &&
            event.isSosTriggered == lastEvent.isSosTriggered &&
            DateTime.now().difference(lastEvent.timestamp).inSeconds < 2) {
          return; // Skip inserting duplicate event
        }
      }

      _recentEvents.insert(0, event);
      if (_recentEvents.length > 20) _recentEvents.removeLast();
    });

    if (event.isSosTriggered) {
      final now = DateTime.now();
      if (_lastSnackbarTime == null ||
          now.difference(_lastSnackbarTime!) > const Duration(seconds: 10)) {
        _lastSnackbarTime = now;
        _onSosDetected(event);
      }
    }
  }

  Future<void> _onSosDetected(TuyaDpEvent event) async {
    // Navigation to emergency screen is handled globally by TuyaBackgroundListener in main.dart
  }

  Future<void> _simulateSos() async {
    setState(() => _isSimulating = true);
    try {
      await _tuyaService.simulateSosEvent();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal simulasi: $e'),
            backgroundColor: const Color(0xFFDC2626),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSimulating = false);
    }
  }

  @override
  void dispose() {
    _eventSubscription?.cancel();
    super.dispose();
  }

  Widget _buildCard({
    required Widget child,
    EdgeInsetsGeometry? padding,
    Color? color,
    Border? border,
    bool isHighContrast = false,
  }) {
    return Container(
      padding: padding ?? const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color ?? AccessibleColors.cardBackground(isHighContrast),
        borderRadius: BorderRadius.circular(16),
        border: border ?? AccessibleColors.cardBorder(isHighContrast),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(
              alpha: isHighContrast ? 0.3 : 0.04,
            ),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: child,
    );
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
            isHighContrast ? Colors.black : const Color(0xFFF8FAFC);
        final tealColor =
            isHighContrast ? const Color(0xFF80CBC4) : primaryTeal;

        return Scaffold(
          backgroundColor: currentBg,
          appBar: AppBar(
            automaticallyImplyLeading: false,
            backgroundColor: currentBg,
            elevation: 0,
            scrolledUnderElevation: 0,
            iconTheme: IconThemeData(color: tealColor),
            leading: widget.showBackButton
                ? IconButton(
                    icon: Icon(CupertinoIcons.back, color: tealColor),
                    onPressed: () => Navigator.of(context).pop(),
                  )
                : null,
            centerTitle: false,
            titleSpacing: widget.showBackButton ? 0 : 16,
            title: Row(
              children: [
                Image.asset('assets/images/logo.png', width: 24, height: 24),
                const SizedBox(width: 8),
                Text(
                  'Sahabat SOS',
                  style: TextStyle(
                    color: tealColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
              ],
            ),
          ),
          body: SafeArea(
            child: _isLoading
                ? Center(
                    child: CupertinoActivityIndicator(
                      radius: 16,
                      color: tealColor,
                    ),
                  )
                : RefreshIndicator(
                    onRefresh: _loadDevices,
                    color: tealColor,
                    child: SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            'Perangkat SOS',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              color: isHighContrast
                                  ? Colors.white
                                  : const Color(0xFF111827),
                              letterSpacing: -0.5,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Kelola tombol darurat fisik & smartwatch Tuya Anda.',
                            style: TextStyle(
                              fontSize: 13,
                              color: isHighContrast
                                  ? const Color(0xFFD1D5DB)
                                  : const Color(0xFF4B5563),
                            ),
                          ),
                          const SizedBox(height: 18),

                          // Status Card
                          _buildStatusCard(isHighContrast),
                          const SizedBox(height: 14),

                          // Simulation Test Card
                          _buildSimulationCard(isHighContrast),
                          const SizedBox(height: 14),

                          // Action Buttons for Adding Devices
                          _buildActionButtons(isHighContrast),
                          const SizedBox(height: 22),

                          // Device List
                          _buildDeviceListSection(isHighContrast),
                          const SizedBox(height: 22),

                          // Recent Events Log
                          if (_recentEvents.isNotEmpty)
                            _buildEventLogCard(isHighContrast),

                          const SizedBox(height: 80),
                        ],
                      ),
                    ),
                  ),
          ),
        );
      },
    );
  }

  Widget _buildStatusCard(bool isHighContrast) {
    final isConnected = _tuyaService.isListening;
    final tealColor = isHighContrast ? const Color(0xFF80CBC4) : primaryTeal;

    return _buildCard(
      isHighContrast: isHighContrast,
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isConnected
                  ? (isHighContrast
                      ? const Color(0xFF1E3A34)
                      : primaryLightTeal)
                  : (isHighContrast
                      ? const Color(0xFF3B1515)
                      : const Color(0xFFFEF2F2)),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              isConnected
                  ? CupertinoIcons.antenna_radiowaves_left_right
                  : CupertinoIcons.exclamationmark_triangle_fill,
              color: isConnected ? tealColor : const Color(0xFFDC2626),
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isConnected ? 'Perangkat Terhubung' : 'Perangkat Terputus',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                    color: AccessibleColors.textPrimary(isHighContrast),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  isConnected
                      ? '${_devices.length} perangkat terdaftar & terpantau'
                      : 'Menghubungkan ke layanan Tuya Cloud...',
                  style: TextStyle(
                    color: isConnected
                        ? AccessibleColors.textSecondary(isHighContrast)
                        : const Color(0xFFDC2626),
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSimulationCard(bool isHighContrast) {
    return _buildCard(
      isHighContrast: isHighContrast,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: isHighContrast
                      ? const Color(0xFF332015)
                      : const Color(0xFFFFF7ED),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  CupertinoIcons.bell_fill,
                  color: Color(0xFFEA580C),
                  size: 18,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'Mode Pengujian Tombol',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                  color: AccessibleColors.textPrimary(isHighContrast),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Kirim sinyal SOS simulasi untuk memverifikasi kesiapan respon sistem darurat.',
            style: TextStyle(
              fontSize: 13,
              color: AccessibleColors.textSecondary(isHighContrast),
              height: 1.4,
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            height: 44,
            child: ElevatedButton.icon(
              onPressed: _isSimulating
                  ? null
                  : () {
                      AccessibilityService.instance.hapticHeavy();
                      unawaited(
                        AccessibilityService.instance
                            .speak("Menguji simulasi sinyal SOS"),
                      );
                      _simulateSos();
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFEA580C),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                elevation: 0,
              ),
              icon: _isSimulating
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CupertinoActivityIndicator(
                        color: Colors.white,
                      ),
                    )
                  : const Icon(CupertinoIcons.bell_fill, size: 16),
              label: Text(
                _isSimulating
                    ? 'Mengirim Simulasi...'
                    : 'Uji Simulasi Sinyal SOS',
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons(bool isHighContrast) {
    final tealColor = isHighContrast ? const Color(0xFF80CBC4) : primaryTeal;
    final defaultBg = AccessibleColors.cardBackground(isHighContrast);
    final cardBorder = AccessibleColors.cardBorder(isHighContrast);

    return Row(
      children: [
        Expanded(
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () {
                AccessibilityService.instance.handleTalkbackTap(
                  id: 'tuya_pairing_wifi_btn',
                  speakText: "Membuka pairing Wi-Fi",
                  hintText: "Tekan sekali lagi untuk membuka pairing Wi-Fi.",
                  onAction: () => context.push('/tuya-devices/scan-wifi'),
                );
              },
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 13),
                decoration: BoxDecoration(
                  color: defaultBg,
                  borderRadius: BorderRadius.circular(12),
                  border: cardBorder,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(
                        alpha: isHighContrast ? 0.25 : 0.04,
                      ),
                      blurRadius: 4,
                      offset: const Offset(0, 1),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(CupertinoIcons.wifi, size: 18, color: tealColor),
                    const SizedBox(width: 8),
                    Text(
                      'Pairing Wi-Fi',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 13.5,
                        color: tealColor,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () {
                AccessibilityService.instance.handleTalkbackTap(
                  id: 'tuya_scan_bt_btn',
                  speakText: "Membuka scan Bluetooth",
                  hintText: "Tekan sekali lagi untuk membuka scan Bluetooth.",
                  onAction: () => context.push('/tuya-devices/scan'),
                );
              },
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 13),
                decoration: BoxDecoration(
                  color: defaultBg,
                  borderRadius: BorderRadius.circular(12),
                  border: cardBorder,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(
                        alpha: isHighContrast ? 0.25 : 0.04,
                      ),
                      blurRadius: 4,
                      offset: const Offset(0, 1),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(CupertinoIcons.bluetooth, size: 18, color: tealColor),
                    const SizedBox(width: 8),
                    Text(
                      'Scan BLE',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 13.5,
                        color: tealColor,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDeviceListSection(bool isHighContrast) {
    if (_devices.isEmpty) {
      return _buildCard(
        isHighContrast: isHighContrast,
        padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 24),
        child: Column(
          children: [
            Icon(
              CupertinoIcons.device_phone_portrait,
              size: 48,
              color: isHighContrast
                  ? const Color(0xFF6B7280)
                  : const Color(0xFF9CA3AF),
            ),
            const SizedBox(height: 14),
            Text(
              'Belum Ada Perangkat Terhubung',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 15,
                color: AccessibleColors.textPrimary(isHighContrast),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Hubungkan tombol darurat atau smartwatch Tuya melalui menu pairing di atas.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: AccessibleColors.textSecondary(isHighContrast),
                height: 1.4,
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 2, bottom: 10),
          child: Text(
            'Perangkat Saya',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 16,
              color: AccessibleColors.textPrimary(isHighContrast),
            ),
          ),
        ),
        ...List.generate(_devices.length, (index) {
          final device = _devices[index];
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _buildDeviceCard(device, isHighContrast),
          );
        }),
      ],
    );
  }

  Widget _buildDeviceCard(TuyaDeviceModel device, bool isHighContrast) {
    final tealColor = isHighContrast ? const Color(0xFF80CBC4) : primaryTeal;

    return _buildCard(
      isHighContrast: isHighContrast,
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: device.isOnline
                  ? (isHighContrast
                      ? const Color(0xFF1E3A34)
                      : primaryLightTeal)
                  : (isHighContrast
                      ? const Color(0xFF263238)
                      : const Color(0xFFF3F4F6)),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              CupertinoIcons.device_phone_portrait,
              color: device.isOnline ? tealColor : const Color(0xFF9CA3AF),
              size: 24,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  device.name,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                    color: AccessibleColors.textPrimary(isHighContrast),
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Container(
                      width: 7,
                      height: 7,
                      decoration: BoxDecoration(
                        color: device.isOnline
                            ? tealColor
                            : const Color(0xFF9CA3AF),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      device.isOnline ? 'Online' : 'Offline',
                      style: TextStyle(
                        fontSize: 12.5,
                        color: device.isOnline
                            ? tealColor
                            : AccessibleColors.textSecondary(isHighContrast),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (device.batteryLevel != null) ...[
                      const SizedBox(width: 14),
                      Icon(
                        device.batteryLevel! > 20
                            ? CupertinoIcons.battery_100
                            : CupertinoIcons.battery_25,
                        size: 14,
                        color: AccessibleColors.textSecondary(isHighContrast),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${device.batteryLevel}%',
                        style: TextStyle(
                          fontSize: 12.5,
                          color: AccessibleColors.textSecondary(isHighContrast),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () {
                AccessibilityService.instance.handleTalkbackTap(
                  id: 'tuya_device_card_${device.deviceId}',
                  speakText: "Membuka detail perangkat ${device.name}",
                  hintText: "Tekan sekali lagi untuk membuka detail perangkat.",
                  onAction: () => context.push('/tuya-devices/${device.deviceId}'),
                );
              },
              child: Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: isHighContrast
                      ? const Color(0xFF1E3A34)
                      : primaryLightTeal,
                  borderRadius: BorderRadius.circular(17),
                ),
                child: Icon(
                  CupertinoIcons.chevron_right,
                  color: tealColor,
                  size: 16,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEventLogCard(bool isHighContrast) {
    final tealColor = isHighContrast ? const Color(0xFF80CBC4) : primaryTeal;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 2, bottom: 10, top: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Aktivitas Terbaru',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                  color: AccessibleColors.textPrimary(isHighContrast),
                ),
              ),
              GestureDetector(
                onTap: () => setState(() => _recentEvents.clear()),
                child: Text(
                  'Bersihkan',
                  style: TextStyle(
                    fontSize: 13,
                    color: tealColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
        _buildCard(
          isHighContrast: isHighContrast,
          padding: EdgeInsets.zero,
          child: Column(
            children: List.generate(
              _recentEvents.length > 5 ? 5 : _recentEvents.length,
              (index) {
                final event = _recentEvents[index];
                final isLast =
                    index ==
                    (_recentEvents.length > 5 ? 4 : _recentEvents.length - 1);
                return Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(14),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: event.isSosTriggered
                                  ? (isHighContrast
                                      ? const Color(0xFF3B1515)
                                      : const Color(0xFFFEF2F2))
                                  : (isHighContrast
                                      ? const Color(0xFF1E3A34)
                                      : primaryLightTeal),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(
                              event.isSosTriggered
                                  ? CupertinoIcons.exclamationmark_triangle_fill
                                  : CupertinoIcons.info_circle_fill,
                              size: 16,
                              color: event.isSosTriggered
                                  ? const Color(0xFFDC2626)
                                  : tealColor,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  event.isSosTriggered
                                      ? 'Panggilan Darurat SOS${event.isSimulation ? " (Simulasi)" : ""}'
                                      : 'Pembaruan Status: ${event.eventType.name}',
                                  style: TextStyle(
                                    fontSize: 13.5,
                                    fontWeight: event.isSosTriggered
                                        ? FontWeight.w700
                                        : FontWeight.w600,
                                    color: event.isSosTriggered
                                        ? const Color(0xFFEF4444)
                                        : AccessibleColors.textPrimary(
                                            isHighContrast),
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '${event.timestamp.hour.toString().padLeft(2, '0')}:${event.timestamp.minute.toString().padLeft(2, '0')} • ${event.deviceId.length > 8 ? '${event.deviceId.substring(0, 8)}...' : event.deviceId}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: AccessibleColors.textSecondary(
                                        isHighContrast),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (!isLast)
                      Divider(
                        height: 1,
                        color: isHighContrast
                            ? const Color(0xFF374151)
                            : const Color(0xFFF3F4F6),
                        indent: 52,
                      ),
                  ],
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}
