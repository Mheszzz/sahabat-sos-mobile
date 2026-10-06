import 'dart:async';

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

  const TuyaDeviceDetailScreen({
    super.key,
    required this.deviceId,
    this.showBackButton = true,
  });

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
                  DateTime.now().difference(lastEvent.timestamp).inSeconds <
                      2) {
                return; // Skip duplicate UI log
              }
            }

            _deviceEvents.insert(0, event);
            if (_deviceEvents.length > 50) _deviceEvents.removeLast();

            if (_device != null) {
              final newDps = Map<String, dynamic>.from(_device!.dps)
                ..addAll(event.dps);
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
          SnackBar(content: Text('❌ Gagal: $e'), backgroundColor: Colors.red),
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

  Widget _buildGlassContainer({
    required Widget child,
    EdgeInsetsGeometry? padding,
    Color? color,
  }) {
    return Container(
      padding: padding ?? const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color ?? Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.black.withValues(alpha: 0.05),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            spreadRadius: 0,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F2F7),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF2F2F7),
        elevation: 0,
        scrolledUnderElevation: 0,
        iconTheme: const IconThemeData(color: Colors.black87),
        leading: widget.showBackButton
            ? IconButton(
                icon: const Icon(CupertinoIcons.back, color: Colors.black87),
                onPressed: () => Navigator.of(context).pop(),
              )
            : null,
        title: Text(
          _device?.name ?? 'Detail Perangkat',
          style: const TextStyle(
            color: Colors.black87,
            fontWeight: FontWeight.w600,
            fontSize: 18,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(CupertinoIcons.refresh, color: Colors.black87),
            onPressed: _loadDeviceInfo,
          ),
        ],
      ),
      body: SafeArea(
        child: _isLoading
            ? const Center(
                child: CircularProgressIndicator(color: Colors.black87),
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
                    const SizedBox(height: 24),
                    _buildDangerZone(),
                    const SizedBox(height: 100),
                  ],
                ),
              ),
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
                  ? const Color(0xFF34C759).withValues(alpha: 0.1)
                  : const Color(0xFFFF3B30).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(
              CupertinoIcons.device_phone_portrait,
              size: 32,
              color: (_device?.isOnline ?? false)
                  ? const Color(0xFF34C759)
                  : const Color(0xFFFF3B30),
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
                    fontWeight: FontWeight.w600,
                    fontSize: 20,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'ID: ${widget.deviceId}',
                  style: const TextStyle(fontSize: 13, color: Colors.black54),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: (_device?.isOnline ?? false)
                            ? const Color(0xFF34C759)
                            : const Color(0xFFFF3B30),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      (_device?.isOnline ?? false) ? 'Terhubung' : 'Terputus',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: (_device?.isOnline ?? false)
                            ? const Color(0xFF34C759)
                            : const Color(0xFFFF3B30),
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
            iconColor: Colors.black87,
            label: 'Baterai',
            value: _device?.batteryLevel != null
                ? '${_device!.batteryLevel}%'
                : 'N/A',
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatusTile(
            icon: CupertinoIcons.antenna_radiowaves_left_right,
            iconColor: Colors.black87,
            label: 'Sinyal',
            value: _device?.signalStrengthFormatted ?? 'N/A',
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatusTile(
            icon: CupertinoIcons.timer,
            iconColor: Colors.black87,
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
          const SizedBox(height: 12),
          Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 18,
              color: Colors.black87,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(fontSize: 13, color: Colors.black54),
          ),
        ],
      ),
    );
  }

  Widget _buildTestCard() {
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
                  color: const Color(0xFF007AFF).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  CupertinoIcons.paperplane_fill,
                  color: Color(0xFF007AFF),
                  size: 18,
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'Uji Coba Perangkat',
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
            'Kirim sinyal uji coba ke server untuk memastikan perangkat ini terhubung dengan benar.',
            style: TextStyle(fontSize: 13, color: Colors.black54),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isTestingTrigger ? null : _testSosTrigger,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF007AFF),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                padding: const EdgeInsets.symmetric(vertical: 14),
                elevation: 0,
              ),
              child: _isTestingTrigger
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text(
                      'Kirim Uji Coba',
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

  Widget _buildEventHistoryCard() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(left: 4, bottom: 12, top: 8),
          child: Text(
            'Riwayat Event',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 18,
              color: Colors.black87,
            ),
          ),
        ),
        _buildGlassContainer(
          padding: EdgeInsets.zero,
          child: _deviceEvents.isEmpty
              ? const Padding(
                  padding: EdgeInsets.symmetric(vertical: 32),
                  child: Center(
                    child: Text(
                      'Belum ada event dari perangkat ini',
                      style: TextStyle(color: Colors.black54, fontSize: 14),
                    ),
                  ),
                )
              : Column(
                  children: List.generate(
                    _deviceEvents.length > 10 ? 10 : _deviceEvents.length,
                    (index) {
                      final event = _deviceEvents[index];
                      final isLast =
                          index ==
                          (_deviceEvents.length > 10
                              ? 9
                              : _deviceEvents.length - 1);
                      return Column(
                        children: [
                          Padding(
                            padding: const EdgeInsets.all(16),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: event.isSosTriggered
                                        ? const Color(
                                            0xFFFF3B30,
                                          ).withValues(alpha: 0.1)
                                        : const Color(
                                            0xFF8E8E93,
                                          ).withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Icon(
                                    event.isSosTriggered
                                        ? CupertinoIcons
                                              .exclamationmark_triangle_fill
                                        : CupertinoIcons.info_circle_fill,
                                    size: 16,
                                    color: event.isSosTriggered
                                        ? const Color(0xFFFF3B30)
                                        : const Color(0xFF8E8E93),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        event.isSosTriggered
                                            ? 'SOS Triggered'
                                            : 'Event: ${event.eventType.name}',
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
                                        '${event.timestamp.day}/${event.timestamp.month}/${event.timestamp.year} '
                                        '${event.timestamp.hour.toString().padLeft(2, '0')}:${event.timestamp.minute.toString().padLeft(2, '0')}\n'
                                        'Data: ${event.dps.toString()}',
                                        style: const TextStyle(
                                          fontSize: 12,
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
                                      color: const Color(
                                        0xFFFF9500,
                                      ).withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: const Text(
                                      'SIM',
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: Color(0xFFFF9500),
                                        fontWeight: FontWeight.bold,
                                      ),
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

  Widget _buildDangerZone() {
    return _buildGlassContainer(
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Zona Bahaya',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 16,
              color: Color(0xFFFF3B30),
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
                    backgroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    title: const Text(
                      'Hapus Perangkat?',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    content: const Text(
                      'Perangkat ini akan dihapus dari akun Anda. '
                      'Anda perlu melakukan pairing ulang untuk menghubungkannya kembali.',
                      style: TextStyle(color: Colors.black87),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.of(ctx).pop(),
                        child: const Text(
                          'Batal',
                          style: TextStyle(
                            color: Color(0xFF007AFF),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      TextButton(
                        onPressed: () {
                          Navigator.of(ctx).pop();
                          _removeDevice();
                        },
                        child: const Text(
                          'Hapus',
                          style: TextStyle(
                            color: Color(0xFFFF3B30),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
              icon: const Icon(
                CupertinoIcons.delete,
                color: Color(0xFFFF3B30),
                size: 18,
              ),
              label: const Text(
                'Hapus Perangkat',
                style: TextStyle(
                  color: Color(0xFFFF3B30),
                  fontWeight: FontWeight.w600,
                ),
              ),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Color(0xFFFF3B30)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
