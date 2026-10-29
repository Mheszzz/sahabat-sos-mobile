import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:sahabat_sos_mobile/core/theme/accessible_colors.dart';

class VolunteerStatsSection extends StatelessWidget {
  final int activeSosCount;
  final int totalLaporan;
  final int completedTaskCount;

  const VolunteerStatsSection({
    super.key,
    required this.activeSosCount,
    required this.totalLaporan,
    required this.completedTaskCount,
  });

  @override
  Widget build(BuildContext context) {
    final isHighContrast = context.isHighContrast;
    final primaryTeal = AccessibleColors.primaryTeal(isHighContrast);
    final textPrimary = AccessibleColors.textPrimary(isHighContrast);
    final textSecondary = AccessibleColors.textSecondary(isHighContrast);
    const sosRed = Color(0xFFDC2626);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Statistik & Situasi Terkini',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: textPrimary,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _StatTile(
                icon: CupertinoIcons.exclamationmark_triangle_fill,
                iconColor: sosRed,
                title: 'SOS AKTIF',
                value: '$activeSosCount',
                unit: 'Kasus',
                bgIconColor: Colors.red.shade50,
                isHighContrast: isHighContrast,
                textPrimary: textPrimary,
                textSecondary: textSecondary,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _StatTile(
                icon: CupertinoIcons.doc_text_fill,
                iconColor: const Color(0xFF1976D2),
                title: 'LAPORAN',
                value: '$totalLaporan',
                unit: 'Warga',
                bgIconColor: Colors.blue.shade50,
                isHighContrast: isHighContrast,
                textPrimary: textPrimary,
                textSecondary: textSecondary,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _StatTile(
                icon: CupertinoIcons.checkmark_seal_fill,
                iconColor: primaryTeal,
                title: 'KONTRIBUSI',
                value: '$completedTaskCount',
                unit: 'Selesai',
                bgIconColor: const Color(0xFFE0F2F1),
                isHighContrast: isHighContrast,
                textPrimary: textPrimary,
                textSecondary: textSecondary,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _StatTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String value;
  final String unit;
  final Color bgIconColor;
  final bool isHighContrast;
  final Color textPrimary;
  final Color textSecondary;

  const _StatTile({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.value,
    required this.unit,
    required this.bgIconColor,
    required this.isHighContrast,
    required this.textPrimary,
    required this.textSecondary,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
      decoration: BoxDecoration(
        color: AccessibleColors.cardBackground(isHighContrast),
        borderRadius: BorderRadius.circular(16),
        border: AccessibleColors.cardBorder(isHighContrast),
        boxShadow: isHighContrast
            ? const []
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 14,
            backgroundColor:
                isHighContrast ? const Color(0xFF1E2430) : bgIconColor,
            child: Icon(
              icon,
              color: isHighContrast
                  ? (iconColor == const Color(0xFFDC2626)
                      ? const Color(0xFFFCA5A5)
                      : const Color(0xFF80CBC4))
                  : iconColor,
              size: 14,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: textSecondary,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: textPrimary,
                  ),
                ),
                const SizedBox(width: 4),
                Text(
                  unit,
                  style: TextStyle(
                    fontSize: 11,
                    color: textSecondary,
                    fontWeight: FontWeight.w500,
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
