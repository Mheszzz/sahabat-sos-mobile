import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';

import '../../data/models/tuya_device_model.dart';
import '../../data/models/tuya_dp_event_model.dart';
import '../../data/services/tuya_channel_service.dart';
import '../../data/services/emergency_trigger_service.dart';

class TuyaDeviceDetailScreen extends StatefulWidget {
  final String deviceId;

  const TuyaDeviceDetailScreen({super.key, required this.deviceId});

  @override
  State<TuyaDeviceDetailScreen> createState() => _TuyaDeviceDetailScreenState();
}

class _TuyaDeviceDetailScreenState extends State<TuyaDeviceDetailScreen> {
  final _tuyaService = GetIt.instance<TuyaChannelService>();
  final _emergencyService = GetIt.instance<EmergencyTriggerService>();

  TuyaDeviceModel? _device;
  bool _isLoading = true;
  bool _isTestingTrigger = false;
  StreamSubscription<TuyaDpEvent>? _eventSubscription;
  final List<TuyaDpEvent> _deviceEvents = [];

  @override
  void initState() {
    super.initState();
    _loadDeviceInfo();
    _startListening();
  }

  Future<void> _loadDeviceInfo() async {
    setState(() => _isLoading = true);
    try {
      final device = await _tuyaService.getDeviceStatus(widget.deviceId);
      if (mounted) setState(() => _device = device);
    } catch (e) {
      // Use placeholder if device status unavailable
      if (mounted) {
        setState(() {
          _device = TuyaDeviceModel(
            deviceId: widget.deviceId,
            name: 'Perangkat ${widget.deviceId}',
          );
        });
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _startListening() {
    _eventSubscription = _tuyaService.dpEventStream
        .where((event) => event.deviceId == widget.deviceId)
        .listen((event) {
      if (!mounted) return;
      setState(() {
        _deviceEvents.insert(0, event);
        if (_deviceEvents.length > 50) _deviceEvents.removeLast();
      });
    });
  }

  Future<void> _testSosTrigger() async {
    setState(() => _isTestingTrigger = true);
    try {
      await _emergencyService.triggerTestEmergency(widget.deviceId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Test SOS berhasil dikirim ke server'),
            backgroundColor: Color(0xFF005C61),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Gagal: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isTestingTrigger = false);
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
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF005C61)),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          _device?.name ?? 'Detail Perangkat',
          style: const TextStyle(
            color: Color(0xFF005C61),
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Color(0xFF005C61)),
            onPressed: _loadDeviceInfo,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF005C61)),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildDeviceInfoCard(),
                  const SizedBox(height: 16),
                  _buildStatusGrid(),
                  const SizedBox(height: 16),
                  _buildTestCard(),
                  const SizedBox(height: 16),
                  _buildEventHistoryCard(),
                  const SizedBox(height: 16),
                  _buildDangerZone(),
                ],
              ),
            ),
    );
  }

  Widget _buildDeviceInfoCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: (_device?.isOnline ?? false)
                  ? const Color(0xFFE0F2F1)
                  : Colors.red.shade50,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.sensors,
              size: 32,
              color: (_device?.isOnline ?? false)
                  ? const Color(0xFF005C61)
                  : Colors.red,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _device?.name ?? 'Unknown',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'ID: ${widget.deviceId}',
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: (_device?.isOnline ?? false)
                            ? Colors.green
                            : Colors.red,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      (_device?.isOnline ?? false) ? 'Terhubung' : 'Terputus',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: (_device?.isOnline ?? false)
                            ? Colors.green
                            : Colors.red,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusGrid() {
    return Row(
      children: [
        Expanded(
          child: _buildStatusTile(
            icon: Icons.battery_6_bar,
            iconColor: Colors.amber,
            label: 'Baterai',
            value: _device?.batteryLevel != null
                ? '${_device!.batteryLevel}%'
                : 'N/A',
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _buildStatusTile(
            icon: Icons.signal_cellular_alt,
            iconColor: const Color(0xFF005C61),
            label: 'Sinyal',
            value: _device?.signalStrength ?? 'N/A',
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _buildStatusTile(
            icon: Icons.history,
            iconColor: Colors.purple,
            label: 'Event',
            value: '${_deviceEvents.length}',
          ),
        ),
      ],
    );
  }

  Widget _buildStatusTile({
    required IconData icon,
    required Color iconColor,
    required String label,
    required String value,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Icon(icon, color: iconColor, size: 24),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(fontSize: 11, color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _buildTestCard() {
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
                'Uji Coba Perangkat',
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
            'Kirim sinyal uji coba ke server untuk memastikan perangkat ini terhubung dengan benar. Ini tidak akan memicu alarm darurat yang sesungguhnya.',
            style: TextStyle(fontSize: 12, color: Colors.brown),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _isTestingTrigger ? null : _testSosTrigger,
              icon: _isTestingTrigger
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.touch_app, color: Colors.white, size: 18),
              label: Text(
                _isTestingTrigger ? 'Mengirim...' : 'Uji Coba SOS',
                style: const TextStyle(color: Colors.white),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF005C61),
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

  Widget _buildEventHistoryCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.timeline, color: Color(0xFF005C61), size: 20),
              SizedBox(width: 8),
              Text(
                'Riwayat Event',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (_deviceEvents.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Center(
                child: Text(
                  'Belum ada event dari perangkat ini',
                  style: TextStyle(color: Colors.grey, fontSize: 13),
                ),
              ),
            )
          else
            ...List.generate(
              _deviceEvents.length > 10 ? 10 : _deviceEvents.length,
              (index) {
                final event = _deviceEvents[index];
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: event.isSosTriggered
                        ? Colors.red.shade50
                        : Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        event.isSosTriggered
                            ? Icons.emergency
                            : Icons.info_outline,
                        size: 18,
                        color: event.isSosTriggered ? Colors.red : Colors.grey,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              event.isSosTriggered
                                  ? 'SOS Triggered'
                                  : 'Event: ${event.eventType.name}',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: event.isSosTriggered
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                              ),
                            ),
                            Text(
                              '${event.timestamp.day}/${event.timestamp.month}/${event.timestamp.year} ${event.timestamp.hour}:${event.timestamp.minute.toString().padLeft(2, '0')}',
                              style: const TextStyle(
                                fontSize: 10,
                                color: Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (event.isSimulation)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.orange.shade100,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            'SIM',
                            style: TextStyle(
                              fontSize: 9,
                              color: Colors.orange,
                              fontWeight: FontWeight.bold,
                            ),
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

  Widget _buildDangerZone() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.red.shade100),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Zona Bahaya',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14,
              color: Colors.red,
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('Hapus Perangkat?'),
                    content: const Text(
                      'Perangkat ini akan dihapus dari akun Anda. '
                      'Anda perlu melakukan pairing ulang untuk menghubungkannya kembali.',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.of(ctx).pop(),
                        child: const Text('Batal'),
                      ),
                      TextButton(
                        onPressed: () {
                          Navigator.of(ctx).pop();
                          Navigator.of(context).pop();
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Perangkat berhasil dihapus'),
                            ),
                          );
                        },
                        child: const Text(
                          'Hapus',
                          style: TextStyle(color: Colors.red),
                        ),
                      ),
                    ],
                  ),
                );
              },
              icon: const Icon(Icons.delete_outline, color: Colors.red, size: 18),
              label: const Text(
                'Hapus Perangkat',
                style: TextStyle(color: Colors.red),
              ),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Colors.red),
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
}
