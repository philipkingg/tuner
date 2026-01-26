import 'package:flutter/material.dart';
import '../../models/visual_mode.dart';

class SettingsSheet extends StatefulWidget {
  final VisualMode visualMode;
  final double targetGain;
  final double sensitivity;
  final double smoothingSpeed;
  final double pianoRollZoom;
  final double traceLerpFactor;
  final ValueChanged<VisualMode> onVisualModeChanged;
  final ValueChanged<double> onTargetGainChanged;
  final ValueChanged<double> onSensitivityChanged;
  final ValueChanged<double> onSmoothingSpeedChanged;
  final ValueChanged<double> onPianoRollZoomChanged;
  final ValueChanged<double> onTraceLerpFactorChanged;
  final VoidCallback onResetToDefaults;

  const SettingsSheet({
    super.key,
    required this.visualMode,
    required this.targetGain,
    required this.sensitivity,
    required this.smoothingSpeed,
    required this.pianoRollZoom,
    required this.traceLerpFactor,
    required this.onVisualModeChanged,
    required this.onTargetGainChanged,
    required this.onSensitivityChanged,
    required this.onSmoothingSpeedChanged,
    required this.onPianoRollZoomChanged,
    required this.onTraceLerpFactorChanged,
    required this.onResetToDefaults,
  });

  @override
  State<SettingsSheet> createState() => _SettingsSheetState();
}

class _SettingsSheetState extends State<SettingsSheet> {
  // Local state to update sliders smoothly while dragging before committing?
  // Actually the original code updated state immediately on change.
  // We will keep it simple and rely on parent update or local state if needed.
  // The original used StatefulBuilder for the modal to update itself.
  // Since we are now a Stateful widget, we can just use setStates locally if we want visuals to update,
  // but we also need to notify parent.
  // Actually, the parent rebuilds the sheet? No, showModalBottomSheet doesn't rebuild when parent rebuilds usually unless we pass a new builder.
  // The original code used StatefulBuilder INSIDE the sheet builder.
  
  // Let's use local state initialized from widget properties, and call callbacks on change.
  
  late VisualMode _visualMode;
  late double _targetGain;
  late double _sensitivity;
  late double _smoothingSpeed;
  late double _pianoRollZoom;
  late double _traceLerpFactor;

  @override
  void initState() {
    super.initState();
    _visualMode = widget.visualMode;
    _targetGain = widget.targetGain;
    _sensitivity = widget.sensitivity;
    _smoothingSpeed = widget.smoothingSpeed;
    _pianoRollZoom = widget.pianoRollZoom;
    _traceLerpFactor = widget.traceLerpFactor;
  }

  // Update local state when widget updates (if parent rebuilds sheet)
  @override
  void didUpdateWidget(SettingsSheet oldWidget) {
      super.didUpdateWidget(oldWidget);
      if (oldWidget.visualMode != widget.visualMode) _visualMode = widget.visualMode;
      if (oldWidget.targetGain != widget.targetGain) _targetGain = widget.targetGain;
      if (oldWidget.sensitivity != widget.sensitivity) _sensitivity = widget.sensitivity;
      if (oldWidget.smoothingSpeed != widget.smoothingSpeed) _smoothingSpeed = widget.smoothingSpeed;
      if (oldWidget.pianoRollZoom != widget.pianoRollZoom) _pianoRollZoom = widget.pianoRollZoom;
      if (oldWidget.traceLerpFactor != widget.traceLerpFactor) _traceLerpFactor = widget.traceLerpFactor;
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
          SizedBox(width: double.infinity, child: FilledButton.tonal(onPressed: () {
             widget.onResetToDefaults();
             // We can't easily update local state here without knowing the defaults, 
             // but if parent triggers rebuild or we just close the sheet it's fine.
             // Best to maybe just let parent handle reset and we update via didUpdateWidget if we kept it open,
             // or just assume reset closes or updates.
             // Actually, the original just reset state and updated. 
             // Let's force a local update to defaults if we know them, OR rely on parent.
             // Let's rely on parent to pass new values back if we are persistent, 
             // but `onResetToDefaults` is void.
             // For now, let's just call the callback.
             Navigator.pop(context); // Close on reset to be simple
          }, child: const Text("Reset to Defaults"))),
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
