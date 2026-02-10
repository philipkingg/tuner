import 'dart:ui' as ui;
import 'dart:typed_data';
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

    // Vertex Generation Data
    final List<Offset> vertices = [];
    final List<Color> colors = [];
    final float32Indices = <int>[];

    // Helper to get screen coordinates
    Offset getPointPos(int index) {
      TracePoint p = points[index];
      double age = currentTimestamp - p.timestamp;
      double y =
          drawingHeight -
          AppConstants.rollingWaveRecentOffset -
          (age * pixelsPerMs);
      double x = midX + ((p.note - centerNoteIndex) * stepX);
      return Offset(x, y);
    }

    // Temporary list to hold high-res central path points + color
    final List<Map<String, dynamic>> pathPoints = [];

    // Helper to add point to path
    void addPathPoint(Offset pos, double cents) {
      pathPoints.add({'pos': pos, 'cents': cents});
    }

    // --- Generate High-Res Path ---

    for (int i = 0; i < points.length - 1; i++) {
      // Start Segment (Linear)
      if (i == 0) {
        Offset p0 = getPointPos(0);
        Offset p1 = getPointPos(1);
        Offset mid01 = (p0 + p1) / 2.0;

        // Linear subdivision P0 -> Mid01
        const int sub = 5;
        for (int s = 0; s <= sub; s++) {
          // 0 to sub inclusive
          double t = s / sub;
          double x = p0.dx + (mid01.dx - p0.dx) * t;
          double y = p0.dy + (mid01.dy - p0.dy) * t;
          double c =
              points[0].cents + (points[1].cents - points[0].cents) * (t * 0.5);
          addPathPoint(Offset(x, y), c);
        }
        // If only 2 points, finish to p1
        if (points.length == 2) {
          for (int s = 1; s <= sub; s++) {
            double t = s / sub;
            double x = mid01.dx + (p1.dx - mid01.dx) * t;
            double y = mid01.dy + (p1.dy - mid01.dy) * t;
            addPathPoint(Offset(x, y), points[1].cents);
          }
        }
      } else {
        // Spline Segments
        Offset pPrev = getPointPos(i - 1);
        Offset pCurr = getPointPos(i);
        Offset pNext = getPointPos(i + 1);

        if (pPrev.dy < -50 && pCurr.dy < -50 && pNext.dy < -50) continue;
        if (pPrev.dy > drawingHeight + 50 &&
            pCurr.dy > drawingHeight + 50 &&
            pNext.dy > drawingHeight + 50)
          continue;

        Offset midPrev = (pPrev + pCurr) / 2.0;
        Offset midNext = (pCurr + pNext) / 2.0;

        double startCents = (points[i - 1].cents + points[i].cents) / 2.0;
        double endCents = (points[i].cents + points[i + 1].cents) / 2.0;

        const int sub = 10;
        // Subdivide Curve
        for (int s = 1; s <= sub; s++) {
          double t = s / sub;
          double invT = 1 - t;
          // Quadratic Bezier
          double x =
              (invT * invT * midPrev.dx) +
              (2 * invT * t * pCurr.dx) +
              (t * t * midNext.dx);
          double y =
              (invT * invT * midPrev.dy) +
              (2 * invT * t * pCurr.dy) +
              (t * t * midNext.dy);

          // Linear cents interp?
          // Or Quadratic? Let's use linear for now.
          double c = startCents + (endCents - startCents) * t;
          // Technically we pass through pCurr control point? No, curve doesn't pass through control point.

          addPathPoint(Offset(x, y), c);
        }

        if (i == points.length - 2) {
          // Finish to P(N-1)
          Offset lastP = pNext;
          const int sub = 5;
          for (int s = 1; s <= sub; s++) {
            double t = s / sub;
            double x = midNext.dx + (lastP.dx - midNext.dx) * t;
            double y = midNext.dy + (lastP.dy - midNext.dy) * t;
            addPathPoint(Offset(x, y), points[i + 1].cents);
          }
        }
      }
    }

    // --- Generate Triangle Strip ---
    if (pathPoints.isEmpty) return;

    double halfWidth = AppConstants.rollingWaveStrokeWidth / 2.0;

    for (int i = 0; i < pathPoints.length; i++) {
      Offset current = pathPoints[i]['pos'] as Offset;
      Offset tangent;

      if (i < pathPoints.length - 1) {
        tangent = (pathPoints[i + 1]['pos'] as Offset) - current;
      } else if (i > 0) {
        tangent = current - (pathPoints[i - 1]['pos'] as Offset);
      } else {
        tangent = const Offset(0, 1); // Fallback
      }

      if (tangent.distance == 0)
        tangent = const Offset(0, 1);
      else
        tangent = tangent / tangent.distance; // Normalize

      // Normal vector (-y, x)
      Offset normal = Offset(-tangent.dy, tangent.dx);

      Offset vLeft = current + normal * halfWidth;
      Offset vRight = current - normal * halfWidth;

      // Calculate Color/Alpha
      double cents = pathPoints[i]['cents'] as double;
      double alpha = (current.dy / AppConstants.rollingWaveFadeTopHeight).clamp(
        0.0,
        1.0,
      );
      Color c = _getColor(cents).withValues(alpha: alpha);

      vertices.add(vLeft);
      vertices.add(vRight);
      colors.add(c);
      colors.add(c);

      // Add indices for 2 triangles forming a quad (strip)
      // Vertices added: 2*i, 2*i+1
      // Previous were: 2*(i-1), 2*(i-1)+1
      if (i > 0) {
        int base = (i - 1) * 2;
        // Triangle 1: Base, Base+1, Base+2
        float32Indices.add(base);
        float32Indices.add(base + 1);
        float32Indices.add(base + 2);
        // Triangle 2: Base+1, Base+3, Base+2
        float32Indices.add(base + 1);
        float32Indices.add(base + 3);
        float32Indices.add(base + 2);
      }
    }

    final verticesObj = ui.Vertices(
      ui.VertexMode.triangles,
      vertices,
      colors: colors,
      indices: Int32List.fromList(float32Indices),
    );

    canvas.drawVertices(verticesObj, BlendMode.srcOver, Paint());

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
