import 'package:flutter/material.dart';
import '../../utils/note_utils.dart';
import '../../models/trace_point.dart';

class RollingRollPainter extends CustomPainter {
  final List<TracePoint> history;
  final double centerNoteIndex;
  final double zoom;
  final List<String> filteredNotes;
  final double scrollSpeed;
  final double currentTimestamp;
  final double currentCents;

  RollingRollPainter(
    this.history,
    this.centerNoteIndex,
    this.zoom,
    this.filteredNotes, {
    this.scrollSpeed = 1.0,
    required this.currentTimestamp,
    required this.currentCents,
  });

  Color _getColor(double cents) {
    double absCents = cents.abs();
    if (absCents < 5) return Colors.greenAccent;
    if (absCents < 20)
      return Color.lerp(
        Colors.greenAccent,
        Colors.yellowAccent,
        (absCents - 5) / 15,
      )!;
    return Color.lerp(
      Colors.yellowAccent,
      Colors.redAccent,
      ((absCents - 20) / 30).clamp(0.0, 1.0),
    )!;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final double midX = size.width / 2;
    final double stepX = (size.width / 2) * zoom;
    final double drawingHeight = size.height;

    // Calculate speed factor pixels per millisecond
    // Base speed: 120 points fill the screen height at 1.0 speed
    // If we assume a point usually comes every ~20-50ms?
    // Let's calibrate:
    // Old logic: stepY = drawingHeight / (120 / scrollSpeed);
    // If update rate is approx 60Hz (16ms) -> too fast?
    // Tuner updates are likely slower, maybe 20-30Hz.
    // Let's aim for: 1 second of history takes up X height.
    // If scrollSpeed 1.0 -> 5 seconds of history visible?
    final double visibleDurationMs = 5000 / scrollSpeed;
    final double pixelsPerMs = drawingHeight / visibleDurationMs;

    // Draw Grid
    if (filteredNotes.isEmpty) {
      int range = (3 / zoom).ceil().clamp(3, 24);
      int startN = (centerNoteIndex - range).floor();
      int endN = (centerNoteIndex + range).ceil();
      for (int n = startN; n <= endN; n++) {
        _drawSingleLine(canvas, n.toDouble(), midX, stepX, drawingHeight);
      }
    } else {
      for (var noteStr in filteredNotes) {
        _drawSingleLine(
          canvas,
          NoteUtils.noteToN(noteStr),
          midX,
          stepX,
          drawingHeight,
        );
      }
    }

    // Live Point Logic: Prepend live point twice to allow smoothing from the very tip
    // If history is empty, we just have the live point, so we need to handle that.
    final TracePoint livePoint = TracePoint(
      cents: currentCents,
      note: centerNoteIndex,
      timestamp: currentTimestamp.toInt(),
    );

    final List<TracePoint> paintList = [livePoint, livePoint, ...history];

    if (paintList.length < 2) return;

    final Paint linePaint =
        Paint()
          ..strokeWidth = 3.5
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round;

    for (int i = 0; i < paintList.length - 1; i++) {
      // Calculate Y based on constant time
      double age1 = currentTimestamp - paintList[i].timestamp;
      double age2 = currentTimestamp - paintList[i + 1].timestamp;

      double y1 = drawingHeight - 40 - (age1 * pixelsPerMs);
      double y2 = drawingHeight - 40 - (age2 * pixelsPerMs);

      // Clip if out of bounds (optimization)
      if (y1 < -50 && y2 < -50) continue;
      if (y1 > drawingHeight + 50 && y2 > drawingHeight + 50) continue;

      double x1 = midX + ((paintList[i].note - centerNoteIndex) * stepX);
      double x2 = midX + ((paintList[i + 1].note - centerNoteIndex) * stepX);

      if (i == 0)
        continue; // Skip first segment to have prev point for smoothing

      // Previous Data for Smoothing
      double age0 = currentTimestamp - paintList[i - 1].timestamp;
      double y0 = drawingHeight - 40 - (age0 * pixelsPerMs);
      double x0 = midX + ((paintList[i - 1].note - centerNoteIndex) * stepX);

      // Midpoints
      double midX1 = (x0 + x1) / 2;
      double midY1 = (y0 + y1) / 2;

      double midX2 = (x1 + x2) / 2;
      double midY2 = (y1 + y2) / 2;

      final path = Path();
      path.moveTo(midX1, midY1);
      path.quadraticBezierTo(x1, y1, midX2, midY2);

      linePaint.color = _getColor(paintList[i].cents);
      canvas.drawPath(path, linePaint);
    }

    // Draw Center Guide Line
    canvas.drawLine(
      Offset(midX, 0),
      Offset(midX, drawingHeight),
      Paint()
        ..color = Colors.white24
        ..strokeWidth = 1.5,
    );
  }

  void _drawSingleLine(
    Canvas canvas,
    double n,
    double midX,
    double stepX,
    double drawingHeight,
  ) {
    double xPos = midX + ((n - centerNoteIndex) * stepX);
    if (xPos < -80 || xPos > midX * 2 + 80) return;
    bool isActive = (n - centerNoteIndex).abs() < 0.2;
    canvas.drawLine(
      Offset(xPos, 0),
      Offset(xPos, drawingHeight),
      Paint()
        ..color =
            isActive
                ? Colors.blueAccent.withValues(alpha: 0.6)
                : Colors.white.withValues(alpha: 0.08)
        ..strokeWidth = isActive ? 3 : 1,
    );

    int noteIdx = ((n + 57) % 12).toInt();
    int oct = ((n + 57) / 12).floor();
    String label = "${NoteUtils.noteNames[noteIdx]}$oct";

    TextPainter(
        text: TextSpan(
          text: label,
          style: TextStyle(
            color: isActive ? Colors.blueAccent : Colors.white24,
            fontSize: isActive ? 14 : 11,
            fontWeight: FontWeight.bold,
          ),
        ),
        textDirection: TextDirection.ltr,
      )
      ..layout()
      ..paint(canvas, Offset(xPos - 8, drawingHeight - 30));
  }

  @override
  bool shouldRepaint(RollingRollPainter old) {
    return old.currentTimestamp != currentTimestamp ||
        old.centerNoteIndex != centerNoteIndex ||
        old.zoom != zoom ||
        old.history != history;
  }
}
