import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:get_it/get_it.dart';

import '../../data/models/tuya_device_model.dart';
import '../../data/models/tuya_dp_event_model.dart';
import '../../data/services/tuya_channel_service.dart';
import '../../data/services/emergency_trigger_service.dart';

class TuyaDeviceDetailScreen extends StatefulWidget {
  final String deviceId;
  final bool showBackButton;

  const TuyaDeviceDetailScreen({super.key, required this.deviceId, this.showBackButton = true});

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
    _tuyaService.listenDevice(widget.deviceId);
    
    _eventSubscription = _tuyaService.dpEventStream
        .where((event) => event.deviceId == widget.deviceId)
        .listen((event) {
      if (!mounted) return;
      setState(() {
        // Prevent spamming identical events in the UI history within 2 seconds
        if (_deviceEvents.isNotEmpty) {
          final lastEvent = _deviceEvents.first;
          if (event.isSosTriggered == lastEvent.isSosTriggered &&
              DateTime.now().difference(lastEvent.timestamp).inSeconds < 2) {
            return; // Skip duplicate UI log
          }
        }

        _deviceEvents.insert(0, event);
        if (_deviceEvents.length > 50) _deviceEvents.removeLast();
        
        if (_device != null) {
          final newDps = Map<String, dynamic>.from(_device!.dps)..addAll(event.dps);
          _device = _device!.copyWith(dps: newDps);
        }
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

  Future<void> _removeDevice() async {
    setState(() => _isLoading = true);
    try {
      await _tuyaService.removeDevice(widget.deviceId);
      if (mounted) {
        Navigator.of(context).pop(); // Go back to device list screen
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Perangkat berhasil dihapus dari akun'),
            backgroundColor: Color(0xFF005C61),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Gagal menghapus perangkat: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _eventSubscription?.cancel();
    _tuyaService.stopListenDevice(widget.deviceId);
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
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: widget.showBackButton 
          ? IconButton(
              icon: const Icon(CupertinoIcons.back, color: Color(0xFF005C61)),
              onPressed: () => Navigator.of(context).pop(),
            )
          : null,
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
            icon: const Icon(CupertinoIcons.refresh, color: Color(0xFF005C61)),
            onPressed: _loadDeviceInfo,
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
                      const SizedBox(height: 100),
                    ],
                  ),
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildDeviceInfoCard() {
    return _buildGlassContainer(
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: (_device?.isOnline ?? false)
                  ? const Color(0xFF2E7D32).withValues(alpha: 0.2)
                  : Colors.redAccent.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              CupertinoIcons.antenna_radiowaves_left_right,
              size: 32,
              color: (_device?.isOnline ?? false)
                  ? const Color(0xFF2E7D32)
                  : Colors.redAccent,
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
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'ID: ${widget.deviceId}',
                  style: const TextStyle(fontSize: 12, color: Colors.black54),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: (_device?.isOnline ?? false)
                            ? const Color(0xFF2E7D32)
                            : Colors.redAccent,
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [
                          BoxShadow(
                            color: ((_device?.isOnline ?? false) ? const Color(0xFF2E7D32) : Colors.redAccent).withValues(alpha: 0.5),
                            blurRadius: 6,
                            spreadRadius: 2,
                          )
                        ]
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      (_device?.isOnline ?? false) ? 'Terhubung' : 'Terputus',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: (_device?.isOnline ?? false)
                            ? const Color(0xFF2E7D32)
                            : Colors.redAccent,
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
            icon: CupertinoIcons.battery_100,
            iconColor: Colors.amberAccent,
            label: 'Baterai',
            value: _device?.batteryLevel != null
                ? '${_device!.batteryLevel}%'
                : 'N/A',
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _buildStatusTile(
            icon: CupertinoIcons.antenna_radiowaves_left_right,
            iconColor: Colors.blueAccent,
            label: 'Sinyal',
            value: _device?.signalStrengthFormatted ?? 'N/A',
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _buildStatusTile(
            icon: CupertinoIcons.timer,
            iconColor: Colors.purpleAccent,
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
    return _buildGlassContainer(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
      child: Column(
        children: [
          Icon(icon, color: iconColor, size: 24),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
              color: Colors.black87,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(fontSize: 11, color: Colors.black54),
          ),
        ],
      ),
    );
  }

  Widget _buildTestCard() {
    return _buildGlassContainer(
      color: Colors.orangeAccent.withValues(alpha: 0.15),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(CupertinoIcons.lab_flask, color: Color(0xFFE65100), size: 20),
              SizedBox(width: 8),
              Text(
                'Uji Coba Perangkat',
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
            'Kirim sinyal uji coba ke server untuk memastikan perangkat ini terhubung dengan benar. Ini tidak akan memicu alarm darurat yang sesungguhnya.',
            style: TextStyle(fontSize: 12, color: Colors.black54),
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
                        color: Colors.black87,
                      ),
                    )
                  : const Icon(CupertinoIcons.hand_point_right_fill, color: Colors.white, size: 18),
              label: Text(
                _isTestingTrigger ? 'Mengirim...' : 'Uji Coba SOS',
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

  Widget _buildEventHistoryCard() {
    return _buildGlassContainer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(CupertinoIcons.waveform_path, color: Colors.black87, size: 20),
              SizedBox(width: 8),
              Text(
                'Riwayat Event',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.black87),
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
                  style: TextStyle(color: Colors.black54, fontSize: 13),
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
                        ? Colors.redAccent.withValues(alpha: 0.15)
                        : Colors.white.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: event.isSosTriggered
                          ? Colors.redAccent.withValues(alpha: 0.3)
                          : Colors.transparent,
                    )
                  ),
                  child: Row(
                    children: [
                      Icon(
                        event.isSosTriggered
                            ? CupertinoIcons.exclamationmark_triangle_fill
                            : CupertinoIcons.info_circle,
                        size: 18,
                        color: event.isSosTriggered ? Colors.redAccent : Colors.black54,
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
                                color: Colors.black87,
                                fontWeight: event.isSosTriggered
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                              ),
                            ),
                            Text(
                              '${event.timestamp.day}/${event.timestamp.month}/${event.timestamp.year} '
                              '${event.timestamp.hour}:${event.timestamp.minute.toString().padLeft(2, '0')}\n'
                              'Data: ${event.dps.toString()}',
                              style: const TextStyle(
                                fontSize: 10,
                                color: Colors.black54,
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
                            color: Colors.orangeAccent.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            'SIM',
                            style: TextStyle(
                              fontSize: 9,
                              color: Colors.orangeAccent,
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
    return _buildGlassContainer(
      color: Colors.redAccent.withValues(alpha: 0.1),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Zona Bahaya',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14,
              color: Colors.redAccent,
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
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    title: const Text('Hapus Perangkat?'),
                    content: const Text(
                      'Perangkat ini akan dihapus dari akun Anda. '
                      'Anda perlu melakukan pairing ulang untuk menghubungkannya kembali.',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.of(ctx).pop(),
                        child: const Text('Batal', style: TextStyle(color: Color(0xFF005C61))),
                      ),
                        TextButton(
                          onPressed: () {
                            Navigator.of(ctx).pop(); // Close dialog
                            _removeDevice(); // Perform actual removal
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
              icon: const Icon(CupertinoIcons.delete, color: Colors.redAccent, size: 18),
              label: const Text(
                'Hapus Perangkat',
                style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold),
              ),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Colors.redAccent),
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


