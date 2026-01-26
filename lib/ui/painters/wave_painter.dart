import 'package:flutter/material.dart';

class WavePainter extends CustomPainter {
  final List<double> points;
  WavePainter(this.points);
  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty) return;
    final path = Path()..moveTo(0, size.height / 2);
    for (var i = 0; i < points.length; i++) {
        path.lineTo(size.width * (i / points.length), (size.height / 2) + (points[i] * size.height / 2));
    }
    canvas.drawPath(path, Paint()..color = Colors.blueAccent..strokeWidth = 3.0..style = PaintingStyle.stroke);
  }
  @override bool shouldRepaint(covariant CustomPainter old) => true;
}
