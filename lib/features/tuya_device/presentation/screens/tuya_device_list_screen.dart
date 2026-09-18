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
import '../../data/services/emergency_trigger_service.dart';

class TuyaDeviceListScreen extends StatefulWidget {
  final bool showBackButton;

  const TuyaDeviceListScreen({super.key, this.showBackButton = true});

  @override
  State<TuyaDeviceListScreen> createState() => _TuyaDeviceListScreenState();
}

class _TuyaDeviceListScreenState extends State<TuyaDeviceListScreen> {
  final _tuyaService = GetIt.instance<TuyaChannelService>();
  final _emergencyService = GetIt.instance<EmergencyTriggerService>();

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

  void _handleDpEvent(TuyaDpEvent event) {
    if (!mounted) return;

    setState(() {
      _recentEvents.insert(0, event);
      if (_recentEvents.length > 20) _recentEvents.removeLast();
    });

    if (event.isSosTriggered) {
      _onSosDetected(event);
    }
  }

  Future<void> _onSosDetected(TuyaDpEvent event) async {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(CupertinoIcons.exclamationmark_triangle, color: Colors.white),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  event.isSimulation
                      ? '🧪 SIMULASI SOS terdeteksi dari ${event.deviceId}'
                      : '🚨 SOS DARURAT terdeteksi dari ${event.deviceId}!',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          backgroundColor: event.isSimulation ? Colors.orange : Colors.red,
          duration: const Duration(seconds: 5),
        ),
      );
    }

    try {
      await _emergencyService.triggerEmergency(event);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Sinyal darurat berhasil dikirim ke server'),
            backgroundColor: Color(0xFF005C61),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Gagal kirim ke server: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
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
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: padding ?? const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: color ?? Colors.white.withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withValues(alpha: 0.8)),
          ),
          child: child,
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
        title: const Row(
          children: [
            Icon(CupertinoIcons.antenna_radiowaves_left_right, color: Color(0xFF005C61)),
            SizedBox(width: 8),
            Text(
              'Perangkat Tuya',
              style: TextStyle(
                color: Color(0xFF005C61),
                fontWeight: FontWeight.bold,
                fontSize: 18,
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
      body: Container(
        constraints: const BoxConstraints.expand(),
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFE0F7FA), Color(0xFFF5F6F8), Color(0xFFE0F2F1)],
          ),
        ),
        child: SafeArea(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator(color: Color(0xFF005C61)))
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Status Card
                      _buildStatusCard(),
                      const SizedBox(height: 16),

                      // Simulation Test Card
                      _buildSimulationCard(),
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
      ),
      floatingActionButton: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          FloatingActionButton.extended(
            heroTag: 'scan_wifi',
            onPressed: () => context.push('/tuya-devices/scan-wifi'),
            backgroundColor: Colors.blue.shade700.withValues(alpha: 0.85),
            icon: const Icon(CupertinoIcons.wifi, color: Colors.white),
            label: const Text('Pairing Wi-Fi', style: TextStyle(color: Colors.white)),
          ),
          const SizedBox(height: 12),
          FloatingActionButton.extended(
            heroTag: 'scan_ble',
            onPressed: () => context.push('/tuya-devices/scan'),
            backgroundColor: const Color(0xFF005C61),
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            icon: const Icon(CupertinoIcons.bluetooth, color: Colors.white),
            label: const Text('Scan BLE', style: TextStyle(color: Colors.white)),
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
                ? Colors.greenAccent.withValues(alpha: 0.2) 
                : Colors.redAccent.withValues(alpha: 0.2),
              shape: BoxShape.circle,
              border: Border.all(
                color: isConnected ? Colors.greenAccent : Colors.redAccent,
              ),
            ),
            child: Icon(
              isConnected ? CupertinoIcons.bluetooth : CupertinoIcons.clear,
              color: isConnected ? Colors.greenAccent : Colors.redAccent,
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
              color: isConnected ? Colors.greenAccent : Colors.redAccent,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: (isConnected ? Colors.greenAccent : Colors.redAccent).withValues(alpha: 0.5),
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
                ? Colors.greenAccent.withValues(alpha: 0.2) 
                : Colors.white.withValues(alpha: 0.6),
              shape: BoxShape.circle,
            ),
            child: Icon(
              CupertinoIcons.antenna_radiowaves_left_right,
              color: device.isOnline ? Colors.greenAccent : Colors.black54,
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
                        color: device.isOnline ? Colors.greenAccent : Colors.redAccent,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      device.isOnline ? 'Online' : 'Offline',
                      style: TextStyle(
                        fontSize: 12,
                        color: device.isOnline ? Colors.greenAccent : Colors.redAccent,
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



