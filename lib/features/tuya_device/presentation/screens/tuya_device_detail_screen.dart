import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';

import 'package:sahabat_sos_mobile/core/di/injection.dart';
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
  static const Color primaryTeal = Color(0xFF00695C);
  static const Color primaryLightTeal = Color(0xFFE0F2F1);

  final _tuyaService = sl<TuyaChannelService>();
  final _emergencyService = sl<EmergencyTriggerService>();

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
                return;
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
            content: Text('Test SOS berhasil dikirim ke server'),
            backgroundColor: primaryTeal,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal: $e'),
            backgroundColor: const Color(0xFFDC2626),
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
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Perangkat berhasil dihapus dari akun'),
            backgroundColor: primaryTeal,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal menghapus perangkat: $e'),
            backgroundColor: const Color(0xFFDC2626),
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
            Expanded(
              child: Text(
                _device?.name ?? 'Detail Perangkat',
                style: const TextStyle(
                  color: primaryTeal,
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
            icon: const Icon(CupertinoIcons.refresh, color: primaryTeal),
            onPressed: _loadDeviceInfo,
          ),
        ],
      ),
      body: SafeArea(
        child: _isLoading
            ? const Center(
                child: CupertinoActivityIndicator(radius: 16),
              )
            : SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildDeviceInfoCard(),
                    const SizedBox(height: 14),
                    _buildStatusGrid(),
                    const SizedBox(height: 14),
                    _buildTestCard(),
                    const SizedBox(height: 14),
                    _buildEventHistoryCard(),
                    const SizedBox(height: 20),
                    _buildDangerZone(),
                    const SizedBox(height: 80),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildDeviceInfoCard() {
    final isOnline = _device?.isOnline ?? false;

    return _buildCard(
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: isOnline ? primaryLightTeal : const Color(0xFFFEF2F2),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              CupertinoIcons.device_phone_portrait,
              size: 32,
              color: isOnline ? primaryTeal : const Color(0xFFDC2626),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _device?.name ?? 'Perangkat SOS',
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 17,
                    color: Color(0xFF111827),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'ID: ${widget.deviceId}',
                  style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: isOnline ? primaryTeal : const Color(0xFFDC2626),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      isOnline ? 'Terhubung (Aktif)' : 'Terputus (Offline)',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: isOnline ? primaryTeal : const Color(0xFFDC2626),
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
            label: 'Baterai',
            value: _device?.batteryLevel != null
                ? '${_device!.batteryLevel}%'
                : 'N/A',
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _buildStatusTile(
            icon: CupertinoIcons.antenna_radiowaves_left_right,
            label: 'Sinyal',
            value: _device?.signalStrengthFormatted ?? 'N/A',
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _buildStatusTile(
            icon: CupertinoIcons.clock,
            label: 'Total Event',
            value: '${_deviceEvents.length}',
          ),
        ),
      ],
    );
  }

  Widget _buildStatusTile({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return _buildCard(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
      child: Column(
        children: [
          Icon(icon, color: primaryTeal, size: 22),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 16,
              color: Color(0xFF111827),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
          ),
        ],
      ),
    );
  }

  Widget _buildTestCard() {
    return _buildCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: primaryLightTeal,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  CupertinoIcons.paperplane_fill,
                  color: primaryTeal,
                  size: 18,
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'Uji Coba Respon SOS',
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
            'Kirimkan sinyal uji coba ke server backend untuk memastikan integrasi tombol fisik berfungsi normal.',
            style: TextStyle(fontSize: 13, color: Color(0xFF4B5563), height: 1.4),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            height: 46,
            child: ElevatedButton(
              onPressed: _isTestingTrigger ? null : _testSosTrigger,
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryTeal,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                elevation: 0,
              ),
              child: _isTestingTrigger
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CupertinoActivityIndicator(
                        color: Colors.white,
                      ),
                    )
                  : const Text(
                      'Kirim Sinyal Uji Coba',
                      style: TextStyle(
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

  Widget _buildEventHistoryCard() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(left: 2, bottom: 10, top: 4),
          child: Text(
            'Riwayat Sinyal Event',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 16,
              color: Color(0xFF111827),
            ),
          ),
        ),
        _buildCard(
          padding: EdgeInsets.zero,
          child: _deviceEvents.isEmpty
              ? const Padding(
                  padding: EdgeInsets.symmetric(vertical: 32),
                  child: Center(
                    child: Text(
                      'Belum ada riwayat event dari perangkat ini',
                      style: TextStyle(color: Color(0xFF6B7280), fontSize: 13),
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
                            padding: const EdgeInsets.all(14),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: event.isSosTriggered
                                        ? const Color(0xFFFEF2F2)
                                        : const Color(0xFFF3F4F6),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Icon(
                                    event.isSosTriggered
                                        ? CupertinoIcons
                                              .exclamationmark_triangle_fill
                                        : CupertinoIcons.info_circle_fill,
                                    size: 16,
                                    color: event.isSosTriggered
                                        ? const Color(0xFFDC2626)
                                        : const Color(0xFF6B7280),
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
                                        '${event.timestamp.day}/${event.timestamp.month}/${event.timestamp.year} '
                                        '${event.timestamp.hour.toString().padLeft(2, '0')}:${event.timestamp.minute.toString().padLeft(2, '0')}\n'
                                        'Payload: ${event.dps.toString()}',
                                        style: const TextStyle(
                                          fontSize: 11.5,
                                          color: Color(0xFF6B7280),
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
                                      color: const Color(0xFFFFF7ED),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: const Text(
                                      'SIMULASI',
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: Color(0xFFEA580C),
                                        fontWeight: FontWeight.bold,
                                      ),
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

  Widget _buildDangerZone() {
    return _buildCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Zona Bahaya',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 15,
              color: Color(0xFFDC2626),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 46,
            child: OutlinedButton.icon(
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    backgroundColor: Colors.white,
                    surfaceTintColor: Colors.transparent,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: const BorderSide(color: Color(0xFFE5E7EB)),
                    ),
                    title: const Text(
                      'Hapus Perangkat?',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 17,
                        color: Color(0xFF111827),
                      ),
                    ),
                    content: const Text(
                      'Perangkat ini akan dihapus dari akun Sahabat SOS Anda. '
                      'Anda perlu melakukan proses pairing ulang jika ingin menghubungkannya kembali.',
                      style: TextStyle(color: Color(0xFF4B5563), fontSize: 13.5),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.of(ctx).pop(),
                        child: const Text(
                          'Batal',
                          style: TextStyle(
                            color: Color(0xFF6B7280),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      ElevatedButton(
                        onPressed: () {
                          Navigator.of(ctx).pop();
                          _removeDevice();
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFDC2626),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: const Text(
                          'Hapus',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                    ],
                  ),
                );
              },
              icon: const Icon(
                CupertinoIcons.delete,
                color: Color(0xFFDC2626),
                size: 18,
              ),
              label: const Text(
                'Hapus Perangkat Dari Akun',
                style: TextStyle(
                  color: Color(0xFFDC2626),
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
              ),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Color(0xFFDC2626)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
