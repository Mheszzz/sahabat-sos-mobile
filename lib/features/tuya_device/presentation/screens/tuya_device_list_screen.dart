import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
  final _tuyaService = GetIt.instance<TuyaChannelService>();

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

      final prefs = GetIt.instance<SharedPreferences>();
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
            backgroundColor: Colors.red,
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
    // ScaffoldMessenger removed as requested by user.
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
            backgroundColor: Colors.red,
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

  Widget _buildGlassContainer({
    required Widget child,
    EdgeInsetsGeometry? padding,
    Color? color,
  }) {
    return Container(
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
            padding: padding ?? const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: color ?? Colors.white.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.6),
                width: 1.5,
              ),
            ),
            child: child,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: const Color(0xFFF5F6F8),
      appBar: AppBar(
        automaticallyImplyLeading: widget.showBackButton,
        backgroundColor: const Color(0xFFF5F6F8),
        elevation: 0,
        scrolledUnderElevation: 0,
        iconTheme: const IconThemeData(color: Color(0xFF00695C)), // primaryTeal
        centerTitle: false,
        titleSpacing: 16,
        title: Row(
          children: [
            Image.asset('assets/images/logo.png', width: 24, height: 24),
            const SizedBox(width: 8),
            const Text(
              'Sahabat SOS',
              style: TextStyle(
                color: Color(0xFF00695C), // primaryTeal
                fontWeight: FontWeight.bold,
                fontSize: 20,
              ),
            ),
          ],
        ),
      ),
      body: Container(
        color: const Color(0xFFF5F6F8),
        child: SafeArea(
          child: _isLoading
              ? const Center(
                  child: CircularProgressIndicator(color: Color(0xFF00695C)),
                )
              : RefreshIndicator(
                  onRefresh: _loadDevices,
                  color: const Color(0xFF00695C),
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Text(
                          'Perangkat',
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                            letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(height: 20),
                        // Status Card
                        _buildStatusCard(),
                        const SizedBox(height: 16),

                        // Simulation Test Card
                        _buildSimulationCard(),
                        const SizedBox(height: 16),

                        // Action Buttons for Adding Devices
                        _buildActionButtons(),
                        const SizedBox(height: 24),

                        // Device List
                        _buildDeviceListSection(),
                        const SizedBox(height: 24),

                        // Recent Events Log
                        if (_recentEvents.isNotEmpty) _buildEventLogCard(),

                        const SizedBox(height: 80), // Padding for FAB
                      ],
                    ),
                  ),
                ),
        ),
      ),
    );
  }

  Widget _buildStatusCard() {
    final isConnected = _tuyaService.isListening;
    return _buildGlassContainer(
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isConnected
                  ? const Color(0xFF34C759).withValues(alpha: 0.1)
                  : const Color(0xFFFF3B30).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              isConnected
                  ? CupertinoIcons.checkmark_shield_fill
                  : CupertinoIcons.xmark_shield_fill,
              color: isConnected
                  ? const Color(0xFF34C759)
                  : const Color(0xFFFF3B30),
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isConnected ? 'Sistem Aktif' : 'Sistem Terputus',
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${_devices.length} perangkat terhubung',
                  style: const TextStyle(color: Colors.black54, fontSize: 13),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSimulationCard() {
    return _buildGlassContainer(
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFFF9500).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  CupertinoIcons.lab_flask_solid,
                  color: Color(0xFFFF9500),
                  size: 18,
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'Mode Pengujian',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Text(
            'Kirim sinyal SOS simulasi untuk menguji sistem.',
            style: TextStyle(fontSize: 13, color: Colors.black54),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isSimulating ? null : _simulateSos,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFF9500),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                padding: const EdgeInsets.symmetric(vertical: 12),
                elevation: 0,
              ),
              child: _isSimulating
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text(
                      'Simulasi SOS',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
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
          child: ElevatedButton.icon(
            onPressed: () => context.push('/tuya-devices/scan-wifi'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: const Color(0xFF007AFF), // Blue text/icon
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: Colors.black.withValues(alpha: 0.05)),
              ),
              elevation: 0,
            ),
            icon: const Icon(CupertinoIcons.wifi, size: 20),
            label: const Text(
              'Pairing Wi-Fi',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: ElevatedButton.icon(
            onPressed: () => context.push('/tuya-devices/scan'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: const Color(0xFF34C759), // Green text/icon
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: Colors.black.withValues(alpha: 0.05)),
              ),
              elevation: 0,
            ),
            icon: const Icon(CupertinoIcons.bluetooth, size: 20),
            label: const Text(
              'Scan BLE',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDeviceListSection() {
    if (_devices.isEmpty) {
      return _buildGlassContainer(
        padding: const EdgeInsets.all(32),
        child: const Column(
          children: [
            Icon(
              CupertinoIcons.device_desktop,
              size: 48,
              color: Colors.black26,
            ),
            SizedBox(height: 16),
            Text(
              'Belum Ada Perangkat',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 16,
                color: Colors.black87,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Gunakan tombol di atas untuk menambah perangkat baru.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: Colors.black54),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(left: 4, bottom: 12),
          child: Text(
            'Perangkat Saya',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 18,
              color: Colors.black87,
            ),
          ),
        ),
        ...List.generate(_devices.length, (index) {
          final device = _devices[index];
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _buildDeviceCard(device),
          );
        }),
      ],
    );
  }

  Widget _buildDeviceCard(TuyaDeviceModel device) {
    return _buildGlassContainer(
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF2F2F7),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              CupertinoIcons.device_phone_portrait,
              color: device.isOnline ? Colors.black87 : Colors.black45,
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  device.name,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: device.isOnline
                            ? const Color(0xFF34C759)
                            : const Color(0xFFFF3B30),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      device.isOnline ? 'Online' : 'Offline',
                      style: TextStyle(
                        fontSize: 13,
                        color: device.isOnline
                            ? const Color(0xFF34C759)
                            : const Color(0xFFFF3B30),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    if (device.batteryLevel != null) ...[
                      const SizedBox(width: 12),
                      Icon(
                        device.batteryLevel! > 20
                            ? CupertinoIcons.battery_100
                            : CupertinoIcons.battery_25,
                        size: 14,
                        color: Colors.black54,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${device.batteryLevel}%',
                        style: const TextStyle(
                          fontSize: 13,
                          color: Colors.black54,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: const Color(0xFFF2F2F7),
              borderRadius: BorderRadius.circular(16),
            ),
            child: IconButton(
              padding: EdgeInsets.zero,
              icon: const Icon(
                CupertinoIcons.chevron_right,
                color: Colors.black54,
                size: 16,
              ),
              onPressed: () => context.push('/tuya-devices/${device.deviceId}'),
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
          padding: const EdgeInsets.only(left: 4, bottom: 12, top: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Aktivitas Terbaru',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 18,
                  color: Colors.black87,
                ),
              ),
              GestureDetector(
                onTap: () => setState(() => _recentEvents.clear()),
                child: const Text(
                  'Bersihkan',
                  style: TextStyle(fontSize: 14, color: Color(0xFF007AFF)),
                ),
              ),
            ],
          ),
        ),
        _buildGlassContainer(
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
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: event.isSosTriggered
                                  ? const Color(
                                      0xFFFF3B30,
                                    ).withValues(alpha: 0.1)
                                  : const Color(
                                      0xFF007AFF,
                                    ).withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(
                              event.isSosTriggered
                                  ? CupertinoIcons.exclamationmark_triangle_fill
                                  : CupertinoIcons.info_circle_fill,
                              size: 16,
                              color: event.isSosTriggered
                                  ? const Color(0xFFFF3B30)
                                  : const Color(0xFF007AFF),
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
                                      : 'Pembaruan Sistem: ${event.eventType.name}',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: event.isSosTriggered
                                        ? FontWeight.w600
                                        : FontWeight.w500,
                                    color: event.isSosTriggered
                                        ? const Color(0xFFFF3B30)
                                        : Colors.black87,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '${event.timestamp.hour.toString().padLeft(2, '0')}:${event.timestamp.minute.toString().padLeft(2, '0')} • ${event.deviceId.length > 8 ? '${event.deviceId.substring(0, 8)}...' : event.deviceId}',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Colors.black54,
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
                        color: Colors.black.withValues(alpha: 0.05),
                        indent: 56,
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
