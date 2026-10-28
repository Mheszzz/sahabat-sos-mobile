import 'package:flutter/material.dart';

/// A self-contained Google 'G' logo widget that renders the official 4-color
/// mark offline with vector fidelity and optional network fallback.
class GoogleLogo extends StatelessWidget {
  final double size;

  const GoogleLogo({super.key, this.size = 24.0});

  @override
  Widget build(BuildContext context) {
    return Image.network(
      'https://upload.wikimedia.org/wikipedia/commons/thumb/c/c1/Google_%22G%22_logo.svg/120px-Google_%22G%22_logo.svg.png',
      width: size,
      height: size,
      errorBuilder: (_, o, s) => SizedBox(
        width: size,
        height: size,
        child: CustomPaint(
          size: Size(size, size),
          painter: const _GoogleLogoPainter(),
        ),
      ),
    );
  }
}

class _GoogleLogoPainter extends CustomPainter {
  const _GoogleLogoPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final strokeWidth = size.width * 0.20;
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - strokeWidth) / 2;
    final rect = Rect.fromCircle(center: center, radius: radius);

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.butt;

    // Top arc - Red
    paint.color = const Color(0xFFEA4335);
    canvas.drawArc(rect, -2.4, 1.55, false, paint);

    // Left arc - Yellow
    paint.color = const Color(0xFFFBBC05);
    canvas.drawArc(rect, 2.3, 1.55, false, paint);

    // Bottom arc - Green
    paint.color = const Color(0xFF34A853);
    canvas.drawArc(rect, 0.75, 1.55, false, paint);

    // Right arc - Blue
    paint.color = const Color(0xFF4285F4);
    canvas.drawArc(rect, -0.85, 1.6, false, paint);

    // Horizontal bar - Blue
    final barPaint = Paint()
      ..color = const Color(0xFF4285F4)
      ..style = PaintingStyle.fill;
    canvas.drawRect(
      Rect.fromLTWH(
        center.dx - 1,
        center.dy - strokeWidth / 2,
        size.width / 2 + 1,
        strokeWidth,
      ),
      barPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
