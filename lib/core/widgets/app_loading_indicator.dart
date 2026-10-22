import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:sahabat_sos_mobile/core/services/accessibility_service.dart';

/// Komponen animasi loading standar Sahabat SOS
/// Mengikuti standar halaman Beranda Relawan: CupertinoActivityIndicator(radius: 16)
class AppLoadingIndicator extends StatelessWidget {
  final double radius;
  final Color? color;

  const AppLoadingIndicator({
    super.key,
    this.radius = 16.0,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: CupertinoActivityIndicator(
        radius: radius,
        color: color,
      ),
    );
  }
}

/// Layar loading penuh (Full-screen loading)
/// Sesuai dengan tampilan loading halaman Beranda Relawan
class AppLoadingScreen extends StatelessWidget {
  final Color? backgroundColor;
  final double radius;

  const AppLoadingScreen({
    super.key,
    this.backgroundColor,
    this.radius = 16.0,
  });

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: AccessibilityService.instance,
      builder: (context, _) {
        final isHighContrast =
            AccessibilityService.instance.isHighContrastEnabled ||
            Theme.of(context).brightness == Brightness.dark ||
            MediaQuery.of(context).highContrast;
        final bg = backgroundColor ??
            (isHighContrast ? Colors.black : const Color(0xFFF5F6F8));

        return Scaffold(
          backgroundColor: bg,
          body: Center(
            child: CupertinoActivityIndicator(
              radius: radius,
              color: isHighContrast ? const Color(0xFF80CBC4) : null,
            ),
          ),
        );
      },
    );
  }
}
