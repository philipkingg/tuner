import 'dart:async';
import 'dart:math';
import 'dart:typed_data';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:pitch_detector_dart/pitch_detector.dart';
import 'package:record/record.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../../models/tuning_preset.dart';
import '../../models/visual_mode.dart';
import '../../utils/note_utils.dart';
import '../painters/wave_painter.dart';
import '../painters/cents_meter_painter.dart';
import '../painters/rolling_roll_painter.dart';
import '../widgets/settings_sheet.dart';
import '../widgets/tuning_menu.dart';

class TunerHome extends StatefulWidget {
  const TunerHome({super.key});
  @override
  State<TunerHome> createState() => _TunerHomeState();
}

class _TunerHomeState extends State<TunerHome> with TickerProviderStateMixin {
  final _audioRecorder = AudioRecorder();
  late PitchDetector _pitchDetector;
  StreamSubscription<Uint8List>? _audioStreamSubscription;
  SharedPreferences? _prefs;

  late AnimationController _needleController;
  late Animation<double> _needleAnimation;

  final List<Point<double>> _traceHistory = [];
  final int _maxTracePoints = 120;

  final List<double> _audioBuffer = [];
  List<double> _wavePoints = [];
  final List<double> _pitchHistory = [];

  double hz = 0.0;
  String note = "--";
  String octave = "";
  int cents = 0;

  double _currentLerpedNote = 0.0;
  double _dynamicZoomMultiplier = 1.0;
  bool _isInitialized = false;

  final List<TuningPreset> _presets = [
    TuningPreset(name: "Chromatic", notes: []),
    TuningPreset(name: "Guitar (Standard)", notes: ["E2", "A2", "D3", "G3", "B3", "E4"]),
    TuningPreset(name: "Guitar (7-String)", notes: ["B1", "E2", "A2", "D3", "G3", "B3", "E4"]),
    TuningPreset(name: "Bass (Standard)", notes: ["E1", "A1", "D2", "G2"]),
  ];
  int _selectedPresetIndex = 0;

  VisualMode _visualMode = VisualMode.rollingTrace;
  double gain = 1.0;
  double targetGain = 5.0;
  double sensitivity = 0.4;
  double smoothingSpeed = 100.0;
  double pianoRollZoom = 1.0;
  double traceLerpFactor = 0.15;

  @override
  void initState() {
    super.initState();
    _pitchDetector = PitchDetector(audioSampleRate: 44100, bufferSize: 4096);
    _needleController = AnimationController(vsync: this, duration: const Duration(milliseconds: 100));
    _needleAnimation = Tween<double>(begin: 0, end: 0).animate(CurvedAnimation(parent: _needleController, curve: Curves.easeOutCubic))
      ..addListener(() { if (mounted) setState(() => cents = _needleAnimation.value.round()); });
    _initApp();
  }

  @override
  void dispose() {
    WakelockPlus.disable();
    _audioStreamSubscription?.cancel();
    _audioRecorder.dispose();
    _needleController.dispose();
    super.dispose();
  }

  Future<void> _initApp() async {
    _prefs = await SharedPreferences.getInstance();
    _loadSettings();
    await _startTuning();
    if (mounted) setState(() => _isInitialized = true);
  }

  void _loadSettings() {
    if (_prefs == null) return;
    setState(() {
      _visualMode = VisualMode.values[_prefs!.getInt('visualMode') ?? 1];
      targetGain = _prefs!.getDouble('targetGain') ?? 5.0;
      sensitivity = _prefs!.getDouble('sensitivity') ?? 0.4;
      smoothingSpeed = _prefs!.getDouble('smoothingSpeed') ?? 100.0;
      pianoRollZoom = _prefs!.getDouble('pianoRollZoom') ?? 1.0;
      traceLerpFactor = _prefs!.getDouble('traceLerpFactor') ?? 0.15;
      _selectedPresetIndex = _prefs!.getInt('presetIndex') ?? 0;
      gain = targetGain;
    });
  }

  Future<void> _saveSettings() async {
    if (_prefs == null) return;
    await _prefs!.setInt('visualMode', _visualMode.index);
    await _prefs!.setDouble('targetGain', targetGain);
    await _prefs!.setDouble('sensitivity', sensitivity);
    await _prefs!.setDouble('smoothingSpeed', smoothingSpeed);
    await _prefs!.setDouble('pianoRollZoom', pianoRollZoom);
    await _prefs!.setDouble('traceLerpFactor', traceLerpFactor);
    await _prefs!.setInt('presetIndex', _selectedPresetIndex);
  }

