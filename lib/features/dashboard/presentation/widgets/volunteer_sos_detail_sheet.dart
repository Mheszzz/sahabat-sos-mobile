import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:sahabat_sos_mobile/core/services/accessibility_service.dart';
import 'package:sahabat_sos_mobile/core/theme/accessible_colors.dart';

/// Bottom sheet detail rincian korban saat pin peta ditekan.
/// Menampilkan profil disabilitas korban, metode komunikasi, alamat, jarak,
/// tombol kontak langsung (WhatsApp/Telepon), serta tombol aksi Terima/Buka Tugas.
class VolunteerSosDetailSheet extends StatelessWidget {
  final Map<String, dynamic> sos;
  final Position? volunteerPosition;
  final Future<String> Function(Map<String, dynamic> sos, double lat, double lng) resolveAddress;
  final bool isFetchingRoute;
  final Future<void> Function() onAcceptOrViewTask;

  const VolunteerSosDetailSheet({
    super.key,
    required this.sos,
    required this.volunteerPosition,
    required this.resolveAddress,
    required this.isFetchingRoute,
    required this.onAcceptOrViewTask,
  });

  IconData _getDisabilityIcon(String category) {
    final cat = category.toLowerCase();
    if (cat.contains('netra')) {
      return CupertinoIcons.eye_slash_fill;
    } else if (cat.contains('rungu') || cat.contains('tuli') || cat.contains('wicara')) {
      return CupertinoIcons.ear;
    } else if (cat.contains('daksa') || cat.contains('fisik') || cat.contains('motorik')) {
      return CupertinoIcons.person_badge_minus;
    } else if (cat.contains('sensorik') || cat.contains('intelektual')) {
      return CupertinoIcons.heart_fill;
    }
    return CupertinoIcons.person_fill;
  }

  String _getCommunicationTip(String category, String? metode) {
    if (metode != null && metode.isNotEmpty && metode.toLowerCase() != 'standar') {
      return 'Preferensi Komunikasi: $metode';
    }
    final cat = category.toLowerCase();
    if (cat.contains('netra')) {
      return 'Panduan Verbal: Berikan petunjuk arah jam dan sapa dari arah depan.';
    } else if (cat.contains('rungu') || cat.contains('tuli') || cat.contains('wicara')) {
      return 'Komunikasi Visual: Gunakan chat WhatsApp atau teks, bicara berhadapan.';
    } else if (cat.contains('daksa') || cat.contains('fisik')) {
      return 'Bantuan Mobilitas: Minta izin sebelum memindahkan alat bantu atau kursi roda.';
    }
    return 'Lakukan pendekatan ramah, perkenalkan diri sebagai Relawan Sahabat SOS.';
  }

