import 'dart:math';
import 'package:flutter/material.dart';
import '../../utils/note_utils.dart';

class RollingRollPainter extends CustomPainter {
  final List<Point<double>> history;
  final double centerNoteIndex;
  final double zoom;
  final List<String> filteredNotes;
  RollingRollPainter(this.history, this.centerNoteIndex, this.zoom, this.filteredNotes);

  // Restored Color Blending Logic
  Color _getColor(double cents) {
    double absCents = cents.abs();
    if (absCents < 5) return Colors.greenAccent;
    if (absCents < 20) return Color.lerp(Colors.greenAccent, Colors.yellowAccent, (absCents - 5) / 15)!;
    return Color.lerp(Colors.yellowAccent, Colors.redAccent, ((absCents - 20) / 30).clamp(0.0, 1.0))!;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final double midX = size.width / 2;
    final double stepX = (size.width / 2) * zoom;
    final double drawingHeight = size.height - 40.0;

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
        _drawSingleLine(canvas, NoteUtils.noteToN(noteStr), midX, stepX, drawingHeight);
      }
    }

    if (history.isEmpty) return;

    // Draw the multi-colored path
    final Paint linePaint = Paint()
      ..strokeWidth = 3.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    // We draw segments to allow the color to change along the line
    for (int i = 0; i < history.length - 1; i++) {
      double x1 = midX + ((history[i].y - centerNoteIndex) * stepX);
      double y1 = drawingHeight - (i * (drawingHeight / 120));
      double x2 = midX + ((history[i+1].y - centerNoteIndex) * stepX);
      double y2 = drawingHeight - ((i + 1) * (drawingHeight / 120));

      linePaint.color = _getColor(history[i].x);
      canvas.drawLine(Offset(x1, y1), Offset(x2, y2), linePaint);
    }

    // Draw Center Guide Line
    canvas.drawLine(Offset(midX, 0), Offset(midX, drawingHeight), Paint()..color = Colors.white24..strokeWidth = 1.5);
  }

  void _drawSingleLine(Canvas canvas, double n, double midX, double stepX, double drawingHeight) {
    double xPos = midX + ((n - centerNoteIndex) * stepX);
    if (xPos < -80 || xPos > midX * 2 + 80) return;
    bool isActive = (n - centerNoteIndex).abs() < 0.2;
    canvas.drawLine(Offset(xPos, 0), Offset(xPos, drawingHeight), Paint()
      ..color = isActive ? Colors.blueAccent.withValues(alpha: 0.6) : Colors.white.withValues(alpha: 0.08)
      ..strokeWidth = isActive ? 3 : 1);

    int noteIdx = ((n + 57) % 12).toInt();
    int oct = ((n + 57) / 12).floor();
    String label = "${NoteUtils.noteNames[noteIdx]}$oct";

    TextPainter(text: TextSpan(text: label, style: TextStyle(color: isActive ? Colors.blueAccent : Colors.white24, fontSize: isActive ? 14 : 11, fontWeight: FontWeight.bold)), textDirection: TextDirection.ltr)
      ..layout()..paint(canvas, Offset(xPos - 8, drawingHeight + 5));
  }
  @override bool shouldRepaint(RollingRollPainter old) => true;
}