  void _resetToDefaults() {
    setState(() {
      _visualMode = VisualMode.rollingTrace;
      targetGain = 5.0;
      sensitivity = 0.4;
      smoothingSpeed = 100.0;
      pianoRollZoom = 1.0;
      traceLerpFactor = 0.15;
      _selectedPresetIndex = 0;
      gain = targetGain;
    });
    _saveSettings();
  }

  Future<void> _startTuning() async {
    if (await _audioRecorder.hasPermission()) {
      WakelockPlus.enable();
      const config = RecordConfig(encoder: AudioEncoder.pcm16bits, sampleRate: 44100, numChannels: 1);
      final stream = await _audioRecorder.startStream(config);
      _audioStreamSubscription = stream.listen((Uint8List data) => _processBytes(data));
    }
  }

  void _processBytes(Uint8List data) async {
    final ByteData byteData = ByteData.sublistView(data);
    final List<double> currentChunk = [];
    double peak = 0.0;
    for (int i = 0; i < data.length - 1; i += 2) {
      int sample = byteData.getInt16(i, Endian.little);
      double val = (sample / 32768.0) * gain;
      currentChunk.add(val.clamp(-1.0, 1.0));
      if (val.abs() > peak) {
        peak = val.abs();
      }
    }
    if (peak >= 0.98) {
      gain *= 0.8;
    } else if (peak < 0.4 && gain < targetGain) {
      gain *= 1.02;
    }
    _audioBuffer.addAll(currentChunk);
    while (_audioBuffer.length >= 4096) {
      final List<double> processingBuffer = _audioBuffer.sublist(0, 4096);
      _audioBuffer.removeRange(0, 2048);
      final result = await _pitchDetector.getPitchFromFloatBuffer(processingBuffer);
      if (result.pitched && result.probability > sensitivity && result.pitch > 30) {
        _updateTunerLogic(result.pitch);
      } else {
        if (_traceHistory.isNotEmpty) {
          _traceHistory.insert(0, _traceHistory.first);
        } else {
          _traceHistory.insert(0, const Point(0, 0));
        }
        if (_traceHistory.length > _maxTracePoints) {
          _traceHistory.removeLast();
        }
      }
    }
    if (mounted) setState(() => _wavePoints = currentChunk.take(80).toList());
  }

  void _updateTunerLogic(double newPitch) {
    _pitchHistory.add(newPitch);
    if (_pitchHistory.length > 5) _pitchHistory.removeAt(0);
    List<double> sorted = List.from(_pitchHistory)..sort();
    double medianHz = sorted[sorted.length ~/ 2];

    double n = 12 * (log(medianHz / 440) / log(2));
    final currentPreset = _presets[_selectedPresetIndex];

    double targetN;
    String targetName;
    String targetOctave;

    if (currentPreset.notes.isEmpty) {
      int roundedN = n.round();
      targetN = roundedN.toDouble();
      targetName = NoteUtils.noteNames[(roundedN + 57) % 12];
      targetOctave = ((roundedN + 57) / 12).floor().toString();
    } else {
      double minDiff = double.infinity;
      double closestN = NoteUtils.noteToN(currentPreset.notes.first);
      String closestLabel = currentPreset.notes.first;

      for (var noteStr in currentPreset.notes) {
        double presetN = NoteUtils.noteToN(noteStr);
        double diff = (n - presetN).abs();
        if (diff < minDiff) {
          minDiff = diff;
          closestN = presetN;
          closestLabel = noteStr;
        }
      }
      targetN = closestN;
      RegExp re = RegExp(r"([A-G]#?)(\d)");
      var match = re.firstMatch(closestLabel);
      targetName = match?.group(1) ?? "--";
      targetOctave = match?.group(2) ?? "";
    }

    // AUTO-ZOOM CALCULATION
    double distance = (n - targetN).abs();
    double targetZoomMult = 1.0;
    if (distance > 0.5) {
      targetZoomMult = (1.0 / (distance * 1.5)).clamp(0.2, 1.0);
    }

    double newCents = (n - targetN) * 100;
    _currentLerpedNote = lerpDouble(_currentLerpedNote, n, traceLerpFactor) ?? n;
    _dynamicZoomMultiplier = lerpDouble(_dynamicZoomMultiplier, targetZoomMult, 0.1) ?? 1.0;

    _traceHistory.insert(0, Point(newCents, _currentLerpedNote));
    if (_traceHistory.length > _maxTracePoints) _traceHistory.removeLast();

    if (mounted) {
      setState(() {
        hz = medianHz;
        note = targetName;
        octave = targetOctave;
      });
      _needleAnimation = Tween<double>(begin: _needleAnimation.value, end: newCents).animate(
          CurvedAnimation(parent: _needleController, curve: Curves.easeOut)
      );
      _needleController.duration = Duration(milliseconds: smoothingSpeed.toInt());
      _needleController.forward(from: 0);
    }
  }

