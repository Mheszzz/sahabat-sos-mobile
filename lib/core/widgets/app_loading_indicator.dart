import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

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
  final Color backgroundColor;
  final double radius;

  const AppLoadingScreen({
    super.key,
    this.backgroundColor = const Color(0xFFF5F6F8),
    this.radius = 16.0,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      body: Center(
        child: CupertinoActivityIndicator(radius: radius),
      ),
    );
  }
}
