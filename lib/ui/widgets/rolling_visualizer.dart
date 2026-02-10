import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import '../../models/trace_point.dart';
import '../painters/rolling_roll_painter.dart';

class RollingVisualizer extends StatefulWidget {
  final List<TracePoint> history;
  final double currentCents;
  final double centerNoteIndex; // Added this parameter to match painter needs
  final double zoom;
  final double scrollSpeed;
  final List<String> filteredNotes;

  const RollingVisualizer({
    super.key,
    required this.history,
    required this.currentCents,
    required this.centerNoteIndex,
    required this.zoom,
    required this.scrollSpeed,
    required this.filteredNotes,
  });

  @override
  State<RollingVisualizer> createState() => _RollingVisualizerState();
}

class _RollingVisualizerState extends State<RollingVisualizer>
    with SingleTickerProviderStateMixin {
  late Ticker _ticker;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker((elapsed) {
      if (mounted) setState(() {});
    });
    _ticker.start();
  }

  @override
  void dispose() {
    _ticker.dispose();
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
            currentTimestamp: DateTime.now().millisecondsSinceEpoch.toDouble(),
            currentCents: widget.currentCents,
          ),
        );
      },
    );
  }
}
