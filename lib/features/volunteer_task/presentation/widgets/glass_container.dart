import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:sahabat_sos_mobile/core/services/accessibility_service.dart';

class GlassContainer extends StatelessWidget {
  final Widget child;
  final double blur;
  final double opacity;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final BorderRadius? borderRadius;
  final Border? border;
  final Color? color;

  const GlassContainer({
    super.key,
    required this.child,
    this.blur = 10.0,
    this.opacity = 0.2,
    this.padding,
    this.margin,
    this.borderRadius,
    this.border,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final isHighContrast =
        AccessibilityService.instance.isHighContrastEnabled ||
        Theme.of(context).brightness == Brightness.dark ||
        MediaQuery.of(context).highContrast;

    final effectiveColor = color ??
        (isHighContrast
            ? const Color(0xFF121212)
            : Colors.white.withValues(alpha: opacity));

    final effectiveBorder = border ??
        (isHighContrast
            ? Border.all(color: const Color(0xFF4B5563), width: 1.5)
            : Border.all(
                color: Colors.white.withValues(alpha: 0.5), width: 1.5));

    return Container(
      margin: margin,
      child: ClipRRect(
        borderRadius: borderRadius ?? BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
          child: Container(
            padding: padding,
            decoration: BoxDecoration(
              color: effectiveColor,
              borderRadius: borderRadius ?? BorderRadius.circular(20),
              border: effectiveBorder,
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}
