import 'package:flutter/material.dart';
import '../../models/visual_mode.dart';

class SettingsSheet extends StatefulWidget {
  final VisualMode visualMode;
  final double targetGain;
  final double sensitivity;
  final double smoothingSpeed;
  final double pianoRollZoom;
  final double traceLerpFactor;
  final double scrollSpeed;
  final ValueChanged<VisualMode> onVisualModeChanged;
  final ValueChanged<double> onTargetGainChanged;
  final ValueChanged<double> onSensitivityChanged;
  final ValueChanged<double> onSmoothingSpeedChanged;
  final ValueChanged<double> onPianoRollZoomChanged;
  final ValueChanged<double> onTraceLerpFactorChanged;
  final ValueChanged<double> onScrollSpeedChanged;
  final VoidCallback onResetToDefaults;

  const SettingsSheet({
    super.key,
    required this.visualMode,
    required this.targetGain,
    required this.sensitivity,
    required this.smoothingSpeed,
    required this.pianoRollZoom,
    required this.traceLerpFactor,
    required this.scrollSpeed,
    required this.onVisualModeChanged,
    required this.onTargetGainChanged,
    required this.onSensitivityChanged,
    required this.onSmoothingSpeedChanged,
    required this.onPianoRollZoomChanged,
    required this.onTraceLerpFactorChanged,
    required this.onScrollSpeedChanged,
    required this.onResetToDefaults,
  });

  @override
  State<SettingsSheet> createState() => _SettingsSheetState();
}

class _SettingsSheetState extends State<SettingsSheet> {
  late VisualMode _visualMode;
  late double _targetGain;
  late double _sensitivity;
  late double _smoothingSpeed;
  late double _pianoRollZoom;
  late double _traceLerpFactor;
  late double _scrollSpeed;

  bool _isConfirmingReset = false;

  @override
  void initState() {
    super.initState();
    _visualMode = widget.visualMode;
    _targetGain = widget.targetGain;
    _sensitivity = widget.sensitivity;
    _smoothingSpeed = widget.smoothingSpeed;
    _pianoRollZoom = widget.pianoRollZoom;
    _traceLerpFactor = widget.traceLerpFactor;
    _scrollSpeed = widget.scrollSpeed;
  }

  @override
  void didUpdateWidget(SettingsSheet oldWidget) {
      super.didUpdateWidget(oldWidget);
      if (oldWidget.visualMode != widget.visualMode) _visualMode = widget.visualMode;
      if (oldWidget.targetGain != widget.targetGain) _targetGain = widget.targetGain;
      if (oldWidget.sensitivity != widget.sensitivity) _sensitivity = widget.sensitivity;
      if (oldWidget.smoothingSpeed != widget.smoothingSpeed) _smoothingSpeed = widget.smoothingSpeed;
      if (oldWidget.pianoRollZoom != widget.pianoRollZoom) _pianoRollZoom = widget.pianoRollZoom;
      if (oldWidget.traceLerpFactor != widget.traceLerpFactor) _traceLerpFactor = widget.traceLerpFactor;
      if (oldWidget.scrollSpeed != widget.scrollSpeed) _scrollSpeed = widget.scrollSpeed;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 32.0),
      child: SingleChildScrollView(
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text("Tuner Settings", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          const Divider(height: 32, color: Colors.white24),
          const Text("Visual Mode", style: TextStyle(color: Colors.grey)),
          const SizedBox(height: 8),
          SegmentedButton<VisualMode>(
            segments: const [
              ButtonSegment(value: VisualMode.needle, label: Text("Wave"), icon: Icon(Icons.waves)),
              ButtonSegment(value: VisualMode.rollingTrace, label: Text("Roll"), icon: Icon(Icons.linear_scale)),
            ],
            selected: {_visualMode},
            onSelectionChanged: (val) {
              setState(() => _visualMode = val.first);
              widget.onVisualModeChanged(val.first);
            },
          ),
          const SizedBox(height: 16),

          if (_visualMode == VisualMode.rollingTrace) ...[
            _settingLabel("Base Zoom", _pianoRollZoom.toStringAsFixed(1)),
            Slider(value: _pianoRollZoom, min: 0.2, max: 2.0, onChanged: (v) {
              setState(() => _pianoRollZoom = v);
              widget.onPianoRollZoomChanged(v);
            }),
            _settingLabel("Trace Glide", _traceLerpFactor.toStringAsFixed(2)),
            Slider(value: _traceLerpFactor, min: 0.01, max: 0.5, onChanged: (v) {
              setState(() => _traceLerpFactor = v);
              widget.onTraceLerpFactorChanged(v);
            }),
            _settingLabel("Scroll Speed", "${_scrollSpeed.toStringAsFixed(1)}x"),
            Slider(value: _scrollSpeed, min: 0.1, max: 5.0, onChanged: (v) {
              setState(() => _scrollSpeed = v);
              widget.onScrollSpeedChanged(v);
            }),
          ],

          _settingLabel("Needle Speed", "${_smoothingSpeed.toInt()}ms"),
          Slider(value: _smoothingSpeed, min: 50, max: 500, onChanged: (v) {
            setState(() => _smoothingSpeed = v);
            widget.onSmoothingSpeedChanged(v);
          }),
          _settingLabel("Max Audio Gain", _targetGain.toStringAsFixed(1)),
          Slider(value: _targetGain, min: 1.0, max: 20.0, onChanged: (v) {
            setState(() => _targetGain = v);
            widget.onTargetGainChanged(v);
          }),
          _settingLabel("Pitch Sensitivity", _sensitivity.toStringAsFixed(2)),
          Slider(value: _sensitivity, min: 0.1, max: 0.9, onChanged: (v) {
            setState(() => _sensitivity = v);
            widget.onSensitivityChanged(v);
          }),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: _isConfirmingReset ? Colors.redAccent : Theme.of(context).colorScheme.secondaryContainer,
                foregroundColor: _isConfirmingReset ? Colors.white : Theme.of(context).colorScheme.onSecondaryContainer,
              ),
              onPressed: () {
                if (_isConfirmingReset) {
                  widget.onResetToDefaults();
                  Navigator.pop(context);
                } else {
                  setState(() => _isConfirmingReset = true);
                }
              },
              child: Text(_isConfirmingReset ? "Are you sure?" : "Reset to Defaults"),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _settingLabel(String title, String value) {
    return Padding(
      padding: const EdgeInsets.only(top: 16.0),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(title, style: const TextStyle(color: Colors.white70)),
        Text(value, style: const TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.bold)),
      ]),
    );
  }
}
