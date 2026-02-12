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
  final bool hasMicPermission;
  final VoidCallback onOpenSettings;

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
    required this.hasMicPermission,
    required this.onOpenSettings,
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
    _scrollSpeed = widget.scrollSpeed;
  }

  @override
  void didUpdateWidget(SettingsSheet oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.visualMode != widget.visualMode)
      _visualMode = widget.visualMode;
    if (oldWidget.targetGain != widget.targetGain)
      _targetGain = widget.targetGain;
    if (oldWidget.sensitivity != widget.sensitivity)
      _sensitivity = widget.sensitivity;
    if (oldWidget.smoothingSpeed != widget.smoothingSpeed)
      _smoothingSpeed = widget.smoothingSpeed;
    if (oldWidget.pianoRollZoom != widget.pianoRollZoom)
      _pianoRollZoom = widget.pianoRollZoom;
    if (oldWidget.scrollSpeed != widget.scrollSpeed)
      _scrollSpeed = widget.scrollSpeed;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1C1C1E).withValues(alpha: 0.25),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 64, 24, 24),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Settings',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close, color: Colors.white70),
                ),
              ],
            ),
          ),

          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Permissions Warning
                  if (!widget.hasMicPermission) _buildPermissionWarning(),

                  // Display Section
                  _buildSection(
                    icon: Icons.visibility_outlined,
                    title: 'Display',
                    children: [_buildVisualModeSelector()],
                  ),

                  // Rolling Wave Section
                  if (_visualMode == VisualMode.rollingTrace)
                    _buildSection(
                      icon: Icons.waves,
                      title: 'Rolling Wave',
                      children: [
                        _buildSliderRow(
                          label: 'Base Zoom',
                          value: _pianoRollZoom,
                          displayValue: _pianoRollZoom.toStringAsFixed(1),
                          min: 0.1,
                          max: 2.0,
                          onChanged: (v) {
                            setState(() => _pianoRollZoom = v);
                            widget.onPianoRollZoomChanged(v);
                          },
                        ),
                        _buildSliderRow(
                          label: 'Scroll Speed',
                          value: _scrollSpeed,
                          displayValue: '${_scrollSpeed.toStringAsFixed(1)}x',
                          min: 0.1,
                          max: 5.0,
                          onChanged: (v) {
                            setState(() => _scrollSpeed = v);
                            widget.onScrollSpeedChanged(v);
                          },
                        ),
                      ],
                    ),

                  // Audio Section
                  _buildSection(
                    icon: Icons.tune,
                    title: 'Audio',
                    children: [
                      _buildSliderRow(
                        label: 'Needle Speed',
                        value: _smoothingSpeed,
                        displayValue: '${_smoothingSpeed.toInt()}ms',
                        min: 50,
                        max: 250,
                        onChanged: (v) {
                          setState(() => _smoothingSpeed = v);
                          widget.onSmoothingSpeedChanged(v);
                        },
                      ),
                      _buildSliderRow(
                        label: 'Max Audio Gain',
                        value: _targetGain,
                        displayValue: _targetGain.toStringAsFixed(1),
                        min: 1.0,
                        max: 20.0,
                        onChanged: (v) {
                          setState(() => _targetGain = v);
                          widget.onTargetGainChanged(v);
                        },
                      ),
                      _buildSliderRow(
                        label: 'Pitch Sensitivity',
                        value: _sensitivity,
                        displayValue: _sensitivity.toStringAsFixed(2),
                        min: 0.1,
                        max: 0.9,
                        onChanged: (v) {
                          setState(() => _sensitivity = v);
                          widget.onSensitivityChanged(v);
                        },
                      ),
                    ],
                  ),

                  const SizedBox(height: 8),

                  // Reset Button
                  _buildResetButton(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPermissionWarning() {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.redAccent.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.redAccent.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.mic_off, color: Colors.redAccent, size: 20),
              SizedBox(width: 8),
              Text(
                'Microphone Access Required',
                style: TextStyle(
                  color: Colors.redAccent,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'Grant microphone permission to use the tuner.',
            style: TextStyle(color: Colors.white70, fontSize: 13),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: widget.onOpenSettings,
              icon: const Icon(Icons.settings, size: 18),
              label: const Text('Open Settings'),
              style: FilledButton.styleFrom(
                backgroundColor: Colors.redAccent,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSection({
    required IconData icon,
    required String title,
    required List<Widget> children,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E20),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(icon, size: 20, color: Colors.white70),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.white70,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
          ...children,
        ],
      ),
    );
  }

  Widget _buildVisualModeSelector() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Row(
        children: [
          Expanded(
            child: _buildModeButton(
              icon: Icons.waves,
              label: 'Wave',
              isSelected: _visualMode == VisualMode.needle,
              onTap: () {
                setState(() => _visualMode = VisualMode.needle);
                widget.onVisualModeChanged(VisualMode.needle);
              },
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildModeButton(
              icon: Icons.linear_scale,
              label: 'Roll',
              isSelected: _visualMode == VisualMode.rollingTrace,
              onTap: () {
                setState(() => _visualMode = VisualMode.rollingTrace);
                widget.onVisualModeChanged(VisualMode.rollingTrace);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModeButton({
    required IconData icon,
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.only(top: 12, bottom: 12),
        decoration: BoxDecoration(
          color:
              isSelected
                  ? Colors.greenAccent.shade700.withOpacity(0.2)
                  : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? Colors.greenAccent.shade700 : Colors.white12,
            width: 1.5,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 18,
              color: isSelected ? Colors.greenAccent.shade400 : Colors.white70,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: isSelected ? Colors.white : Colors.white70,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSliderRow({
    required String label,
    required double value,
    required String displayValue,
    required double min,
    required double max,
    required ValueChanged<double> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                label,
                style: const TextStyle(fontSize: 15, color: Colors.white),
              ),
              Text(
                displayValue,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: Colors.greenAccent.shade400,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SliderTheme(
            data: SliderThemeData(
              activeTrackColor: Colors.greenAccent.shade700,
              inactiveTrackColor: Colors.white12,
              thumbColor: Colors.white,
              overlayColor: Colors.greenAccent.shade700.withOpacity(0.2),
              trackHeight: 4,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
            ),
            child: Slider(
              value: value,
              min: min,
              max: max,
              onChanged: onChanged,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResetButton() {
    return SizedBox(
      width: double.infinity,
      child: FilledButton(
        onPressed: () {
          if (_isConfirmingReset) {
            widget.onResetToDefaults();
            Navigator.pop(context);
          } else {
            setState(() => _isConfirmingReset = true);
            Future.delayed(const Duration(seconds: 3), () {
              if (mounted) setState(() => _isConfirmingReset = false);
            });
          }
        },
        style: FilledButton.styleFrom(
          backgroundColor:
              _isConfirmingReset ? Colors.redAccent : const Color(0xFF1E1E20),
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: Text(
          _isConfirmingReset ? 'Are you sure?' : 'Reset to Defaults',
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}
