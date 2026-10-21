import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:sahabat_sos_mobile/core/di/injection.dart';
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
  }) {
    return Container(
      padding: padding ?? const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color ?? Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: border ?? Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x06000000),
            blurRadius: 6,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: child,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: const Color(0xFFF8FAFC),
        elevation: 0,
        scrolledUnderElevation: 0,
        iconTheme: const IconThemeData(color: primaryTeal),
        leading: widget.showBackButton
            ? IconButton(
                icon: const Icon(CupertinoIcons.back, color: primaryTeal),
                onPressed: () => Navigator.of(context).pop(),
              )
            : null,
        centerTitle: false,
        titleSpacing: widget.showBackButton ? 0 : 16,
        title: Row(
          children: [
            Image.asset('assets/images/logo.png', width: 24, height: 24),
            const SizedBox(width: 8),
            const Text(
              'Sahabat SOS',
              style: TextStyle(
                color: primaryTeal,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
          ],
        ),
      ),
      body: SafeArea(
        child: _isLoading
            ? const Center(
                child: CupertinoActivityIndicator(radius: 16),
              )
            : RefreshIndicator(
                onRefresh: _loadDevices,
                color: primaryTeal,
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text(
                        'Perangkat SOS',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF111827),
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Kelola tombol darurat fisik & smartwatch Tuya Anda.',
                        style: TextStyle(
                          fontSize: 13,
                          color: Color(0xFF4B5563),
                        ),
                      ),
                      const SizedBox(height: 18),

                      // Status Card
                      _buildStatusCard(),
                      const SizedBox(height: 14),

                      // Simulation Test Card
                      _buildSimulationCard(),
                      const SizedBox(height: 14),

                      // Action Buttons for Adding Devices
                      _buildActionButtons(),
                      const SizedBox(height: 22),

                      // Device List
                      _buildDeviceListSection(),
                      const SizedBox(height: 22),

                      // Recent Events Log
                      if (_recentEvents.isNotEmpty) _buildEventLogCard(),

                      const SizedBox(height: 80),
                    ],
                  ),
                ),
              ),
      ),
    );
  }

  Widget _buildStatusCard() {
    final isConnected = _tuyaService.isListening;

    return _buildCard(
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isConnected ? primaryLightTeal : const Color(0xFFFEF2F2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              isConnected
                  ? CupertinoIcons.antenna_radiowaves_left_right
                  : CupertinoIcons.exclamationmark_triangle_fill,
              color: isConnected ? primaryTeal : const Color(0xFFDC2626),
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
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                    color: Color(0xFF111827),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  isConnected
                      ? '${_devices.length} perangkat terdaftar & terpantau'
                      : 'Menghubungkan ke layanan Tuya Cloud...',
                  style: TextStyle(
                    color: isConnected
                        ? const Color(0xFF4B5563)
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

  Widget _buildSimulationCard() {
    return _buildCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF7ED),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  CupertinoIcons.bell_fill,
                  color: Color(0xFFEA580C),
                  size: 18,
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'Mode Pengujian Tombol',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                  color: Color(0xFF111827),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'Kirim sinyal SOS simulasi untuk memverifikasi kesiapan respon sistem darurat.',
            style: TextStyle(fontSize: 13, color: Color(0xFF4B5563), height: 1.4),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            height: 44,
            child: ElevatedButton.icon(
              onPressed: _isSimulating ? null : _simulateSos,
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
                _isSimulating ? 'Mengirim Simulasi...' : 'Uji Simulasi Sinyal SOS',
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

  Widget _buildActionButtons() {
    return Row(
      children: [
        Expanded(
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => context.push('/tuya-devices/scan-wifi'),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 13),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE5E7EB)),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x06000000),
                      blurRadius: 4,
                      offset: Offset(0, 1),
                    ),
                  ],
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(CupertinoIcons.wifi, size: 18, color: primaryTeal),
                    SizedBox(width: 8),
                    Text(
                      'Pairing Wi-Fi',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 13.5,
                        color: primaryTeal,
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
              onTap: () => context.push('/tuya-devices/scan'),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 13),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE5E7EB)),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x06000000),
                      blurRadius: 4,
                      offset: Offset(0, 1),
                    ),
                  ],
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(CupertinoIcons.bluetooth, size: 18, color: primaryTeal),
                    SizedBox(width: 8),
                    Text(
                      'Scan BLE',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 13.5,
                        color: primaryTeal,
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

  Widget _buildDeviceListSection() {
    if (_devices.isEmpty) {
      return _buildCard(
        padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 24),
        child: const Column(
          children: [
            Icon(
              CupertinoIcons.device_phone_portrait,
              size: 48,
              color: Color(0xFF9CA3AF),
            ),
            SizedBox(height: 14),
            Text(
              'Belum Ada Perangkat Terhubung',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 15,
                color: Color(0xFF111827),
              ),
            ),
            SizedBox(height: 6),
            Text(
              'Hubungkan tombol darurat atau smartwatch Tuya melalui menu pairing di atas.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: Color(0xFF6B7280), height: 1.4),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(left: 2, bottom: 10),
          child: Text(
            'Perangkat Saya',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 16,
              color: Color(0xFF111827),
            ),
          ),
        ),
        ...List.generate(_devices.length, (index) {
          final device = _devices[index];
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _buildDeviceCard(device),
          );
        }),
      ],
    );
  }

  Widget _buildDeviceCard(TuyaDeviceModel device) {
    return _buildCard(
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: device.isOnline ? primaryLightTeal : const Color(0xFFF3F4F6),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              CupertinoIcons.device_phone_portrait,
              color: device.isOnline ? primaryTeal : const Color(0xFF9CA3AF),
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
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                    color: Color(0xFF111827),
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
                            ? primaryTeal
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
                            ? primaryTeal
                            : const Color(0xFF9CA3AF),
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
                        color: const Color(0xFF6B7280),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${device.batteryLevel}%',
                        style: const TextStyle(
                          fontSize: 12.5,
                          color: Color(0xFF4B5563),
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
              onTap: () => context.push('/tuya-devices/${device.deviceId}'),
              child: Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: primaryLightTeal,
                  borderRadius: BorderRadius.circular(17),
                ),
                child: const Icon(
                  CupertinoIcons.chevron_right,
                  color: primaryTeal,
                  size: 16,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEventLogCard() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 2, bottom: 10, top: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Aktivitas Terbaru',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                  color: Color(0xFF111827),
                ),
              ),
              GestureDetector(
                onTap: () => setState(() => _recentEvents.clear()),
                child: const Text(
                  'Bersihkan',
                  style: TextStyle(
                    fontSize: 13,
                    color: primaryTeal,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
        _buildCard(
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
                                  ? const Color(0xFFFEF2F2)
                                  : primaryLightTeal,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(
                              event.isSosTriggered
                                  ? CupertinoIcons.exclamationmark_triangle_fill
                                  : CupertinoIcons.info_circle_fill,
                              size: 16,
                              color: event.isSosTriggered
                                  ? const Color(0xFFDC2626)
                                  : primaryTeal,
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
                                        ? const Color(0xFFDC2626)
                                        : const Color(0xFF111827),
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '${event.timestamp.hour.toString().padLeft(2, '0')}:${event.timestamp.minute.toString().padLeft(2, '0')} • ${event.deviceId.length > 8 ? '${event.deviceId.substring(0, 8)}...' : event.deviceId}',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Color(0xFF6B7280),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (!isLast)
                      const Divider(
                        height: 1,
                        color: Color(0xFFF3F4F6),
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
