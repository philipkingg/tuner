import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import '../../models/trace_point.dart';
import '../painters/rolling_roll_painter.dart';

class RollingVisualizer extends StatefulWidget {
  final List<TracePoint> history;
  final double currentCents;
  final double centerNoteIndex;
  final double zoom;
  final double scrollSpeed;
  final List<String> filteredNotes;
  final Color gridLineColor;
  final Color gridLineActiveColor;

  const RollingVisualizer({
    super.key,
    required this.history,
    required this.currentCents,
    required this.centerNoteIndex,
    required this.zoom,
    required this.scrollSpeed,
    required this.filteredNotes,
    this.gridLineColor = const Color(0xFF3D2D1F),
    this.gridLineActiveColor = const Color(0xFFC8892F),
  });

  @override
  State<RollingVisualizer> createState() => _RollingVisualizerState();
}

class _RollingVisualizerState extends State<RollingVisualizer>
    with SingleTickerProviderStateMixin {
  late Ticker _ticker;
  late final ValueNotifier<int> _repaintNotifier;

  @override
  void initState() {
    super.initState();
    _repaintNotifier = ValueNotifier(0);
    _ticker = createTicker((_) {
      _repaintNotifier.value++;
    });
    _ticker.start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    _repaintNotifier.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return CustomPaint(
          size: Size(constraints.maxWidth, constraints.maxHeight),
          painter: RollingRollPainter(
            widget.history,
            widget.centerNoteIndex,
            widget.zoom,
            widget.filteredNotes,
            scrollSpeed: widget.scrollSpeed,
            currentCents: widget.currentCents,
            gridLineColor: widget.gridLineColor,
            gridLineActiveColor: widget.gridLineActiveColor,
            repaint: _repaintNotifier,
          ),
        );
      },
    );
  }
}
