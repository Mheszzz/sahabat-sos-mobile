import 'package:flutter/material.dart';
import 'package:sahabat_sos_mobile/core/services/accessibility_service.dart';

/// Helper and extension for dynamic accessible theme colors.
/// Adheres to High Contrast mode requirements:
/// - Background Kartu: isHighContrast ? Color(0xFF121212) : Colors.white
/// - Border Kartu: isHighContrast ? Color(0xFF4B5563) (1.5px) : Color(0xFFE5E7EB) (1px)
/// - Teks Utama: isHighContrast ? Colors.white : Color(0xFF1F2937)
/// - Teks Sekunder: isHighContrast ? Color(0xFFD1D5DB) : Color(0xFF6B7280)
class AccessibleColors {
  const AccessibleColors._();

  static Color cardBackground(bool isHighContrast) =>
      isHighContrast ? const Color(0xFF121212) : Colors.white;

  static Color cardBorderColor(bool isHighContrast) =>
      isHighContrast ? const Color(0xFF4B5563) : const Color(0xFFE5E7EB);

  static double cardBorderWidth(bool isHighContrast) =>
      isHighContrast ? 1.5 : 1.0;

  static Border cardBorder(bool isHighContrast) => Border.all(
        color: cardBorderColor(isHighContrast),
        width: cardBorderWidth(isHighContrast),
      );

  static Color textPrimary(bool isHighContrast) =>
      isHighContrast ? Colors.white : const Color(0xFF1F2937);

  static Color textSecondary(bool isHighContrast) =>
      isHighContrast ? const Color(0xFFD1D5DB) : const Color(0xFF6B7280);

  static Color fieldBackground(bool isHighContrast) =>
      isHighContrast ? const Color(0xFF1E2430) : const Color(0xFFF3F4F6);

  static Color scaffoldBackground(bool isHighContrast) =>
      isHighContrast ? Colors.black : const Color(0xFFF8FAFC);

  static Color primaryTeal(bool isHighContrast) =>
      isHighContrast ? const Color(0xFF26A69A) : const Color(0xFF00695C);

  static Color accentColor(bool isHighContrast) =>
      isHighContrast ? const Color(0xFF80CBC4) : const Color(0xFF00695C);

  static Color navBarBackground(bool isHighContrast) =>
      isHighContrast ? const Color(0xFF121212) : Colors.white.withValues(alpha: 0.95);

  static Color navBarBorderColor(bool isHighContrast) =>
      isHighContrast ? const Color(0xFF4B5563) : Colors.white.withValues(alpha: 0.6);
}

extension AccessibleThemeContextExtension on BuildContext {
  bool get isHighContrast =>
      AccessibilityService.instance.isHighContrastEnabled ||
      Theme.of(this).brightness == Brightness.dark ||
      MediaQuery.of(this).highContrast;

  Color get cardBackground => AccessibleColors.cardBackground(isHighContrast);
  Color get cardBorderColor => AccessibleColors.cardBorderColor(isHighContrast);
  double get cardBorderWidth => AccessibleColors.cardBorderWidth(isHighContrast);
  Border get cardBorder => AccessibleColors.cardBorder(isHighContrast);
  Color get textPrimary => AccessibleColors.textPrimary(isHighContrast);
  Color get textSecondary => AccessibleColors.textSecondary(isHighContrast);
  Color get fieldBackground => AccessibleColors.fieldBackground(isHighContrast);
  Color get scaffoldBackground => AccessibleColors.scaffoldBackground(isHighContrast);
  Color get primaryTeal => AccessibleColors.primaryTeal(isHighContrast);
  Color get navBarBackground => AccessibleColors.navBarBackground(isHighContrast);
}