  Future<void> _openWhatsApp(BuildContext context, String rawPhone, String name) async {
    String cleanPhone = rawPhone.replaceAll(RegExp(r'[^0-9]'), '');
    if (cleanPhone.isEmpty || cleanPhone == '-') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nomor WhatsApp korban tidak tersedia.')),
      );
      return;
    }
    if (cleanPhone.startsWith('0')) {
      cleanPhone = '62${cleanPhone.substring(1)}';
    }
    final message = Uri.encodeComponent(
      'Halo $name, saya Relawan Sahabat SOS yang sedang merespon sinyal darurat Anda. Mohon tetap tenang, saya sedang bergerak membantu Anda.',
    );
    final uri = Uri.parse('https://wa.me/$cleanPhone?text=$message');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Gagal membuka aplikasi WhatsApp.')),
        );
      }
    }
  }

  Future<void> _callPhone(BuildContext context, String rawPhone) async {
    final cleanPhone = rawPhone.replaceAll(RegExp(r'[^0-9+]'), '');
    if (cleanPhone.isEmpty || cleanPhone == '-') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nomor telepon korban tidak tersedia.')),
      );
      return;
    }
    final uri = Uri.parse('tel:$cleanPhone');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Tidak dapat melakukan panggilan telepon.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isHighContrast = context.isHighContrast;
    final isDarkMode = isHighContrast || Theme.of(context).brightness == Brightness.dark;
    final sheetBg = AccessibleColors.cardBackground(isHighContrast);
    final textPrimary = AccessibleColors.textPrimary(isHighContrast);
    final textSecondary = AccessibleColors.textSecondary(isHighContrast);
    final primaryTeal = AccessibleColors.primaryTeal(isHighContrast);
    const sosRed = Color(0xFFDC2626);

    final sosLat = double.tryParse(sos['latitude']?.toString() ?? '') ?? 0.0;
    final sosLng = double.tryParse(sos['longitude']?.toString() ?? '') ?? 0.0;

    double? distanceKm;
    if (volunteerPosition != null && sosLat != 0.0 && sosLng != 0.0) {
      final meters = Geolocator.distanceBetween(
        volunteerPosition!.latitude,
        volunteerPosition!.longitude,
        sosLat,
        sosLng,
      );
      distanceKm = meters / 1000.0;
    }

    final pengguna = (sos['pengguna'] is Map)
        ? sos['pengguna'] as Map<String, dynamic>
        : <String, dynamic>{};
    final user = (sos['user'] is Map)
        ? sos['user'] as Map<String, dynamic>
        : <String, dynamic>{};

    final nama = pengguna['name'] ??
        user['nama'] ??
        user['name'] ??
        sos['nama'] ??
        sos['nama_pelapor'] ??
        'Pengguna Korban';

    final noTelp = pengguna['phone'] ??
        pengguna['no_telp'] ??
        user['no_telp'] ??
        sos['no_telp'] ??
        '-';

    final kategori = (pengguna['kategori_user'] ?? user['kategori_user'] ?? 'Umum').toString();
    final metodeKomunikasi = pengguna['metode_komunikasi'] ?? user['metode_komunikasi'];
    final catatanMedis = pengguna['catatan_medis'] ?? user['catatan_medis'] ?? sos['catatan'];
    final kebutuhanKhusus = pengguna['kebutuhan_khusus'] ?? user['kebutuhan_khusus'];

    final status = (sos['status_sos'] ?? 'aktif').toString();
    final isAssigned = sos['is_assigned'] == true;

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
      decoration: BoxDecoration(
        color: sheetBg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: isHighContrast
            ? const Border(
                top: BorderSide(color: Color(0xFF4B5563), width: 1.5),
                left: BorderSide(color: Color(0xFF4B5563), width: 1.5),
                right: BorderSide(color: Color(0xFF4B5563), width: 1.5),
              )
            : null,
        boxShadow: isHighContrast
            ? const []
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.12),
                  blurRadius: 20,
                  offset: const Offset(0, -4),
                ),
              ],
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Drag Handle Bar
              Center(
                child: Container(
                  width: 44,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: isHighContrast
                        ? const Color(0xFF4B5563)
                        : (isDarkMode ? Colors.white24 : Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              // Header: Nama Pelapor + Status Badge
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: isAssigned
                          ? (isHighContrast ? const Color(0xFF451A03) : const Color(0xFFFEF3C7))
                          : (isHighContrast ? const Color(0xFF450A0A) : const Color(0xFFFEE2E2)),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isAssigned
                            ? (isHighContrast ? const Color(0xFFF59E0B) : const Color(0xFFF59E0B))
                            : (isHighContrast ? const Color(0xFFEF4444) : sosRed),
                        width: 1.5,
                      ),
                    ),
                    child: Icon(
                      isAssigned
                          ? CupertinoIcons.checkmark_shield_fill
                          : CupertinoIcons.exclamationmark_triangle_fill,
                      color: isAssigned
                          ? (isHighContrast ? const Color(0xFFFDE68A) : const Color(0xFFD97706))
                          : (isHighContrast ? const Color(0xFFFCA5A5) : sosRed),
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          nama,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                            color: textPrimary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          isAssigned
                              ? 'Tugas Sedang Ditangani Anda'
                              : 'Panggilan SOS Belum Ditangani',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: isAssigned
                                ? (isHighContrast ? const Color(0xFFFDE68A) : const Color(0xFFB45309))
                                : (isHighContrast ? const Color(0xFFFCA5A5) : sosRed),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: isAssigned
                          ? (isHighContrast ? const Color(0xFF451A03) : const Color(0xFFFEF3C7))
                          : (isHighContrast ? const Color(0xFF450A0A) : const Color(0xFFFEE2E2)),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isAssigned
                            ? (isHighContrast ? const Color(0xFFF59E0B) : const Color(0xFFD97706))
                            : (isHighContrast ? const Color(0xFFEF4444) : sosRed),
                      ),
                    ),
                    child: Text(
                      isAssigned ? 'DITANGANI' : status.toUpperCase(),
                      style: TextStyle(
                        color: isAssigned
                            ? (isHighContrast ? const Color(0xFFFDE68A) : const Color(0xFFB45309))
                            : (isHighContrast ? const Color(0xFFFCA5A5) : sosRed),
                        fontWeight: FontWeight.bold,
                        fontSize: 11,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // Rincian Kebutuhan & Disabilitas
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: isHighContrast
                      ? const Color(0xFF1E2430)
                      : (isDarkMode ? const Color(0xFF262626) : const Color(0xFFF8FAFC)),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: isHighContrast
                        ? const Color(0xFF4B5563)
                        : (isDarkMode ? Colors.white12 : const Color(0xFFE2E8F0)),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          _getDisabilityIcon(kategori),
                          color: primaryTeal,
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Kategori Disabilitas: $kategori',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: primaryTeal,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _getCommunicationTip(kategori, metodeKomunikasi),
                      style: TextStyle(
                        fontSize: 12,
                        height: 1.35,
                        color: textSecondary,
                      ),
                    ),
                    if (catatanMedis != null && catatanMedis.toString().isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        'Catatan: $catatanMedis',
                        style: TextStyle(
                          fontSize: 11,
                          fontStyle: FontStyle.italic,
                          color: textSecondary,
                        ),
                      ),
                    ],
                    if (kebutuhanKhusus != null && kebutuhanKhusus.toString().isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        'Kebutuhan: $kebutuhanKhusus',
                        style: TextStyle(
                          fontSize: 11,
                          fontStyle: FontStyle.italic,
                          color: textSecondary,
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              const SizedBox(height: 12),

              // Rincian Lokasi & Jarak
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: isHighContrast
                      ? const Color(0xFF1E2430)
                      : (isDarkMode ? const Color(0xFF262626) : const Color(0xFFF8FAFC)),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: isHighContrast
                        ? const Color(0xFF4B5563)
                        : (isDarkMode ? Colors.white12 : const Color(0xFFE2E8F0)),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          CupertinoIcons.location_solid,
                          color: primaryTeal,
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Titik Lokasi Korban',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: primaryTeal,
                          ),
                        ),
                        const Spacer(),
                        if (distanceKm != null)
                          Text(
                            '±${distanceKm.toStringAsFixed(1)} km dari Anda',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: isHighContrast ? const Color(0xFFFDE68A) : const Color(0xFFD97706),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    FutureBuilder<String>(
                      future: resolveAddress(sos, sosLat, sosLng),
                      builder: (context, snapshot) {
                        return Text(
                          snapshot.data ?? 'Memuat alamat...',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: textPrimary,
                            height: 1.35,
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 14),

              // Tombol Komunikasi Langsung (WhatsApp & Telepon)
              if (noTelp != '-')
                Row(
                  children: [
                    Expanded(
                      child: SizedBox(
                        height: 46,
                        child: OutlinedButton.icon(
                          onPressed: () {
                            AccessibilityService.instance.hapticLight();
                            _openWhatsApp(context, noTelp, nama);
                          },
                          icon: const Icon(
                            CupertinoIcons.chat_bubble_2_fill,
                            color: Color(0xFF16A34A),
                            size: 18,
                          ),
                          label: const Text(
                            'Chat WhatsApp',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF16A34A),
                            ),
                          ),
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(
                              color: isHighContrast
                                  ? const Color(0xFF16A34A)
                                  : const Color(0xFFBBF7D0),
                              width: 1.5,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: SizedBox(
                        height: 46,
                        child: OutlinedButton.icon(
                          onPressed: () {
                            AccessibilityService.instance.hapticLight();
                            _callPhone(context, noTelp);
                          },
                          icon: Icon(
                            CupertinoIcons.phone_fill,
                            color: primaryTeal,
                            size: 18,
                          ),
                          label: Text(
                            'Panggil Telepon',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: primaryTeal,
                            ),
                          ),
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(
                              color: isHighContrast
                                  ? primaryTeal
                                  : const Color(0xFFCCECE8),
                              width: 1.5,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),

              const SizedBox(height: 16),

              // Tombol Aksi Utama: Terima Tugas / Buka Detail Tugas
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton.icon(
                  icon: isFetchingRoute
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : Icon(
                          isAssigned
                              ? CupertinoIcons.arrow_right_circle_fill
                              : CupertinoIcons.checkmark_circle_fill,
                          size: 20,
                          color: Colors.white,
                        ),
                  label: Text(
                    isFetchingRoute
                        ? 'Menghitung Rute...'
                        : (isAssigned
                            ? 'Buka Halaman Navigasi & Tugas'
                            : 'Terima & Tangani Tugas Ini'),
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      color: Colors.white,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isHighContrast
                        ? const Color(0xFF00897B)
                        : (isAssigned ? const Color(0xFF00695C) : primaryTeal),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                      side: isHighContrast
                          ? const BorderSide(color: Color(0xFF80CBC4), width: 1.5)
                          : BorderSide.none,
                    ),
                  ),
                  onPressed: isFetchingRoute
                      ? null
                      : () {
                          AccessibilityService.instance.hapticMedium();
                          onAcceptOrViewTask();
                        },
                ),
              ),
              const SizedBox(height: 6),
            ],
          ),
        ),
      ),
    );
  }
}

/// Helper function to display the volunteer SOS detail sheet
void showVolunteerSosDetailSheet({
  required BuildContext context,
  required Map<String, dynamic> sos,
  required Position? volunteerPosition,
  required Future<String> Function(Map<String, dynamic> sos, double lat, double lng) resolveAddress,
  required bool isFetchingRoute,
  required Future<void> Function() onAcceptOrDetail,
}) {
  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (ctx) => VolunteerSosDetailSheet(
      sos: sos,
      volunteerPosition: volunteerPosition,
      resolveAddress: resolveAddress,
      isFetchingRoute: isFetchingRoute,
      onAcceptOrViewTask: onAcceptOrDetail,
    ),
  );
}
