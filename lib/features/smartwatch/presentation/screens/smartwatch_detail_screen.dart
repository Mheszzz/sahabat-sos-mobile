import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import '../../data/models/smartwatch_device_model.dart';
import '../../data/services/smartwatch_manager.dart';

class SmartwatchDetailScreen extends StatelessWidget {
  final SmartwatchDeviceModel device;

  const SmartwatchDetailScreen({super.key, required this.device});

  @override
  Widget build(BuildContext context) {
    final manager = GetIt.instance<SmartwatchManager>();

    return Scaffold(
      backgroundColor: const Color(0xFFF5F6F8),
      appBar: AppBar(
        title: Text(
          device.name,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        backgroundColor: Colors.white,
        elevation: 0.5,
        iconTheme: const IconThemeData(color: Colors.black87),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Status Header Card
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x0A000000),
                    blurRadius: 10,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      color: const Color(0x1AE53935),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(
                      Icons.watch,
                      color: Color(0xFFE53935),
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
                            color: Color(0xFF1E293B),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          device.brandDisplay,
                          style: const TextStyle(fontSize: 13, color: Colors.grey),
                        ),
                        const SizedBox(height: 6),
                        ValueListenableBuilder<SmartwatchDeviceModel?>(
                          valueListenable: manager.activeDevice,
                          builder: (context, active, _) {
                            final isConn = active != null && active.isConnected;
                            return Row(
                              children: [
                                Container(
                                  width: 8,
                                  height: 8,
                                  decoration: BoxDecoration(
                                    color: isConn ? Colors.green : Colors.grey,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: ValueListenableBuilder<String?>(
                                    valueListenable: manager.connectionStatus,
                                    builder: (context, status, _) {
                                      return Text(
                                        status ?? (isConn ? 'Terhubung & Siaga' : 'Terputus'),
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: isConn ? Colors.green : Colors.grey,
                                          fontWeight: FontWeight.w600,
                                        ),
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

            ValueListenableBuilder<SmartwatchDeviceModel?>(
              valueListenable: manager.activeDevice,
              builder: (context, active, _) {
                final isConn = active != null && active.id == device.id && active.isConnected;
                if (isConn) return const SizedBox.shrink();

                return Container(
                  margin: const EdgeInsets.only(top: 14),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF2F2),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFFECACA)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.bluetooth_disabled, color: Color(0xFFDC2626), size: 20),
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
                      const SizedBox(height: 6),
                      const Text(
                        '💡 Tips Sebelum Menyambungkan:\n'
                        '1. Pastikan layar jam tangan MENYALA (jangan biarkan layar padam/tidur).\n'
                        '2. Tutup aplikasi bawaan jam (Vivan/GloryFit/Da Fit) agar koneksi Bluetooth tidak terkunci.\n'
                        '3. Buka menu Detak Jantung (Heart Rate) di jam tangan.',
                        style: TextStyle(fontSize: 12, color: Color(0xFF7F1D1D), height: 1.4),
                      ),
                      const SizedBox(height: 12),
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
                                              : 'Gagal terhubung ke ${device.name}. Pastikan layar jam menyala & aplikasi bawaan ditutup.',
                                        ),
                                        backgroundColor: ok ? Colors.green : Colors.red,
                                        duration: const Duration(seconds: 4),
                                      ),
                                    );
                                  },
                            icon: isConnBusy
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                  )
                                : const Icon(Icons.bluetooth_connected),
                            label: Text(isConnBusy ? 'Menghubungkan...' : 'Sambungkan Jam Tangan'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFE53935),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                );
              },
            ),

            const SizedBox(height: 16),

            // Live Telemetry Cards
            Row(
              children: [
                // Heart Rate Card
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.favorite, color: Colors.red, size: 22),
                            SizedBox(width: 8),
                            Text(
                              'Detak Jantung',
                              style: TextStyle(fontSize: 13, color: Colors.grey),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        ValueListenableBuilder<int?>(
                          valueListenable: manager.liveHeartRate,
                          builder: (context, bpm, _) {
                            final hasBpm = bpm != null && bpm > 0;
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  hasBpm ? '$bpm BPM' : '-- BPM',
                                  style: TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                    color: hasBpm ? Colors.red.shade700 : const Color(0xFF1E293B),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  hasBpm
                                      ? (bpm > 120
                                          ? 'Tinggi — kemungkinan panik'
                                          : (bpm < 50
                                              ? 'Rendah — perlu perhatian'
                                              : 'Normal — denyut aktif'))
                                      : 'Buka menu HR di jam tangan',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: hasBpm
                                        ? (bpm > 120 || bpm < 50
                                            ? Colors.red.shade700
                                            : Colors.green.shade700)
                                        : Colors.grey,
                                    fontWeight: hasBpm ? FontWeight.w600 : FontWeight.normal,
                                  ),
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
                  child: Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.battery_charging_full, color: Colors.green, size: 22),
                            SizedBox(width: 8),
                            Text(
                              'Baterai Jam',
                              style: TextStyle(fontSize: 13, color: Colors.grey),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          device.batteryLevel != null
                              ? '${device.batteryLevel}%'
                              : 'Normal',
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1E293B),
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Kondisi daya siaga',
                          style: TextStyle(fontSize: 11, color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // Tip Pengukuran Detak Jantung
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFEFF6FF),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFBFDBFE)),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.tips_and_updates_outlined, color: Color(0xFF2563EB), size: 20),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Tips Sensor Detak Jantung:',
                          style: TextStyle(
                            fontSize: 13,
                            color: Color(0xFF1E40AF),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 8),
                  Padding(
                    padding: EdgeInsets.only(left: 30),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '1. Kenakan jam dengan pas di pergelangan tangan',
                          style: TextStyle(fontSize: 12, color: Color(0xFF1E40AF), height: 1.5),
                        ),
                        Text(
                          '2. Buka menu "Heart Rate" / "Detak Jantung" di layar jam',
                          style: TextStyle(fontSize: 12, color: Color(0xFF1E40AF), height: 1.5),
                        ),
                        Text(
                          '3. Tunggu beberapa detik sampai BPM muncul di aplikasi',
                          style: TextStyle(fontSize: 12, color: Color(0xFF1E40AF), height: 1.5),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Sebagian besar smartwatch hanya broadcast BPM via Bluetooth saat menu HR aktif di layar jam.',
                          style: TextStyle(fontSize: 11, color: Color(0xFF3B82F6), height: 1.4, fontStyle: FontStyle.italic),
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
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1E293B),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Gunakan tombol di bawah untuk menguji respon sistem SahabatSOS terhadap sinyal dari smartwatch tanpa harus menunggu kejadian darurat.',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 14),

            ElevatedButton.icon(
              onPressed: () {
                manager.simulateTestSos();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Simulasi tombol SOS Smartwatch dipicu!'),
                    backgroundColor: Color(0xFFE53935),
                  ),
                );
              },
              icon: const Icon(Icons.emergency),
              label: const Text('Uji Coba Tombol SOS Jam'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFE53935),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),

