import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:sahabat_sos_mobile/core/theme/accessible_colors.dart';

class VolunteerDutyCard extends StatelessWidget {
  final bool isReady;
  final bool isVerified;
  final String verificationStatus;
  final ValueChanged<bool> onToggleStatus;

  const VolunteerDutyCard({
    super.key,
    required this.isReady,
    required this.isVerified,
    required this.verificationStatus,
    required this.onToggleStatus,
  });

  @override
  Widget build(BuildContext context) {
    final isHighContrast = context.isHighContrast;
    final primaryTeal = AccessibleColors.primaryTeal(isHighContrast);
    final textSecondary = AccessibleColors.textSecondary(isHighContrast);

    final statusText = isReady ? 'Status: Siap Bertugas' : 'Status: Tidak Aktif';
    final descriptionText = !isVerified
        ? (verificationStatus == 'ditolak'
            ? 'Akun ditolak. Hubungi admin untuk verifikasi ulang.'
            : 'Menunggu verifikasi admin. Radar darurat belum dapat diaktifkan.')
        : (isReady
            ? 'Radar aktif. Anda dapat menerima panggilan darurat otomatis.'
            : 'Sedang istirahat. Sistem tidak akan mengirim panggilan darurat.');

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
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: isHighContrast
                  ? (isReady
                      ? const Color(0xFF064E3B)
                      : const Color(0xFF1E2430))
                  : (isReady
                      ? const Color(0xFFE8F5E9)
                      : Colors.grey.shade200),
              shape: BoxShape.circle,
            ),
            child: Icon(
              isReady
                  ? CupertinoIcons.radiowaves_right
                  : CupertinoIcons.slash_circle,
              color: isHighContrast
                  ? (isReady ? const Color(0xFFA7F3D0) : const Color(0xFF9CA3AF))
                  : (isReady ? primaryTeal : Colors.grey.shade600),
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  statusText,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: isHighContrast
                        ? (isReady ? const Color(0xFF80CBC4) : textSecondary)
                        : (isReady ? primaryTeal : Colors.grey.shade800),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  descriptionText,
                  style: TextStyle(
                    fontSize: 12,
                    color: textSecondary,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
            child: Switch(
              value: isReady,
              onChanged: isVerified
                  ? onToggleStatus
                  : (val) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            verificationStatus == 'ditolak'
                                ? 'Akun relawan Anda telah ditolak oleh admin.'
                                : 'Akun relawan Anda belum diverifikasi oleh admin.',
                          ),
                          backgroundColor: Colors.orange.shade800,
                        ),
                      );
                    },
              activeThumbColor: Colors.white,
              activeTrackColor: isHighContrast
                  ? const Color(0xFF00897B)
                  : primaryTeal,
              inactiveThumbColor: Colors.white,
              inactiveTrackColor: isHighContrast
                  ? const Color(0xFF374151)
                  : (isVerified ? Colors.grey.shade400 : Colors.grey.shade300),
              trackOutlineColor: WidgetStateProperty.all(
                isHighContrast
                    ? const Color(0xFF4B5563)
                    : Colors.transparent,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
