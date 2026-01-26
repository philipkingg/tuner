import 'package:flutter/material.dart';

class CentsMeterPainter extends CustomPainter {
  final double cents;
  CentsMeterPainter(this.cents);
  @override
  void paint(Canvas canvas, Size size) {
    final double midX = size.width / 2;
    canvas.drawLine(Offset(0, size.height / 2), Offset(size.width, size.height / 2), Paint()..color = Colors.white12..strokeWidth = 2);
    for (int i = -50; i <= 50; i += 10) {
      double x = midX + (i / 50.0) * midX;
      canvas.drawLine(Offset(x, (size.height / 2) - 5), Offset(x, (size.height / 2) + 5), Paint()..color = i == 0 ? Colors.white70 : Colors.white24..strokeWidth = i == 0 ? 2 : 1);
    }
    double needleX = midX + (cents.clamp(-50, 50) / 50.0) * midX;
    canvas.drawLine(Offset(needleX, 0), Offset(needleX, size.height), Paint()..color = (cents.abs() < 5 ? Colors.greenAccent : (cents.abs() < 20 ? Colors.yellowAccent : Colors.redAccent))..strokeWidth = 3);
  }
  @override bool shouldRepaint(CentsMeterPainter old) => old.cents != cents;
}
