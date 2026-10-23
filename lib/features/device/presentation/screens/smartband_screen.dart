import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:health/health.dart';
import 'package:intl/intl.dart';
import '../../../../core/di/injection.dart';
import '../../../../core/services/health_connect_service.dart';
import '../../../tuya_device/data/services/emergency_trigger_service.dart';
import '../widgets/heart_rate_sos_dialog.dart';

class SmartbandScreen extends StatefulWidget {
  final bool showBackButton;

  const SmartbandScreen({super.key, this.showBackButton = false});

  @override
  State<SmartbandScreen> createState() => _SmartbandScreenState();
}

class _SmartbandScreenState extends State<SmartbandScreen>
    with SingleTickerProviderStateMixin {
  final HealthConnectService _healthService = sl<HealthConnectService>();
  final EmergencyTriggerService _emergencyService = sl<EmergencyTriggerService>();

  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  bool _isSyncing = false;

  static const Color primaryTeal = Color(0xFF00695C);

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.92, end: 1.08).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _refreshStatus();
  }

  Future<void> _refreshStatus() async {
    setState(() => _isSyncing = true);
    await _healthService.init();
    await _healthService.checkPermission();
    if (_healthService.hasPermission.value) {
      await _healthService.fetchLatestHeartRate();
    }
    if (mounted) {
      setState(() => _isSyncing = false);
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  Color _getStatusColor(HeartRateStatus status) {
    switch (status) {
      case HeartRateStatus.normal:
        return const Color(0xFF2E7D32);
      case HeartRateStatus.warning:
        return const Color(0xFFEF6C00);
      case HeartRateStatus.critical:
        return const Color(0xFFD32F2F);
      case HeartRateStatus.unknown:
        return Colors.grey;
    }
  }

  Color _getStatusBg(HeartRateStatus status) {
    switch (status) {
      case HeartRateStatus.normal:
        return const Color(0xFFE8F5E9);
      case HeartRateStatus.warning:
        return const Color(0xFFFFF3E0);
      case HeartRateStatus.critical:
        return const Color(0xFFFFEBEE);
      case HeartRateStatus.unknown:
        return const Color(0xFFF5F5F5);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6F8),
      appBar: AppBar(
        title: const Text(
          'Smartband & Kesehatan',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 18,
            color: primaryTeal,
          ),
        ),
        centerTitle: false,
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: widget.showBackButton
            ? IconButton(
                icon: const Icon(CupertinoIcons.back, color: primaryTeal),
                onPressed: () => Navigator.pop(context),
              )
            : null,
        actions: [
          IconButton(
            icon: _isSyncing
                ? const CupertinoActivityIndicator(radius: 10)
                : const Icon(CupertinoIcons.arrow_clockwise, color: primaryTeal),
            tooltip: 'Sinkronkan data',
            onPressed: _isSyncing ? null : _refreshStatus,
          ),
        ],
      ),
      body: ValueListenableBuilder<int?>(
        valueListenable: _healthService.currentBpm,
        builder: (context, bpm, _) {
          return ValueListenableBuilder<HeartRateStatus>(
            valueListenable: _healthService.currentStatus,
            builder: (context, status, _) {
              return ValueListenableBuilder<bool>(
                valueListenable: _healthService.isMonitoring,
                builder: (context, isMonitoring, _) {
                  return ValueListenableBuilder<bool>(
                    valueListenable: _healthService.hasPermission,
                    builder: (context, hasPermission, _) {
                      return ListView(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        children: [
                          _buildDeviceHeaderCard(hasPermission),
                          const SizedBox(height: 16),
                          _buildHeartRateMonitorCard(bpm, status),
                          const SizedBox(height: 16),
                          _buildMonitoringControls(
                            hasPermission,
                            isMonitoring,
                          ),
                          const SizedBox(height: 16),
                          _buildDiagnosticAndSimulationCard(),
                          const SizedBox(height: 16),
                          _buildSetupGuideCard(),
                          const SizedBox(height: 100),
                        ],
                      );
                    },
                  );
                },
              );
            },
          );
        },
      ),
    );
  }

  /// Header Kartu Perangkat & Status Izin Health Connect
  Widget _buildDeviceHeaderCard(bool hasPermission) {
    final sdkStatus = _healthService.sdkStatus.value;
    final isSdkAvailable = sdkStatus == HealthConnectSdkStatus.sdkAvailable;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: primaryTeal.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.watch_rounded,
                  color: primaryTeal,
                  size: 26,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ValueListenableBuilder<String>(
                      valueListenable: _healthService.connectedDeviceName,
                      builder: (context, deviceName, _) {
                        return Text(
                          deviceName,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: Colors.black87,
                          ),
                        );
                      },
                    ),
                    Text(
                      'via Android Health Connect Hub',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: hasPermission
                      ? const Color(0xFFE8F5E9)
                      : const Color(0xFFFFEBEE),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircleAvatar(
                      radius: 4,
                      backgroundColor:
                          hasPermission ? Colors.green : Colors.red,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      hasPermission ? 'Aktif' : 'Perlu Izin',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: hasPermission ? Colors.green : Colors.red,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Divider(height: 1),
          const SizedBox(height: 12),

          // Jika Health Connect belum terpasang
          if (!isSdkAvailable) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF3E0),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFFFB74D)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, color: Color(0xFFEF6C00)),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      'Health Connect belum terpasang di HP Anda.',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFFE65100),
                      ),
                    ),
                  ),
                  ElevatedButton(
                    onPressed: () => _healthService.installHealthConnect(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFEF6C00),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text(
                      'Pasang',
                      style: TextStyle(fontSize: 11, color: Colors.white),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
          ],

          // Tombol perizinan jika belum diberikan
          if (!hasPermission) ...[
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () async {
                  final granted =
                      await _healthService.requestHeartRatePermission();
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          granted
                              ? 'Izin Health Connect berhasil diberikan!'
                              : 'Izin Health Connect belum diberikan.',
                        ),
                      ),
                    );
                  }
                },
                icon: const Icon(Icons.security, size: 18, color: Colors.white),
                label: const Text(
                  'Beri Izin Baca Detak Jantung',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryTeal,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ),
          ] else ...[
            Row(
              children: [
                const Icon(
                  Icons.check_circle_rounded,
                  color: Colors.green,
                  size: 16,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Izin membaca detak jantung Health Connect terverifikasi.',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade700,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  /// Kartu Tampilan Detak Jantung Utama (BPM & Status)
  Widget _buildHeartRateMonitorCard(int? bpm, HeartRateStatus status) {
    final statusColor = _getStatusColor(status);
    final statusBg = _getStatusBg(status);
    final sampleTime = _healthService.lastSampleTime.value;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 15,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Detak Jantung Real-Time',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: statusBg,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: statusColor.withValues(alpha: 0.3),
                  ),
                ),
                child: Text(
                  bpm != null
                      ? HeartRateRecord(
                          bpm: bpm,
                          timestamp: DateTime.now(),
                          status: status,
                        ).statusLabel
                      : 'Menunggu Data',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: statusColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Animasi Ikon Hati & Angka BPM
          ScaleTransition(
            scale: bpm != null ? _pulseAnimation : const AlwaysStoppedAnimation(1.0),
            child: Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: statusColor.withValues(alpha: 0.08),
              ),
              child: Center(
                child: Icon(
                  Icons.favorite,
                  size: 58,
                  color: bpm != null ? statusColor : Colors.grey.shade400,
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Angka BPM
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                bpm != null ? '$bpm' : '--',
                style: TextStyle(
                  fontSize: 54,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -1.5,
                  color: bpm != null ? statusColor : Colors.black45,
                ),
              ),
              const SizedBox(width: 8),
              const Text(
                'BPM',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.black54,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Waktu Pembaruan Terakhir
          Text(
            sampleTime != null
                ? 'Terakhir diperbarui: ${DateFormat('HH:mm:ss').format(sampleTime)}'
                : 'Belum ada data terbaca',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 16),

          // Indikator Skala Ambang Batas
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFFF9FAFB),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildLegendItem('Rendah', '< 45', Colors.red),
                _buildLegendItem('Normal', '60-100', Colors.green),
                _buildLegendItem('Waspada', '101-130', Colors.orange),
                _buildLegendItem('Kritis', '> 130', Colors.red),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLegendItem(String label, String range, Color color) {
    return Column(
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(radius: 3.5, backgroundColor: color),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          range,
          style: TextStyle(
            fontSize: 10,
            color: Colors.grey.shade600,
          ),
        ),
      ],
    );
  }

  /// Kontrol Pemantauan (Auto Monitoring & Manual Sync)
  Widget _buildMonitoringControls(bool hasPermission, bool isMonitoring) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: primaryTeal.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  CupertinoIcons.timer,
                  color: primaryTeal,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Pemantauan Otomatis (Background)',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: Colors.black87,
                      ),
                    ),
                    Text(
                      'Memeriksa sampel detak jantung setiap 15 detik',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
              CupertinoSwitch(
                value: isMonitoring,
                activeTrackColor: primaryTeal,
                onChanged: !hasPermission
                    ? null
                    : (value) async {
                        if (value) {
                          await _healthService.startMonitoring();
                        } else {
                          await _healthService.stopMonitoring();
                        }
                      },
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(height: 1),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: !hasPermission || _isSyncing
                  ? null
                  : () async {
                      setState(() => _isSyncing = true);
                      final record =
                          await _healthService.fetchLatestHeartRate();
                      if (mounted) {
                        setState(() => _isSyncing = false);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              record != null
                                  ? 'Data diperbarui: ${record.bpm} BPM'
                                  : 'Belum ada data sampel baru di Health Connect.',
                            ),
                          ),
                        );
                      }
                    },
              icon: const Icon(Icons.sync, size: 18, color: primaryTeal),
              label: const Text(
                'Ambil Data Terbaru Sekarang',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: primaryTeal,
                ),
              ),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: primaryTeal),
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

  /// Fitur Pengujian & Simulasi Darurat
  Widget _buildDiagnosticAndSimulationCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.science_outlined, color: Colors.indigo, size: 20),
              SizedBox(width: 8),
              Text(
                'Simulasi & Pengujian Alur SOS',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Uji coba dialog peringatan 10 detik dan pengiriman SOS otomatis tanpa perlu memicu detak jantung fisik tinggi.',
            style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () {
                    // Simulasi Kritis (142 BPM)
                    _healthService.simulateBpm(142);
                    HeartRateSosDialog.show(
                      context,
                      record: HeartRateRecord(
                        bpm: 142,
                        timestamp: DateTime.now(),
                        status: HeartRateStatus.critical,
                      ),
                      onConfirm: () async {
                        try {
                          await _emergencyService.triggerHeartRateEmergency(
                            bpm: 142,
                            reason: 'Simulasi Detak Jantung Kritis',
                          );
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Sinyal SOS Berhasil Dikirim!'),
                              ),
                            );
                          }
                        } catch (e) {
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('$e')),
                            );
                          }
                        }
                      },
                      onCancel: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Peringatan SOS Dibatalkan oleh Pengguna.'),
                          ),
                        );
                      },
                    );
                  },
                  icon: const Icon(Icons.warning_amber_rounded,
                      size: 16, color: Colors.white),
                  label: const Text(
                    'Tes Kritis (142 BPM)',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red.shade700,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    _healthService.simulateBpm(76);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Simulasi 76 BPM (Normal) diterapkan.'),
                      ),
                    );
                  },
                  icon: const Icon(Icons.check_circle_outline,
                      size: 16, color: Colors.green),
                  label: const Text(
                    'Tes Normal (76 BPM)',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: Colors.green,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Colors.green),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Panduan Integrasi Huawei Band 7
  Widget _buildSetupGuideCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: false,
          leading: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: Colors.blue.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.help_outline, color: Colors.blue, size: 20),
          ),
          title: const Text(
            'Panduan Integrasi Huawei Band 7',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          subtitle: const Text(
            'Alur setup Huawei Health -> Health Sync -> Health Connect',
            style: TextStyle(fontSize: 11, color: Colors.black54),
          ),
          childrenPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          children: [
            _buildStepRow(
              step: '1',
              title: 'Huawei Health App',
              desc:
                  'Pastikan Huawei Band 7 terhubung via Bluetooth ke Huawei Health. Buka menu Perangkat -> Pemantauan Kesehatan -> aktifkan "Continuous Heart Rate Monitoring".',
            ),
            const SizedBox(height: 12),
            _buildStepRow(
              step: '2',
              title: 'Pasang Health Sync (Play Store)',
              desc:
                  'Buka Health Sync -> pilih Sumber (Source): Huawei Health -> pilih Tujuan (Destination): Health Connect. Berikan centang pada data "Heart Rate".',
            ),
            const SizedBox(height: 12),
            _buildStepRow(
              step: '3',
              title: 'Perizinan Health Connect',
              desc:
                  'Di menu Pengaturan HP -> Health Connect -> berikan izin Tulis (Write) ke Health Sync dan izin Baca (Read) ke aplikasi Sahabat SOS.',
            ),
            const SizedBox(height: 12),
            _buildStepRow(
              step: '4',
              title: 'Otomatisasi SOS Sahabat',
              desc:
                  'Sahabat SOS akan otomatis membaca data detak jantung secara continuous. Jika detak jantung > 130 BPM atau < 45 BPM, dialog SOS 10 detik akan muncul secara otomatis.',
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  Widget _buildStepRow({
    required String step,
    required String title,
    required String desc,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CircleAvatar(
          radius: 12,
          backgroundColor: primaryTeal,
          child: Text(
            step,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                desc,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade700,
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
