import 'package:flutter/material.dart';
import '../../models/spectral_frame.dart';
import '../../utils/note_utils.dart';
import '../../utils/app_constants.dart';

class SpectrographPainter extends CustomPainter {
  final List<SpectralFrame> frames;
  final double scrollOffsetN;
  final Color primaryColor;
  final Color backgroundColor;

  static const double labelWidth = 46.0;
  static const double rightPadding = 46.0; // symmetric buffer on the right
  static const double topFadeHeight = 52.0;
  static const int visibleSemitones = AppConstants.spectroDefaultVisibleSemitones;

  // Classic spectrograph heatmap: silence → cool → warm → peak
  static const List<Color> _heatmap = [
    Color(0xFF000000), // 0.00 — black (silence)
    Color(0xFF06052A), // 0.15 — dark indigo
    Color(0xFF0A2278), // 0.30 — deep navy
    Color(0xFF0060B0), // 0.46 — cobalt blue
    Color(0xFF00A8C0), // 0.60 — cyan-teal
    Color(0xFF48D080), // 0.74 — seafoam green
    Color(0xFFD4E020), // 0.86 — yellow-green
    Color(0xFFFF8800), // 0.94 — amber-orange
    Color(0xFFFFFFFF), // 1.00 — white (peak)
  ];
  static const List<double> _stops = [
    0.00, 0.15, 0.30, 0.46, 0.60, 0.74, 0.86, 0.94, 1.00
  ];

  SpectrographPainter({
    required this.frames,
    required this.scrollOffsetN,
    required this.primaryColor,
    required this.backgroundColor,
    Listenable? repaint,
  }) : super(repaint: repaint);

  Color _mapAmplitude(double v) {
    v = v.clamp(0.0, 1.0);
    for (int i = 0; i < _stops.length - 1; i++) {
      if (v <= _stops[i + 1]) {
        final double t = (v - _stops[i]) / (_stops[i + 1] - _stops[i]);
        return Color.lerp(_heatmap[i], _heatmap[i + 1], t)!;
      }
    }
    return _heatmap.last;
  }

  @override
  void paint(Canvas canvas, Size size) {
    // Content area sits between the left label strip and right padding strip
    final double contentLeft = labelWidth;
    final double contentRight = size.width - rightPadding;
    final double contentWidth = contentRight - contentLeft;
    final double cellHeight = size.height / visibleSemitones;

    // Bottom note with sub-semitone offset for smooth scrolling
    final int bottomN = scrollOffsetN.floor();
    final double subOffset = scrollOffsetN - bottomN;

    final int rowCount = visibleSemitones + 1;
    final List<double> rowYTop = List<double>.generate(rowCount, (si) {
      return size.height - (si + 1 - subOffset) * cellHeight;
    });
    final List<double> rowYBottom = List<double>.generate(rowCount, (si) {
      return size.height - (si - subOffset) * cellHeight;
    });

    // Newest frames anchor to the right (contentRight), older extend left
    final int maxColumns = contentWidth.toInt().clamp(1, frames.length + 1);
    final List<SpectralFrame> displayFrames = frames.length > maxColumns
        ? frames.sublist(frames.length - maxColumns)
        : frames;
    final int numFrames = displayFrames.length;
    final double colWidth = contentWidth / maxColumns;

    // Black-key row tint behind the spectrogram
    final Paint sharpPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.025);
    const List<int> sharpIndices = [1, 3, 6, 8, 10];
    for (int si = 0; si < rowCount; si++) {
      final int noteIdx = ((bottomN + si + 57) % 12 + 12) % 12;
      if (sharpIndices.contains(noteIdx)) {
        final double top = rowYTop[si].clamp(0.0, size.height);
        final double bot = rowYBottom[si].clamp(0.0, size.height);
        if (bot > top) {
          canvas.drawRect(
            Rect.fromLTRB(contentLeft, top, contentRight, bot),
            sharpPaint,
          );
        }
      }
    }

    // Clip to content area and draw spectral cells
    canvas.save();
    canvas.clipRect(Rect.fromLTRB(contentLeft, 0, contentRight, size.height));