  void _showTuningMenu() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.grey[900],
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => TuningMenu(
        presets: _presets,
        selectedIndex: _selectedPresetIndex,
        onPresetSelected: (index) {
          setState(() { _selectedPresetIndex = index; _traceHistory.clear(); });
          _saveSettings();
        },
      ),
    );
  }

  void _showSettings() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.grey[900],
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => SettingsSheet(
        visualMode: _visualMode,
        targetGain: targetGain,
        sensitivity: sensitivity,
        smoothingSpeed: smoothingSpeed,
        pianoRollZoom: pianoRollZoom,
        traceLerpFactor: traceLerpFactor,
        onVisualModeChanged: (v) { setState(() => _visualMode = v); _saveSettings(); },
        onTargetGainChanged: (v) { setState(() => targetGain = v); _saveSettings(); },
        onSensitivityChanged: (v) { setState(() => sensitivity = v); _saveSettings(); },
        onSmoothingSpeedChanged: (v) { setState(() => smoothingSpeed = v); _saveSettings(); },
        onPianoRollZoomChanged: (v) { setState(() => pianoRollZoom = v); _saveSettings(); },
        onTraceLerpFactorChanged: (v) { setState(() => traceLerpFactor = v); _saveSettings(); },
        onResetToDefaults: _resetToDefaults,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_isInitialized) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    bool isCorrect = cents.abs() < 5 && note != "--";
    final currentPreset = _presets[_selectedPresetIndex];

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        leadingWidth: 140,
        leading: InkWell(
          onTap: _showTuningMenu,
          child: Padding(
            padding: const EdgeInsets.only(left: 12.0),
            child: Row(
              children: [
                const Icon(Icons.tune, size: 22),
                const SizedBox(width: 8),
                Expanded(child: Text(currentPreset.name, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold), overflow: TextOverflow.visible)),
              ],
            ),
          ),
        ),
        actions: [IconButton(onPressed: _showSettings, icon: const Icon(Icons.settings))],
      ),
      body: Column(children: [
        SizedBox(
          height: 180,
          child: Stack(
            alignment: Alignment.center,
            children: [
              if (isCorrect)
                IgnorePointer(
                  child: Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          Colors.greenAccent.withValues(alpha: 0.4),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                ),
              Center(
                child: RichText(
                  text: TextSpan(children: [
                    TextSpan(
                      text: note,
                      style: TextStyle(
                        fontSize: 100,
                        fontWeight: FontWeight.bold,
                        color: isCorrect ? Colors.greenAccent : Colors.white,
                        shadows: isCorrect ? [const Shadow(blurRadius: 20, color: Colors.greenAccent)] : null,
                      ),
                    ),
                    TextSpan(
                      text: octave,
                      style: TextStyle(
                        fontSize: 30,
                        color: Colors.blueAccent.withValues(alpha: 0.7),
                        fontFeatures: const [FontFeature.subscripts()],
                      ),
                    ),
                  ]),
                ),
              ),
            ],
          ),
        ),

        Text("${hz.toStringAsFixed(1)} Hz", style: const TextStyle(fontSize: 20, color: Colors.blueAccent)),

        Expanded(
          child: Container(
            margin: const EdgeInsets.symmetric(vertical: 20),
            width: double.infinity,
            clipBehavior: Clip.hardEdge,
            decoration: const BoxDecoration(color: Colors.black),
            child: _visualMode == VisualMode.needle
                ? Center(child: SizedBox(height: 120, width: double.infinity, child: CustomPaint(painter: WavePainter(_wavePoints))))
                : CustomPaint(painter: RollingRollPainter(_traceHistory, _currentLerpedNote, pianoRollZoom * _dynamicZoomMultiplier, currentPreset.notes)),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 20),
          child: Column(children: [
            SizedBox(height: 40, width: double.infinity, child: CustomPaint(painter: CentsMeterPainter(cents.toDouble()))),
            const SizedBox(height: 10),
            Text("${cents.abs()} cents ${cents > 0 ? 'sharp' : 'flat'}", style: TextStyle(fontSize: 16, color: isCorrect ? Colors.greenAccent : Colors.white70)),
          ]),
        ),
      ]),
    );
  }
}
