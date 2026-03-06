import 'package:flutter/material.dart';

class WavePainter extends CustomPainter {
  final List<double> points;
  final Color color;

  WavePainter(this.points, {this.color = const Color(0xFFC8892F)});

  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty) return;
    final path = Path()..moveTo(0, size.height / 2);
    for (var i = 0; i < points.length; i++) {
      path.lineTo(
        size.width * (i / points.length),
        (size.height / 2) + (points[i] * size.height / 2),
      );
    }
    // Glow layer
    canvas.drawPath(
      path,
      Paint()
        ..color = color.withValues(alpha: 0.25)
        ..strokeWidth = 6.0
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round,
    );
    // Main line
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..strokeWidth = 2.0
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(covariant WavePainter old) =>
      old.points != points || old.color != color;
}