    final Paint cellPaint = Paint();
    for (int fi = 0; fi < numFrames; fi++) {
      final SpectralFrame frame = displayFrames[fi];
      // fi=numFrames-1 is newest (at contentRight), fi=0 is oldest
      final double xStart =
          contentRight - (numFrames - fi) * colWidth;
      final double xEnd = xStart + colWidth + 0.5;

      for (int si = 0; si < rowCount; si++) {
        final double yTop = rowYTop[si];
        final double yBottom = rowYBottom[si];
        if (yBottom <= 0 || yTop >= size.height) continue;

        final int binIndex = (bottomN + si) - AppConstants.spectroMinN;
        if (binIndex < 0 || binIndex >= frame.magnitudes.length) continue;

        cellPaint.color = _mapAmplitude(frame.magnitudes[binIndex]);
        canvas.drawRect(
          Rect.fromLTRB(
            xStart,
            yTop.clamp(0.0, size.height),
            xEnd,
            yBottom.clamp(0.0, size.height),
          ),
          cellPaint,
        );
      }
    }

    canvas.restore();

    // Octave divider lines (C notes)
    final Paint octavePaint = Paint()
      ..color = primaryColor.withValues(alpha: 0.18)
      ..strokeWidth = 0.5;
    for (int si = 0; si < rowCount; si++) {
      if (((bottomN + si + 57) % 12 + 12) % 12 == 0) {
        final double y = rowYBottom[si].clamp(0.0, size.height);
        canvas.drawLine(Offset(0, y), Offset(size.width, y), octavePaint);
      }
    }

    // Loudest note highlight line
    if (frames.isNotEmpty) {
      final int loudestN =
          AppConstants.spectroMinN + frames.last.loudestBin;
      final int si = loudestN - bottomN;
      if (si >= 0 && si < rowCount) {
        final double midY = (rowYTop[si] + rowYBottom[si]) / 2;
        if (midY >= 0 && midY <= size.height) {
          canvas.drawLine(
            Offset(contentLeft, midY),
            Offset(contentRight, midY),
            Paint()
              ..color = Colors.white.withValues(alpha: 0.28)
              ..strokeWidth = 1.0,
          );
        }
      }
    }

    // "Now" line at the right edge of the content area
    canvas.drawLine(
      Offset(contentRight - 1.0, 0),
      Offset(contentRight - 1.0, size.height),
      Paint()
        ..color = primaryColor.withValues(alpha: 0.50)
        ..strokeWidth = 1.5,
    );

    // Top fade: gradient from backgroundColor → transparent
    final Rect fadeRect =
        Rect.fromLTWH(contentLeft, 0, contentWidth, topFadeHeight);
    canvas.drawRect(
      fadeRect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            backgroundColor,
            backgroundColor.withValues(alpha: 0),
          ],
        ).createShader(fadeRect),
    );

    // Left label background
    canvas.drawRect(
      Rect.fromLTWH(0, 0, labelWidth, size.height),
      Paint()..color = backgroundColor.withValues(alpha: 0.92),
    );

    // Right padding background (symmetric with left)
    canvas.drawRect(
      Rect.fromLTWH(contentRight, 0, rightPadding, size.height),
      Paint()..color = backgroundColor.withValues(alpha: 0.92),
    );

    // Label/content separator
    canvas.drawLine(
      Offset(labelWidth, 0),
      Offset(labelWidth, size.height),
      Paint()
        ..color = primaryColor.withValues(alpha: 0.18)
        ..strokeWidth = 0.5,
    );

    // Note labels in the left strip
    const List<int> naturalIndices = [0, 2, 4, 5, 7, 9, 11];
    for (int si = 0; si < rowCount; si++) {
      final int noteN = bottomN + si;
      final int noteIdx = ((noteN + 57) % 12 + 12) % 12;
      final int octave = (noteN + 57) ~/ 12;
      final bool isC = noteIdx == 0;
      final bool isNatural = naturalIndices.contains(noteIdx);

      if (!isC && (!isNatural || cellHeight < 11)) continue;

      final String label = isC ? 'C$octave' : NoteUtils.noteNames[noteIdx];

      final double midY = (rowYTop[si] + rowYBottom[si]) / 2;
      if (midY < 0 || midY > size.height) continue;

      final TextPainter tp = TextPainter(
        text: TextSpan(
          text: label,
          style: TextStyle(
            color: isC
                ? primaryColor.withValues(alpha: 0.90)
                : Colors.white.withValues(alpha: 0.30),
            fontSize: isC ? 11 : 9,
            fontWeight: isC ? FontWeight.w700 : FontWeight.w400,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();

      tp.paint(canvas, Offset(labelWidth - tp.width - 7, midY - tp.height / 2));
    }
  }

  @override
  bool shouldRepaint(SpectrographPainter old) {
    return old.frames != frames ||
        old.scrollOffsetN != scrollOffsetN ||
        old.primaryColor != primaryColor;
  }
}
