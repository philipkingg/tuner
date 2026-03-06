import 'package:flutter/material.dart';
import '../../models/app_theme.dart';
import '../../models/visual_mode.dart';
import '../../main.dart';

class SettingsSheet extends StatefulWidget {
  final AppThemeColors themeColors;
  final VisualMode visualMode;
  final double targetGain;
  final double sensitivity;
  final double smoothingSpeed;
  final double pianoRollZoom;
  final double traceLerpFactor;
  final double scrollSpeed;
  final AppColorTheme selectedColorTheme;
  final ValueChanged<AppColorTheme> onColorThemeChanged;
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
    required this.themeColors,
    required this.visualMode,
    required this.targetGain,
    required this.sensitivity,
    required this.smoothingSpeed,
    required this.pianoRollZoom,
    required this.traceLerpFactor,
    required this.scrollSpeed,
    required this.selectedColorTheme,
    required this.onColorThemeChanged,
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
  late AppColorTheme _selectedColorTheme;
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
    _selectedColorTheme = widget.selectedColorTheme;
    appThemeNotifier.addListener(_onThemeChange);
  }

  @override
  void dispose() {
    appThemeNotifier.removeListener(_onThemeChange);
    super.dispose();
  }

  void _onThemeChange() {
    if (mounted) setState(() {});
  }

  @override
  void didUpdateWidget(SettingsSheet oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.visualMode != widget.visualMode) _visualMode = widget.visualMode;
    if (oldWidget.targetGain != widget.targetGain) _targetGain = widget.targetGain;
    if (oldWidget.sensitivity != widget.sensitivity) _sensitivity = widget.sensitivity;
    if (oldWidget.smoothingSpeed != widget.smoothingSpeed) _smoothingSpeed = widget.smoothingSpeed;
    if (oldWidget.pianoRollZoom != widget.pianoRollZoom) _pianoRollZoom = widget.pianoRollZoom;
    if (oldWidget.scrollSpeed != widget.scrollSpeed) _scrollSpeed = widget.scrollSpeed;
    if (oldWidget.selectedColorTheme != widget.selectedColorTheme) _selectedColorTheme = widget.selectedColorTheme;
  }

  AppThemeColors get tc => AppThemeColors.fromType(appThemeNotifier.value);

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: tc.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        border: Border(top: BorderSide(color: tc.border, width: 1)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 12, bottom: 4),
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: tc.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 20, 16, 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Settings',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: tc.textPrimary,
                    letterSpacing: -0.3,
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: Icon(
                    Icons.close_rounded,
                    color: tc.textSecondary,
                    size: 20,
                  ),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                ),
              ],
            ),
          ),

          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (!widget.hasMicPermission) _buildPermissionWarning(),

                  // Appearance Section
                  _buildSection(
                    icon: Icons.palette_outlined,
                    title: 'Appearance',
                    children: [
                      _buildThemeSelector(),
                      _buildVisualModeSelector(),
                    ],
                  ),

                  // Rolling Wave Section
                  if (_visualMode == VisualMode.rollingTrace)
                    _buildSection(
                      icon: Icons.waves_rounded,
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
                    icon: Icons.tune_rounded,
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

                  const SizedBox(height: 4),
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
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFF453A).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFFFF453A).withValues(alpha: 0.25),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.mic_off_rounded, color: Color(0xFFFF453A), size: 18),
              SizedBox(width: 8),
              Text(
                'Microphone Access Required',
                style: TextStyle(
                  color: Color(0xFFFF453A),
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Grant microphone permission to use the tuner.',
            style: TextStyle(color: tc.textSecondary, fontSize: 12),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: widget.onOpenSettings,
              icon: const Icon(Icons.settings_outlined, size: 16),
              label: const Text('Open Settings'),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFFF453A),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 10),
                textStyle: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
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
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: tc.surfaceContainer,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: tc.border, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
            child: Row(
              children: [
                Icon(icon, size: 16, color: tc.primary),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: tc.textSecondary,
                    letterSpacing: 0.4,
                  ),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: tc.border),
          ...children,
        ],
      ),
    );
  }

  Widget _buildThemeSelector() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Color Theme',
            style: TextStyle(fontSize: 14, color: tc.textPrimary),
          ),
          const SizedBox(height: 10),
          Row(
            children: AppColorTheme.values.map((themeType) {
              final themeColors = AppThemeColors.fromType(themeType);
              final isSelected = _selectedColorTheme == themeType;
              return Expanded(
                child: GestureDetector(
                  onTap: () {
                    setState(() => _selectedColorTheme = themeType);
                    widget.onColorThemeChanged(themeType);
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: EdgeInsets.only(
                      right: themeType == AppColorTheme.earthy ? 8 : 0,
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? tc.primary.withValues(alpha: 0.12)
                          : tc.surface,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isSelected ? tc.primary : tc.border,
                        width: isSelected ? 1.5 : 1,
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Color swatch dots
                        Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            color: themeColors.background,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: themeColors.primary,
                              width: 2,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          themeColors.displayName,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: isSelected ? tc.primary : tc.textSecondary,
                          ),
                        ),
                        if (isSelected) ...[
                          const SizedBox(width: 4),
                          Icon(
                            Icons.check_rounded,
                            size: 14,
                            color: tc.primary,
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildVisualModeSelector() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Visualizer',
            style: TextStyle(fontSize: 14, color: tc.textPrimary),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _buildModeButton(
                  icon: Icons.waves_rounded,
                  label: 'Wave',
                  isSelected: _visualMode == VisualMode.needle,
                  onTap: () {
                    setState(() => _visualMode = VisualMode.needle);
                    widget.onVisualModeChanged(VisualMode.needle);
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildModeButton(
                  icon: Icons.linear_scale_rounded,
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
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? tc.primary.withValues(alpha: 0.12) : tc.surface,
          borderRadius: BorderRadius.circular(9),
          border: Border.all(
            color: isSelected ? tc.primary : tc.border,
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 16,
              color: isSelected ? tc.primary : tc.textSecondary,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: isSelected ? tc.primary : tc.textSecondary,
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
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                label,
                style: TextStyle(fontSize: 14, color: tc.textPrimary),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: tc.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  displayValue,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: tc.primary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          SliderTheme(
            data: SliderThemeData(
              activeTrackColor: tc.primary,
              inactiveTrackColor: tc.border,
              thumbColor: tc.primary,
              overlayColor: tc.primary.withValues(alpha: 0.15),
              trackHeight: 3,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
            ),
            child: Slider(value: value, min: min, max: max, onChanged: onChanged),
          ),
        ],
      ),
    );
  }

  Widget _buildResetButton() {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton(
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
        style: OutlinedButton.styleFrom(
          foregroundColor: _isConfirmingReset
              ? const Color(0xFFFF453A)
              : tc.textSecondary,
          side: BorderSide(
            color: _isConfirmingReset
                ? const Color(0xFFFF453A).withValues(alpha: 0.5)
                : tc.border,
          ),
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: Text(
          _isConfirmingReset ? 'Tap again to confirm reset' : 'Reset to Defaults',
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}
