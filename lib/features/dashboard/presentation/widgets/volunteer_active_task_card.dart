import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:sahabat_sos_mobile/core/theme/accessible_colors.dart';

class VolunteerActiveTaskCard extends StatelessWidget {
  final Map<String, dynamic>? activeTask;
  final String activeTaskLokasi;
  final VoidCallback onOpenTaskDetail;

  const VolunteerActiveTaskCard({
    super.key,
    required this.activeTask,
    required this.activeTaskLokasi,
    required this.onOpenTaskDetail,
  });

  @override
  Widget build(BuildContext context) {
    final isHighContrast = context.isHighContrast;
    final primaryTeal = AccessibleColors.primaryTeal(isHighContrast);
    final textPrimary = AccessibleColors.textPrimary(isHighContrast);
    final textSecondary = AccessibleColors.textSecondary(isHighContrast);
    const sosRed = Color(0xFFDC2626);

    if (activeTask != null) {
      final victimName = activeTask!['pengguna']?['name'] ??
          activeTask!['pengguna']?['nama_lengkap'] ??
          'Pengguna Korban';

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Tugas Darurat Aktif',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: isHighContrast ? const Color(0xFFFCA5A5) : sosRed,
            ),
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isHighContrast
                  ? const Color(0xFF450A0A)
                  : sosRed,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isHighContrast
                    ? const Color(0xFFEF4444)
                    : const Color(0xFFB91C1C),
                width: isHighContrast ? 1.5 : 1.0,
              ),
              boxShadow: isHighContrast
                  ? const []
                  : [
                      BoxShadow(
                        color: sosRed.withValues(alpha: 0.25),
                        blurRadius: 12,
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
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        CupertinoIcons.exclamationmark_triangle_fill,
                        color: Colors.white,
                        size: 18,
                      ),
                    ),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Text(
                        'Panggilan Darurat Sedang Ditangani',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      CupertinoIcons.person_fill,
                      color: Colors.white,
                      size: 16,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        victimName,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      CupertinoIcons.location_solid,
                      color: Colors.white,
                      size: 16,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        activeTaskLokasi.isNotEmpty
                            ? activeTaskLokasi
                            : 'Memuat lokasi...',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          height: 1.3,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton.icon(
                    onPressed: onOpenTaskDetail,
                    icon: Icon(
                      CupertinoIcons.map,
                      size: 18,
                      color: isHighContrast ? Colors.white : sosRed,
                    ),
                    label: Text(
                      'Buka Rute & Detail Penanganan',
                      style: TextStyle(
                        color: isHighContrast ? Colors.white : sosRed,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isHighContrast
                          ? const Color(0xFFEF4444)
                          : Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: isHighContrast
                            ? const BorderSide(
                                color: Color(0xFFFCA5A5),
                                width: 1.5,
                              )
                            : BorderSide.none,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AccessibleColors.cardBackground(isHighContrast),
        borderRadius: BorderRadius.circular(16),
        border: AccessibleColors.cardBorder(isHighContrast),
        boxShadow: isHighContrast
            ? const []
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isHighContrast
                  ? const Color(0xFF1E2430)
                  : const Color(0xFFE0F2F1),
              borderRadius: BorderRadius.circular(14),
              border: isHighContrast
                  ? Border.all(color: const Color(0xFF4B5563))
                  : null,
            ),
            child: Icon(
              CupertinoIcons.shield_lefthalf_fill,
              color: primaryTeal,
              size: 26,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Tidak Ada Tugas Berjalan',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Wilayah dalam pengawasan siaga. Notifikasi darurat akan langsung muncul saat warga membutuhkan bantuan.',
                  style: TextStyle(
                    fontSize: 12,
                    color: textSecondary,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
