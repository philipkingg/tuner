import 'package:flutter/material.dart';

class CentsMeterPainter extends CustomPainter {
  final double cents;
  final Color trackColor;
  final Color inTuneColor;

  CentsMeterPainter(
    this.cents, {
    this.trackColor = const Color(0xFF3D2D1F),
    this.inTuneColor = const Color(0xFFD4A853),
  });

  Color _needleColor() {
    final abs = cents.abs();
    if (abs < 5) return inTuneColor;
    if (abs < 20) {
      return Color.lerp(inTuneColor, Colors.yellowAccent, (abs - 5) / 15)!;
    }
    return Color.lerp(
      Colors.yellowAccent,
      Colors.redAccent,
      ((abs - 20) / 30).clamp(0.0, 1.0),
    )!;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final double midX = size.width / 2;
    final double midY = size.height / 2;
    final Paint trackPaint = Paint()
      ..color = trackColor
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;

    // Track line
    canvas.drawLine(
      Offset(8, midY),
      Offset(size.width - 8, midY),
      trackPaint,
    );

    // Tick marks
    for (int i = -50; i <= 50; i += 10) {
      final double x = midX + (i / 50.0) * (midX - 8);
      final bool isCenter = i == 0;
      final double tickHeight = isCenter ? 10.0 : 6.0;
      canvas.drawLine(
        Offset(x, midY - tickHeight / 2),
        Offset(x, midY + tickHeight / 2),
        Paint()
          ..color = isCenter
              ? trackColor.withValues(alpha: 0.8)
              : trackColor.withValues(alpha: 0.5)
          ..strokeWidth = isCenter ? 2.0 : 1.0
          ..strokeCap = StrokeCap.round,
      );
    }

    // Needle
    final double needleX = midX + (cents.clamp(-50, 50) / 50.0) * (midX - 8);
    final Color needleColor = _needleColor();

    // Needle glow
    canvas.drawLine(
      Offset(needleX, 2),
      Offset(needleX, size.height - 2),
      Paint()
        ..color = needleColor.withValues(alpha: 0.25)
        ..strokeWidth = 7
        ..strokeCap = StrokeCap.round,
    );

    // Needle main line
    canvas.drawLine(
      Offset(needleX, 2),
      Offset(needleX, size.height - 2),
      Paint()
        ..color = needleColor
        ..strokeWidth = 2.5
        ..strokeCap = StrokeCap.round,
    );

    // Needle dot at center-Y
    canvas.drawCircle(
      Offset(needleX, midY),
      4,
      Paint()..color = needleColor,
    );
  }

  @override
  bool shouldRepaint(CentsMeterPainter old) =>
      old.cents != cents ||
      old.trackColor != trackColor ||
      old.inTuneColor != inTuneColor;
}
