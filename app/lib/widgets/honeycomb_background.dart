import 'dart:math';
import 'package:flutter/material.dart';

class HoneycombBackground extends StatelessWidget {
  final Widget child;
  const HoneycombBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _HoneyPainter(),
      child: child,
    );
  }
}

class _HoneyPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    // Couleur très légère, comme le mock
    paint.color = Colors.black.withValues(alpha: 0.06);

    const r = 16.0; // rayon hex
    final w = r * 2;
    final h = sqrt(3) * r;

    for (double y = -h; y < size.height + h; y += h) {
      final isOdd = ((y / h).round().isOdd);
      for (double x = -w; x < size.width + w; x += w * 0.75) {
        final dx = x + (isOdd ? w * 0.375 : 0);
        _drawHex(canvas, Offset(dx, y), r, paint);
      }
    }
  }

  void _drawHex(Canvas canvas, Offset c, double r, Paint paint) {
    final path = Path();
    for (int i = 0; i < 6; i++) {
      final a = (pi / 3) * i + pi / 6;
      final p = Offset(c.dx + r * cos(a), c.dy + r * sin(a));
      if (i == 0) {
        path.moveTo(p.dx, p.dy);
      } else {
        path.lineTo(p.dx, p.dy);
      }
    }
    path.close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
