import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../data/models/tuya_device_model.dart';
import '../../data/models/tuya_dp_event_model.dart';
import '../../data/services/tuya_channel_service.dart';
import '../../data/services/emergency_trigger_service.dart';

class TuyaDeviceListScreen extends StatefulWidget {
  const TuyaDeviceListScreen({super.key});

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
      // Initialize Tuya SDK
      await _tuyaService.initTuya();

      // Login to Tuya cloud with user's auth token as UID
      final prefs = GetIt.instance<SharedPreferences>();
      final token = prefs.getString('auth_token') ?? '';
      if (token.isNotEmpty) {
        await _tuyaService.loginAnonymous(token);
      }

      // Start listening to EventChannel
      _tuyaService.startEventListening();

      // Subscribe to DP events
      _eventSubscription = _tuyaService.dpEventStream.listen(_handleDpEvent);

      // Load device list
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
    // Show alert
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.warning_amber_rounded, color: Colors.white),
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

    // Send to Laravel
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF7F8FA),
        elevation: 0,
        title: const Row(
          children: [
            Icon(Icons.sensors, color: Color(0xFF005C61)),
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
            icon: const Icon(Icons.refresh, color: Color(0xFF005C61)),
            onPressed: _loadDevices,
          ),
        ],
      ),
      body: _isLoading
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
                ],
              ),
            ),
      floatingActionButton: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          FloatingActionButton.extended(
            heroTag: 'scan_wifi',
            onPressed: () => context.push('/tuya-devices/scan-wifi'),
            backgroundColor: Colors.blue.shade700,
            icon: const Icon(Icons.wifi, color: Colors.white),
            label: const Text('Pairing Wi-Fi', style: TextStyle(color: Colors.white)),
          ),
          const SizedBox(height: 12),
          FloatingActionButton.extended(
            heroTag: 'scan_ble',
            onPressed: () => context.push('/tuya-devices/scan'),
            backgroundColor: const Color(0xFF005C61),
            icon: const Icon(Icons.bluetooth_searching, color: Colors.white),
            label: const Text('Scan BLE', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusCard() {
    final isConnected = _tuyaService.isListening;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isConnected ? const Color(0xFFE0F2F1) : Colors.red.shade50,
              shape: BoxShape.circle,
            ),
            child: Icon(
              isConnected ? Icons.bluetooth_connected : Icons.bluetooth_disabled,
              color: isConnected ? const Color(0xFF005C61) : Colors.red,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isConnected ? 'Tuya SDK Aktif' : 'Tuya SDK Tidak Aktif',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
                Text(
                  '${_devices.length} perangkat terdaftar',
                  style: const TextStyle(color: Colors.grey, fontSize: 12),
                ),
              ],
            ),
          ),
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: isConnected ? Colors.green : Colors.red,
              shape: BoxShape.circle,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSimulationCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF8E1),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.science, color: Colors.orange, size: 20),
              SizedBox(width: 8),
              Text(
                'Mode Pengujian',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: Colors.brown,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'Kirim sinyal SOS simulasi untuk menguji alur Flutter → Laravel → Admin Dashboard tanpa perangkat fisik.',
            style: TextStyle(fontSize: 12, color: Colors.brown),
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
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.emergency, color: Colors.white, size: 18),
              label: Text(
                _isSimulating ? 'Mengirim...' : 'Simulasi SOS',
                style: const TextStyle(color: Colors.white),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange.shade700,
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
      return Container(
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            Icon(Icons.devices_other, size: 64, color: Colors.grey.shade300),
            const SizedBox(height: 16),
            const Text(
              'Belum ada perangkat',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.grey),
            ),
            const SizedBox(height: 8),
            const Text(
              'Tekan tombol "Scan Perangkat" untuk mencari dan menghubungkan perangkat Tuya SOS.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: Colors.grey),
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
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
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
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: device.isOnline ? const Color(0xFFE0F2F1) : Colors.grey.shade100,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.sensors,
              color: device.isOnline ? const Color(0xFF005C61) : Colors.grey,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  device.name,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: device.isOnline ? Colors.green : Colors.red,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      device.isOnline ? 'Online' : 'Offline',
                      style: TextStyle(
                        fontSize: 12,
                        color: device.isOnline ? Colors.green : Colors.red,
                      ),
                    ),
                    if (device.batteryLevel != null) ...[
                      const SizedBox(width: 12),
                      Icon(
                        device.batteryLevel! > 50
                            ? Icons.battery_6_bar
                            : Icons.battery_2_bar,
                        size: 16,
                        color: Colors.amber,
                      ),
                      const SizedBox(width: 2),
                      Text(
                        '${device.batteryLevel}%',
                        style: const TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right, color: Colors.grey),
            onPressed: () => context.push('/tuya-devices/${device.deviceId}'),
          ),
        ],
      ),
    );
  }

  Widget _buildEventLogCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(Icons.history, color: Color(0xFF005C61), size: 20),
                  SizedBox(width: 8),
                  Text(
                    'Event Terbaru',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                ],
              ),
              TextButton(
                onPressed: () => setState(() => _recentEvents.clear()),
                child: const Text('Hapus', style: TextStyle(fontSize: 12)),
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
                      event.isSosTriggered ? Icons.emergency : Icons.info_outline,
                      size: 16,
                      color: event.isSosTriggered ? Colors.red : Colors.grey,
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
                              color: event.isSosTriggered ? Colors.red : Colors.black87,
                            ),
                          ),
                          Text(
                            '${event.timestamp.hour}:${event.timestamp.minute.toString().padLeft(2, '0')}:${event.timestamp.second.toString().padLeft(2, '0')} — ${event.deviceId}',
                            style: const TextStyle(fontSize: 10, color: Colors.grey),
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
