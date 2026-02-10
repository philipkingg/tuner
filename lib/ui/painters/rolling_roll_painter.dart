import 'package:flutter/material.dart';
import '../../utils/note_utils.dart';
import '../../models/trace_point.dart';
import '../../utils/app_constants.dart';

class RollingRollPainter extends CustomPainter {
  final List<TracePoint> history;
  final double centerNoteIndex;
  final double zoom;
  final List<String> filteredNotes;
  final double scrollSpeed;
  final double currentTimestamp; // Added for time-based rendering
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
    final double visibleDurationMs =
        AppConstants.rollingWaveVisibleDurationMs / scrollSpeed;
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

    // Unified List: [Current, ...History]
    final TracePoint currentPoint = TracePoint(
      cents: currentCents,
      note:
          centerNoteIndex, // The pen is at the center index (current lerped note)
      timestamp: currentTimestamp.toInt(),
    );

    final List<TracePoint> points = [currentPoint, ...history];

    if (points.length < 2) return;

    final Paint linePaint =
        Paint()
          ..strokeWidth = AppConstants.rollingWaveStrokeWidth
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round;

    // We draw the trace in segments.
    // Segment 0: Line from Points[0] to Mid(0,1).
    // Segment i (i=1..N-2): Curve from Mid(i-1, i) to Mid(i, i+1) with Control(i).
    // Segment Last: Line from Mid(N-2, N-1) to Points[N-1] (optional, or just stop at mid).

    // Pre-calculate positions to avoid re-calc?
    // Given the dynamic culling, we calculate on the fly.

    // Helper to get screen coordinates
    Offset getPointPos(int index) {
      TracePoint p = points[index];
      double age = currentTimestamp - p.timestamp;
      // "Now" is at (drawingHeight - offset).
      // Older points move UP (y decreases).
      // y = (H - offset) - (age * speed)
      double y =
          drawingHeight -
          AppConstants.rollingWaveRecentOffset -
          (age * pixelsPerMs);
      double x = midX + ((p.note - centerNoteIndex) * stepX);
      return Offset(x, y);
    }

    // Draw first segment (Live tip linearity)
    // Actually, let's treat it as a loop.
    // We need at least 2 points.

    // We can maximize batching, but we change color per segment.
    // So we draw many small paths.

    for (int i = 0; i < points.length - 1; i++) {
      // We are processing segment between i and i+1?
      // No, the spline logic focuses on point 'i' as control point (except start/end).

      // Let's adopt the strategy:
      // Iterate i from 0 to N-2.
      // Draw the connection that covers the interval around point i+1?
      //
      // Standard Midpoint Spline:
      // Start at P0.
      // Line to Mid(P0, P1).
      // For j = 1 to N-2:
      //    Curve from Mid(P(j-1), Pj) to Mid(Pj, P(j+1)) using Pj as control.
      // Line from Mid(P(N-2), P(N-1)) to P(N-1).

      // Let's implement this loop.

      if (i == 0) {
        // Special Case: Start
        Offset p0 = getPointPos(0);
        Offset p1 = getPointPos(1);
        Offset mid01 = (p0 + p1) / 2.0;

        Path path = Path();
        path.moveTo(p0.dx, p0.dy);
        path.lineTo(mid01.dx, mid01.dy);

        linePaint.color = _getColor(points[0].cents);
        canvas.drawPath(path, linePaint);

        // If we only have 2 points, we also need to finish the line?
        if (points.length == 2) {
          Path endPath = Path();
          endPath.moveTo(mid01.dx, mid01.dy);
          endPath.lineTo(p1.dx, p1.dy);
          linePaint.color = _getColor(points[1].cents);
          canvas.drawPath(endPath, linePaint);
        }
      } else {
        // Interior segments (using points[i] as control point)
        // Corresponds to 'j' in explanation above.
        // i is the index of the Control Point.
        // We draw from Mid(i-1, i) to Mid(i, i+1).

        Offset pPrev = getPointPos(i - 1);
        Offset pCurr = getPointPos(i);
        Offset pNext = getPointPos(i + 1);

        // Optimization: Culling
        // If pCurr and pNext are way off screen, skip?
        // pCurr is the control point. The curve is near pCurr.
        // pNext helps define the endpoint.
        // y coords are decreasing.
        // If pCurr.dy < -50 (off top), and pNext.dy < -50, then this segment is off screen.
        // pPrev.dy is "newer" (lower on screen) than pCurr.
        // If pPrev is off screen (top), then pCurr is definitely off screen.

        if (pCurr.dy < -50 && pNext.dy < -50) continue;
        if (pCurr.dy > drawingHeight + 50 && pNext.dy > drawingHeight + 50)
          continue;

        Offset midPrev = (pPrev + pCurr) / 2.0;
        Offset midNext = (pCurr + pNext) / 2.0;

        Path path = Path();
        path.moveTo(midPrev.dx, midPrev.dy);
        path.quadraticBezierTo(pCurr.dx, pCurr.dy, midNext.dx, midNext.dy);

        linePaint.color = _getColor(points[i].cents);
        canvas.drawPath(path, linePaint);

        // Handle End of Line
        if (i == points.length - 2) {
          // This was the last curve (control point was second to last point).
          // We need to connect Mid(N-2, N-1) to P(N-1).
          Offset lastP = pNext; // points[i+1] which is points[N-1]
          Path endPath = Path();
          endPath.moveTo(midNext.dx, midNext.dy);
          endPath.lineTo(lastP.dx, lastP.dy);
          linePaint.color = _getColor(points[i + 1].cents);
          canvas.drawPath(endPath, linePaint);
        }
      }
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
