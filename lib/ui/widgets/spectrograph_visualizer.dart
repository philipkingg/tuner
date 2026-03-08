import 'package:flutter/material.dart';
import '../../models/spectral_frame.dart';
import '../../utils/app_constants.dart';
import '../painters/spectrograph_painter.dart';

class SpectrographVisualizer extends StatefulWidget {
  final List<SpectralFrame> frames;
  final Color primaryColor;
  final Color backgroundColor;

  const SpectrographVisualizer({
    super.key,
    required this.frames,
    required this.primaryColor,
    required this.backgroundColor,
  });

  @override
  State<SpectrographVisualizer> createState() => _SpectrographVisualizerState();
}

class _SpectrographVisualizerState extends State<SpectrographVisualizer> {
  // N value of the bottom of the visible range (double for smooth scrolling)
  double _scrollOffsetN = AppConstants.spectroMinN.toDouble();
  bool _autoFollow = true;

  @override
  void didUpdateWidget(SpectrographVisualizer old) {
    super.didUpdateWidget(old);
    if (_autoFollow && widget.frames.isNotEmpty) {
      final int loudestBin = widget.frames.last.loudestBin;
      final int loudestN = AppConstants.spectroMinN + loudestBin;
      // Center the view on the loudest note
      final double targetBottom =
          loudestN - AppConstants.spectroDefaultVisibleSemitones / 2.0;
      final double clamped = targetBottom.clamp(
        AppConstants.spectroMinN.toDouble(),
        (AppConstants.spectroMaxN - AppConstants.spectroDefaultVisibleSemitones)
            .toDouble(),
      );
      // Smooth lerp — no extra setState needed since parent already rebuilding
      _scrollOffsetN = _scrollOffsetN + (clamped - _scrollOffsetN) * 0.06;
    }
  }

  void _onDragStart(DragStartDetails _) {
    setState(() => _autoFollow = false);
  }

  void _onDragUpdate(DragUpdateDetails details, double cellHeight) {
    // Standard scroll: drag up → content moves up → lower notes revealed
    final double delta = details.delta.dy / cellHeight;
    setState(() {
      _scrollOffsetN = (_scrollOffsetN + delta).clamp(
        AppConstants.spectroMinN.toDouble(),
        (AppConstants.spectroMaxN - AppConstants.spectroDefaultVisibleSemitones)
            .toDouble(),
      );
    });
  }

  void _onDragEnd(DragEndDetails _) {
    // Auto-follow only resumes when the user explicitly taps the Follow button
  }

  void _resumeAutoFollow() {
    setState(() => _autoFollow = true);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final double cellHeight =
            constraints.maxHeight / AppConstants.spectroDefaultVisibleSemitones;

        return GestureDetector(
          onVerticalDragStart: _onDragStart,
          onVerticalDragUpdate: (d) => _onDragUpdate(d, cellHeight),
          onVerticalDragEnd: _onDragEnd,
          child: Stack(
            children: [
              CustomPaint(
                size: Size(constraints.maxWidth, constraints.maxHeight),
                painter: SpectrographPainter(
                  frames: widget.frames,
                  scrollOffsetN: _scrollOffsetN,
                  primaryColor: widget.primaryColor,
                  backgroundColor: widget.backgroundColor,
                ),
              ),

              // Auto-follow indicator — tap to re-enable
              if (!_autoFollow)
                Positioned(
                  top: 10,
                  right: 10,
                  child: GestureDetector(
                    onTap: _resumeAutoFollow,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 9,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.72),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: widget.primaryColor.withValues(alpha: 0.45),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.my_location_rounded,
                            size: 11,
                            color: widget.primaryColor,
                          ),
                          const SizedBox(width: 5),
                          Text(
                            'Follow',
                            style: TextStyle(
                              color: widget.primaryColor,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.3,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
