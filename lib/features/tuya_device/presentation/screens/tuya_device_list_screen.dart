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
      if (_lastSnackbarTime == null || now.difference(_lastSnackbarTime!) > const Duration(seconds: 10)) {
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
          SnackBar(content: Text('Gagal simulasi: $e'), backgroundColor: Colors.red),
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

  Widget _buildGlassContainer({required Widget child, EdgeInsetsGeometry? padding, Color? color}) {
    return Container(
      decoration: BoxDecoration(
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 20,
            spreadRadius: -5,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            padding: padding ?? const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: color ?? Colors.white.withValues(alpha: 0.7),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: Colors.white.withValues(alpha: 0.9), width: 1.5),
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
      appBar: AppBar(
        automaticallyImplyLeading: widget.showBackButton,
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Color(0xFF005C61)),
                centerTitle: false,
        titleSpacing: 16,
        title: const Row(
          children: [
            Icon(CupertinoIcons.heart_circle_fill, color: Color(0xFF005C61), size: 24),
            SizedBox(width: 8),
            Text(
              'Sahabat SOS',
              style: TextStyle(
                color: Color(0xFF005C61),
                fontWeight: FontWeight.bold,
                fontSize: 20,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(CupertinoIcons.refresh, color: Color(0xFF005C61)),
            onPressed: _loadDevices,
          ),
        ],
      ),
      body: Stack(
        children: [
          Container(color: const Color(0xFFF2F2F7)),
          Positioned(
            top: -100,
            left: -50,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                color: const Color(0xFF005C61).withValues(alpha: 0.3),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Positioned(
            bottom: -50,
            right: -100,
            child: Container(
              width: 350,
              height: 350,
              decoration: BoxDecoration(
                color: Colors.blueAccent.withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Positioned.fill(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 80, sigmaY: 80),
              child: Container(color: Colors.transparent),
            ),
          ),
          SafeArea(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator(color: Color(0xFF005C61)))
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text(
                        'Perangkat SOS',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1A1A2E),
                        ),
                      ),
                      const SizedBox(height: 16),
                      // Status Card
                      _buildStatusCard(),
                      const SizedBox(height: 16),

                      // Simulation Test Card
                      _buildSimulationCard(),
                      const SizedBox(height: 16),

                      // Action Buttons for Adding Devices
                      _buildActionButtons(),
                      const SizedBox(height: 16),

                      // Device List
                      _buildDeviceListSection(),
                      const SizedBox(height: 16),

                      // Recent Events Log
                      if (_recentEvents.isNotEmpty) _buildEventLogCard(),
                      
                      const SizedBox(height: 80), // Padding for FAB
                    ],
                  ),
                ),
          ),
        ],
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
                ? const Color(0xFF2E7D32).withValues(alpha: 0.2) 
                : Colors.redAccent.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isConnected ? const Color(0xFF2E7D32) : Colors.redAccent,
              ),
            ),
            child: Icon(
              isConnected ? CupertinoIcons.bluetooth : CupertinoIcons.clear,
              color: isConnected ? const Color(0xFF2E7D32) : Colors.redAccent,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isConnected ? 'Tuya SDK Aktif' : 'Tuya SDK Tidak Aktif',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.black87),
                ),
                Text(
                  '${_devices.length} perangkat terdaftar',
                  style: const TextStyle(color: Colors.black54, fontSize: 12),
                ),
              ],
            ),
          ),
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: isConnected ? const Color(0xFF2E7D32) : Colors.redAccent,
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: (isConnected ? const Color(0xFF2E7D32) : Colors.redAccent).withValues(alpha: 0.5),
                  blurRadius: 6,
                  spreadRadius: 2,
                )
              ]
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSimulationCard() {
    return _buildGlassContainer(
      color: Colors.orange.withValues(alpha: 0.2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(CupertinoIcons.lab_flask, color: Color(0xFFE65100), size: 20),
              SizedBox(width: 8),
              Text(
                'Mode Pengujian',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'Kirim sinyal SOS simulasi untuk menguji alur Flutter → Laravel → Admin Dashboard tanpa perangkat fisik.',
            style: TextStyle(fontSize: 12, color: Colors.black54),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _isSimulating ? null : _simulateSos,
              icon: _isSimulating
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.black87,
                      ),
                    )
                  : const Icon(CupertinoIcons.exclamationmark_triangle_fill, color: Colors.white, size: 18),
              label: Text(
                _isSimulating ? 'Mengirim...' : 'Simulasi SOS',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orangeAccent.withValues(alpha: 0.8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                padding: const EdgeInsets.symmetric(vertical: 12),
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
              backgroundColor: Colors.blue.shade700.withValues(alpha: 0.85),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              elevation: 2,
            ),
            icon: const Icon(CupertinoIcons.wifi),
            label: const Text('Pairing Wi-Fi'),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: ElevatedButton.icon(
            onPressed: () => context.push('/tuya-devices/scan'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF005C61),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              elevation: 2,
            ),
            icon: const Icon(CupertinoIcons.bluetooth),
            label: const Text('Scan BLE'),
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
            Icon(CupertinoIcons.device_desktop, size: 64, color: Colors.black54),
            SizedBox(height: 16),
            Text(
              'Belum ada perangkat',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.black87),
            ),
            SizedBox(height: 8),
            Text(
              'Tekan tombol "Scan Perangkat" untuk mencari dan menghubungkan perangkat Tuya SOS.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: Colors.black54),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            'Perangkat Terdaftar',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.black87),
          ),
        ),
        ...List.generate(_devices.length, (index) {
          final device = _devices[index];
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _buildDeviceCard(device),
          );
        }),
      ],
    );
  }

  Widget _buildDeviceCard(TuyaDeviceModel device) {
    return _buildGlassContainer(
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: device.isOnline 
                ? const Color(0xFF2E7D32).withValues(alpha: 0.2) 
                : Colors.white.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              CupertinoIcons.antenna_radiowaves_left_right,
              color: device.isOnline ? const Color(0xFF2E7D32) : Colors.black54,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  device.name,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.black87),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: device.isOnline ? const Color(0xFF2E7D32) : Colors.redAccent,
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      device.isOnline ? 'Online' : 'Offline',
                      style: TextStyle(
                        fontSize: 12,
                        color: device.isOnline ? const Color(0xFF2E7D32) : Colors.redAccent,
                      ),
                    ),
                    if (device.batteryLevel != null) ...[
                      const SizedBox(width: 12),
                      Icon(
                        device.batteryLevel! > 50
                            ? CupertinoIcons.battery_100
                            : CupertinoIcons.battery_25,
                        size: 16,
                        color: Colors.amberAccent,
                      ),
                      const SizedBox(width: 2),
                      Text(
                        '${device.batteryLevel}%',
                        style: const TextStyle(fontSize: 12, color: Colors.black54),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(CupertinoIcons.chevron_right, color: Colors.black54),
            onPressed: () => context.push('/tuya-devices/${device.deviceId}'),
          ),
        ],
      ),
    );
  }

  Widget _buildEventLogCard() {
    return _buildGlassContainer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(CupertinoIcons.time, color: Colors.black87, size: 20),
                  SizedBox(width: 8),
                  Text(
                    'Event Terbaru',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.black87),
                  ),
                ],
              ),
              TextButton(
                onPressed: () => setState(() => _recentEvents.clear()),
                child: const Text('Hapus', style: TextStyle(fontSize: 12, color: Colors.black54)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ...List.generate(
            _recentEvents.length > 5 ? 5 : _recentEvents.length,
            (index) {
              final event = _recentEvents[index];
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Icon(
                      event.isSosTriggered ? CupertinoIcons.exclamationmark_triangle_fill : CupertinoIcons.info_circle,
                      size: 16,
                      color: event.isSosTriggered ? Colors.redAccent : Colors.black54,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            event.isSosTriggered
                                ? 'SOS Triggered${event.isSimulation ? " (Simulasi)" : ""}'
                                : 'DP Update: ${event.eventType.name}',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight:
                                  event.isSosTriggered ? FontWeight.bold : FontWeight.normal,
                              color: event.isSosTriggered ? Colors.redAccent : Colors.black87,
                            ),
                          ),
                          Text(
                            '${event.timestamp.hour}:${event.timestamp.minute.toString().padLeft(2, '0')}:${event.timestamp.second.toString().padLeft(2, '0')} — ${event.deviceId}',
                            style: const TextStyle(fontSize: 10, color: Colors.black54),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}