            const SizedBox(height: 10),

            OutlinedButton.icon(
              onPressed: () {
                manager.simulateTestFall();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Simulasi sensor deteksi jatuh dipicu!'),
                    backgroundColor: Colors.orange,
                  ),
                );
              },
              icon: const Icon(Icons.personal_injury, color: Colors.orange),
              label: const Text(
                'Uji Coba Deteksi Jatuh',
                style: TextStyle(color: Colors.orange),
              ),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Colors.orange),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),

            const SizedBox(height: 28),

            // Disconnect & Unpair Actions
            ValueListenableBuilder<SmartwatchDeviceModel?>(
              valueListenable: manager.activeDevice,
              builder: (context, active, _) {
                final isConn = active != null && active.id == device.id && active.isConnected;
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
                    icon: const Icon(Icons.link_off, color: Colors.orange),
                    label: const Text(
                      'Putuskan Sambungan',
                      style: TextStyle(color: Colors.orange),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.orange),
                      padding: const EdgeInsets.symmetric(vertical: 14),
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
                  builder: (ctx) => AlertDialog(
                    title: const Text('Hapus Smartwatch?'),
                    content: const Text(
                      'Perangkat jam tangan ini akan dihapus dari akun SahabatSOS Anda. '
                      'Anda bisa menyambungkan ulang kapan saja.',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        child: const Text('Batal'),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, true),
                        style: TextButton.styleFrom(foregroundColor: Colors.red),
                        child: const Text('Hapus'),
                      ),
                    ],
                  ),
                );

                if (confirm == true) {
                  await manager.unpairDevice(device.id);
                  if (context.mounted) {
                    Navigator.of(context).pop();
                  }
                }
              },
              icon: const Icon(Icons.delete_outline, color: Colors.red),
              label: const Text(
                'Hapus Pasangan (Unpair)',
                style: TextStyle(color: Colors.red),
              ),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Colors.redAccent),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
