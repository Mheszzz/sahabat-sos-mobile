import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:sahabat_sos_mobile/core/theme/accessible_colors.dart';

class VolunteerQuickActions extends StatelessWidget {
  final VoidCallback onOpenMap;
  final VoidCallback onOpenTaskList;
  final VoidCallback onCall112;
  final VoidCallback onOpenSop;

  const VolunteerQuickActions({
    super.key,
    required this.onOpenMap,
    required this.onOpenTaskList,
    required this.onCall112,
    required this.onOpenSop,
  });

  @override
  Widget build(BuildContext context) {
    final isHighContrast = context.isHighContrast;
    final primaryTeal = AccessibleColors.primaryTeal(isHighContrast);
    final textPrimary = AccessibleColors.textPrimary(isHighContrast);
    const sosRed = Color(0xFFDC2626);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Aksi Cepat',
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
              child: _QuickActionButton(
                icon: CupertinoIcons.map_fill,
                label: 'Radar Peta',
                accentColor: primaryTeal,
                onTap: onOpenMap,
                isHighContrast: isHighContrast,
                textPrimary: textPrimary,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _QuickActionButton(
                icon: CupertinoIcons.doc_text_fill,
                label: 'Daftar Tugas',
                accentColor: const Color(0xFF1976D2),
                onTap: onOpenTaskList,
                isHighContrast: isHighContrast,
                textPrimary: textPrimary,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _QuickActionButton(
                icon: CupertinoIcons.phone_fill,
                label: 'Panggil 112',
                accentColor: sosRed,
                onTap: onCall112,
                isHighContrast: isHighContrast,
                textPrimary: textPrimary,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _QuickActionButton(
                icon: CupertinoIcons.book_fill,
                label: 'Panduan SOP',
                accentColor: const Color(0xFFD97706),
                onTap: onOpenSop,
                isHighContrast: isHighContrast,
                textPrimary: textPrimary,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _QuickActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color accentColor;
  final VoidCallback onTap;
  final bool isHighContrast;
  final Color textPrimary;

  const _QuickActionButton({
    required this.icon,
    required this.label,
    required this.accentColor,
    required this.onTap,
    required this.isHighContrast,
    required this.textPrimary,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AccessibleColors.cardBackground(isHighContrast),
      borderRadius: BorderRadius.circular(16),
      elevation: 0,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          constraints: const BoxConstraints(minHeight: 80),
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
          decoration: BoxDecoration(
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
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: isHighContrast
                      ? accentColor.withValues(alpha: 0.25)
                      : accentColor.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  icon,
                  color: isHighContrast
                      ? const Color(0xFF80CBC4)
                      : accentColor,
                  size: 20,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                label,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: textPrimary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
