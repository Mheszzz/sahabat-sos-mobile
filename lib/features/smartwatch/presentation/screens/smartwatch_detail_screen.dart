import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import '../../data/models/smartwatch_device_model.dart';
import '../../data/services/smartwatch_manager.dart';

class SmartwatchDetailScreen extends StatelessWidget {
  static const Color primaryTeal = Color(0xFF00695C);
  static const Color sosRed = Color(0xFFE50000);

  final SmartwatchDeviceModel device;

  const SmartwatchDetailScreen({super.key, required this.device});

  Widget _buildGlassContainer({
    required Widget child,
    EdgeInsetsGeometry? padding,
    Color? color,
    BorderRadius? borderRadius,
  }) {
    final radius = borderRadius ?? BorderRadius.circular(16);
    return Container(
      decoration: BoxDecoration(
        borderRadius: radius,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: radius,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            padding: padding ?? const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: color ?? Colors.white.withValues(alpha: 0.65),
              borderRadius: radius,
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.7),
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
    final manager = GetIt.instance<SmartwatchManager>();

    return Scaffold(
      backgroundColor: const Color(0xFFF5F6F8),
      appBar: AppBar(
        title: Text(
          device.name,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.black87),
        ),
        backgroundColor: const Color(0xFFF5F6F8),
        elevation: 0,
        scrolledUnderElevation: 0,
        iconTheme: const IconThemeData(color: primaryTeal),
        leading: IconButton(
          icon: const Icon(CupertinoIcons.back, color: primaryTeal),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Status Header Card
            _buildGlassContainer(
              padding: const EdgeInsets.all(18),
              child: Row(
                children: [
                  Container(
                    width: 58,
                    height: 58,
                    decoration: BoxDecoration(
                      color: primaryTeal.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Icon(
                      Icons.watch,
                      color: primaryTeal,
                      size: 32,
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
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          device.brandDisplay,
                          style: const TextStyle(fontSize: 13, color: Colors.black54),
                        ),
                        const SizedBox(height: 6),
                        ValueListenableBuilder<SmartwatchDeviceModel?>(
                          valueListenable: manager.activeDevice,
                          builder: (context, active, _) {
                            final isConn = active != null &&
                                active.id == device.id &&
                                active.isConnected;
                            return Row(
                              children: [
                                Container(
                                  width: 8,
                                  height: 8,
                                  decoration: BoxDecoration(
                                    color: isConn ? const Color(0xFF34C759) : Colors.grey,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: ValueListenableBuilder<String?>(
                                    valueListenable: manager.connectionStatus,
                                    builder: (context, status, _) {
                                      return Text(
                                        isConn
                                            ? (status ?? 'Terhubung & Siaga')
                                            : 'Terputus',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: isConn ? const Color(0xFF34C759) : Colors.grey,
                                          fontWeight: FontWeight.w600,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      );
                                    },
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Banner jika belum tersambung
            ValueListenableBuilder<SmartwatchDeviceModel?>(
              valueListenable: manager.activeDevice,
              builder: (context, active, _) {
                final isConn = active != null &&
                    active.id == device.id &&
                    active.isConnected;
                if (isConn) return const SizedBox.shrink();

                return Padding(
                  padding: const EdgeInsets.only(top: 14),
                  child: _buildGlassContainer(
                    color: const Color(0xFFFEF2F2).withValues(alpha: 0.9),
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Row(
                          children: [
                            Icon(CupertinoIcons.bluetooth,
                                color: Color(0xFFDC2626), size: 20),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Smartwatch Belum Tersambung',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                  color: Color(0xFF991B1B),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          '💡 Tips Sebelum Menyambungkan:\n'
                          '1. Pastikan layar jam tangan MENYALA (jangan biarkan layar padam/tidur).\n'
                          '2. Untuk jam Huawei: aktifkan "Heart Rate Broadcast" di pengaturan olahraga jam, atau hubungkan Huawei Health ke Health Connect.\n'
                          '3. Buka menu Detak Jantung (Heart Rate) di jam tangan.',
                          style: TextStyle(
                              fontSize: 12,
                              color: Color(0xFF7F1D1D),
                              height: 1.45),
                        ),
                        const SizedBox(height: 14),
                        ValueListenableBuilder<String?>(
                          valueListenable: manager.connectingDeviceId,
                          builder: (context, connectingId, _) {
                            final isConnBusy = connectingId == device.id;
                            final isAnyBusy = connectingId != null;

                            return ElevatedButton.icon(
                              onPressed: isAnyBusy
                                  ? null
                                  : () async {
                                      final ok = await manager.connectDevice(device);
                                      if (!context.mounted) return;
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            ok
                                                ? 'Berhasil terhubung ke ${device.name}'
                                                : 'Gagal terhubung ke ${device.name}. Pastikan layar jam menyala & Bluetooth aktif.',
                                          ),
                                          backgroundColor:
                                              ok ? primaryTeal : Colors.red,
                                          duration: const Duration(seconds: 4),
                                        ),
                                      );
                                    },
                              icon: isConnBusy
                                  ? const SizedBox(
                                      width: 14,
                                      height: 14,
                                      child: CupertinoActivityIndicator(
                                        radius: 7,
                                        color: Colors.white,
                                      ),
                                    )
                                  : const Icon(CupertinoIcons.bluetooth, size: 16),
                              label: Text(isConnBusy
                                  ? 'Menghubungkan...'
                                  : 'Sambungkan Jam Tangan'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: primaryTeal,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),

            const SizedBox(height: 16),

            // Live Telemetry Cards (Heart Rate & Battery)
            Row(
              children: [
                // Heart Rate Card
                Expanded(
                  child: _buildGlassContainer(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Row(
                              children: [
                                Icon(CupertinoIcons.heart_fill, color: Colors.red, size: 20),
                                SizedBox(width: 6),
                                Text(
                                  'Detak Jantung',
                                  style: TextStyle(fontSize: 12, color: Colors.black54, fontWeight: FontWeight.w600),
                                ),
                              ],
                            ),
                            InkWell(
                              onTap: () async {
                                await manager.syncFromHealthConnect();
                                if (!context.mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'Menyinkronkan data terbaru dari Health Connect...',
                                    ),
                                    duration: Duration(seconds: 2),
                                  ),
                                );
                              },
                              borderRadius: BorderRadius.circular(8),
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  color: primaryTeal.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: const Icon(
                                  CupertinoIcons.arrow_clockwise,
                                  size: 14,
                                  color: primaryTeal,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        ValueListenableBuilder<int?>(
                          valueListenable: manager.liveHeartRate,
                          builder: (context, bpm, _) {
                            final displayBpm = bpm ?? device.heartRate;
                            final hasBpm = displayBpm != null && displayBpm > 0;
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  hasBpm ? '$displayBpm BPM' : '-- BPM',
                                  style: TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.bold,
                                    color: hasBpm
                                        ? Colors.red.shade700
                                        : Colors.black87,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  hasBpm
                                      ? (displayBpm > 120
                                          ? 'Tinggi — kemungkinan panik'
                                          : (displayBpm < 50
                                              ? 'Rendah — perlu perhatian'
                                              : 'Normal — denyut aktif'))
                                      : 'Buka HR / Sinkronisasi',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: hasBpm
                                        ? (displayBpm > 120 || displayBpm < 50
                                            ? Colors.red.shade700
                                            : const Color(0xFF2E7D32))
                                        : Colors.black45,
                                    fontWeight:
                                        hasBpm ? FontWeight.w600 : FontWeight.normal,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                // Battery Card
                Expanded(
                  child: _buildGlassContainer(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(CupertinoIcons.battery_100,
                                color: Color(0xFF34C759), size: 20),
                            SizedBox(width: 6),
                            Text(
                              'Baterai Jam',
                              style: TextStyle(fontSize: 12, color: Colors.black54, fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        ValueListenableBuilder<int?>(
                          valueListenable: manager.liveBatteryLevel,
                          builder: (context, liveBat, _) {
                            final bat = liveBat ?? device.batteryLevel;
                            return Text(
                              bat != null ? '$bat%' : 'Siaga',
                              style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Kondisi daya siaga',
                          style: TextStyle(fontSize: 11, color: Colors.black45),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // Tombol Sinkronisasi Health Connect
            _buildGlassContainer(
              padding: EdgeInsets.zero,
              child: InkWell(
                onTap: () async {
                  final resultMsg = await manager.syncFromHealthConnect();
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(resultMsg),
                      backgroundColor: resultMsg.startsWith('Berhasil')
                          ? primaryTeal
                          : Colors.orange.shade800,
                      duration: const Duration(seconds: 4),
                    ),
                  );
                },
                borderRadius: BorderRadius.circular(16),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: primaryTeal.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(CupertinoIcons.arrow_2_circlepath, color: primaryTeal, size: 20),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Ambil Data via Health Connect',
                              style: TextStyle(
                                color: Colors.black87,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                            SizedBox(height: 2),
                            Text(
                              'Sinkronisasi dari Huawei Health / Google Fit',
                              style: TextStyle(fontSize: 11, color: Colors.black54),
                            ),
                          ],
                        ),
                      ),
                      const Icon(CupertinoIcons.chevron_right, size: 16, color: Colors.black38),
                    ],
                  ),
                ),
              ),
            ),

            const SizedBox(height: 12),

            // Tip Pengukuran Detak Jantung
            _buildGlassContainer(
              color: primaryTeal.withValues(alpha: 0.06),
              padding: const EdgeInsets.all(14),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(CupertinoIcons.lightbulb_fill,
                          color: primaryTeal, size: 18),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Tips Sensor Detak Jantung:',
                          style: TextStyle(
                            fontSize: 13,
                            color: primaryTeal,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 8),
                  Padding(
                    padding: EdgeInsets.only(left: 26),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '1. Untuk live BPM via Bluetooth: buka Pengaturan Jam Huawei > Pengaturan Olahraga > aktifkan "Siaran Detak Jantung" (Heart Rate Broadcast).',
                          style: TextStyle(
                              fontSize: 12,
                              color: Colors.black87,
                              height: 1.45),
                        ),
                        SizedBox(height: 4),
                        Text(
                          '2. Untuk sinkronisasi via Health Connect: pastikan Huawei Health sudah terhubung ke Health Connect, lalu tekan tombol di atas.',
                          style: TextStyle(
                              fontSize: 12,
                              color: Colors.black87,
                              height: 1.45),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Emergency Testing Section
            const Text(
              'Uji Coba Fungsi Darurat',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Uji respon sistem SahabatSOS terhadap sinyal dari smartwatch tanpa harus menunggu kejadian darurat.',
              style: TextStyle(fontSize: 12, color: Colors.black54),
            ),
            const SizedBox(height: 12),

            _buildGlassContainer(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        manager.simulateTestSos();
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Simulasi tombol SOS Smartwatch dipicu!'),
                            backgroundColor: sosRed,
                          ),
                        );
                      },
                      icon: const Icon(CupertinoIcons.exclamationmark_triangle_fill, size: 18),
                      label: const Text(
                        'Uji Coba Tombol SOS Jam',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: sosRed,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () {
                        manager.simulateTestFall();
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Simulasi sensor deteksi jatuh dipicu!'),
                            backgroundColor: Colors.orange,
                          ),
                        );
                      },
                      icon: const Icon(Icons.personal_injury, color: Colors.orange, size: 18),
                      label: const Text(
                        'Uji Coba Deteksi Jatuh',
                        style: TextStyle(color: Colors.orange, fontWeight: FontWeight.bold),
                      ),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Colors.orange),
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Disconnect & Unpair Actions
            ValueListenableBuilder<SmartwatchDeviceModel?>(
              valueListenable: manager.activeDevice,
              builder: (context, active, _) {
                final isConn = active != null &&
                    active.id == device.id &&
                    active.isConnected;
                if (!isConn) return const SizedBox.shrink();

                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      await manager.disconnectCurrentDevice();
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Sambungan ke smartwatch diputuskan'),
                          ),
                        );
                      }
                    },
                    icon: const Icon(CupertinoIcons.link, color: Colors.orange, size: 18),
                    label: const Text(
                      'Putuskan Sambungan',
                      style: TextStyle(color: Colors.orange, fontWeight: FontWeight.bold),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.orange),
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                );
              },
            ),

            OutlinedButton.icon(
              onPressed: () async {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                    child: AlertDialog(
                      backgroundColor: Colors.white.withValues(alpha: 0.9),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      title: const Text('Hapus Smartwatch?', style: TextStyle(fontWeight: FontWeight.bold)),
                      content: const Text(
                        'Perangkat jam tangan ini akan dihapus dari akun SahabatSOS Anda. '
                        'Anda bisa menyambungkan ulang kapan saja.',
                        style: TextStyle(fontSize: 13, color: Colors.black87),
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx, false),
                          child: const Text('Batal', style: TextStyle(color: Colors.black54)),
                        ),
                        TextButton(
                          onPressed: () => Navigator.pop(ctx, true),
                          style: TextButton.styleFrom(foregroundColor: Colors.red),
                          child: const Text('Hapus', style: TextStyle(fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                  ),
                );

                if (confirm == true) {
                  await manager.unpairDevice(device.id);
                  if (context.mounted) {
                    Navigator.of(context).pop();
                  }
                }
              },
              icon: const Icon(CupertinoIcons.trash, color: Colors.red, size: 18),
              label: const Text(
                'Hapus Pasangan (Unpair)',
                style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
              ),
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: Colors.red.shade300),
                padding: const EdgeInsets.symmetric(vertical: 13),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),

            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}