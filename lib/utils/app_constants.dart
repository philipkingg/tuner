import 'package:flutter/material.dart';
import '../models/tuning_preset.dart';
import '../models/visual_mode.dart';

class AppConstants {
  // Audio Configuration
  static const int audioSampleRate = 44100;
  static const int bufferSize = 4096;
  static const int jumpGuardThreshold = 5;

  // Default Settings
  static const double defaultTargetGain = 15.0;
  static const double defaultSensitivity = 0.4;
  static const double defaultSmoothingSpeed = 100.0;
  static const double defaultPianoRollZoom = 0.4;
  static const double defaultTraceLerpFactor = 0.15;
  static const double defaultScrollSpeed = 2.0;
  static const VisualMode defaultVisualMode = VisualMode.rollingTrace;
  static const int defaultPresetIndex = 0;

  // Layout & UI
  static const int maxTracePoints = 2000;
  static const Duration needleAnimationDuration = Duration(milliseconds: 100);
  static const double tuningMenuBorderRadius = 20.0;

  // Colors
  static final Color tuningMenuBackgroundColor = Colors.grey[900]!;

  // Rolling Painter Configuration
  static const double rollingWaveVisibleDurationMs = 5000.0;
  static const double rollingWaveStrokeWidth = 3.5;
  static const double rollingWaveRecentOffset = 40.0;
  static const double rollingWaveFadeTopHeight =
      150.0; // The height of the fade zone at the top

  // Default Presets
  static final List<TuningPreset> defaultPresets = [
    TuningPreset(name: "Chromatic", notes: []),
    TuningPreset(
      name: "Guitar (Standard)",
      notes: ["E2", "A2", "D3", "G3", "B3", "E4"],
    ),
    TuningPreset(name: "Bass (Standard)", notes: ["E1", "A1", "D2", "G2"]),
    TuningPreset(
      name: "C Major Scale",
      notes: ["C", "D", "E", "F", "G", "A", "B"],
    ),
  ];
}
