import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pitch_detector_dart/pitch_detector.dart';
import 'package:record/record.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../models/tuning_preset.dart';
import '../../models/visual_mode.dart';
import '../../utils/note_utils.dart';
import '../painters/wave_painter.dart';
import '../painters/cents_meter_painter.dart';
// import '../painters/rolling_roll_painter.dart'; // Replaced by RollingVisualizer
import '../widgets/rolling_visualizer.dart';
import '../../models/trace_point.dart';
import '../widgets/settings_sheet.dart';
import '../widgets/tuning_menu.dart';
import '../widgets/add_tuning_dialog.dart';
import '../../utils/app_constants.dart';

class TunerHome extends StatefulWidget {
  const TunerHome({super.key});
  @override
  State<TunerHome> createState() => _TunerHomeState();
}

class _TunerHomeState extends State<TunerHome>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  final _audioRecorder = AudioRecorder();
  late PitchDetector _pitchDetector;
  StreamSubscription<Uint8List>? _audioStreamSubscription;
  SharedPreferences? _prefs;

  late AnimationController _needleController;
  late Animation<double> _needleAnimation;

  final List<TracePoint> _traceHistory = [];

  final List<double> _audioBuffer = [];
  List<double> _wavePoints = [];
  final List<double> _pitchHistory = [];

  double _visualCents = 0.0; // Smoothed cents for visualization

  double hz = 0.0;
  String note = "--";
  String octave = "";
  int cents = 0;

  double _currentLerpedNote = 0.0;
  double _dynamicZoomMultiplier = 1.0;
  bool _isInitialized = false;
  bool _hasMicPermission = true;

  static final List<TuningPreset> _kDefaultPresets =
      AppConstants.defaultPresets;

  List<TuningPreset> _presets = List.from(_kDefaultPresets);
  int _selectedPresetIndex = AppConstants.defaultPresetIndex;

  VisualMode _visualMode = AppConstants.defaultVisualMode;
  double gain = 1.0;
  double targetGain = AppConstants.defaultTargetGain;
  double sensitivity = AppConstants.defaultSensitivity;
  double smoothingSpeed = AppConstants.defaultSmoothingSpeed;
  double pianoRollZoom = AppConstants.defaultPianoRollZoom;
  double traceLerpFactor = AppConstants.defaultTraceLerpFactor;
  double scrollSpeed = AppConstants.defaultScrollSpeed;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _pitchDetector = PitchDetector(
      audioSampleRate: AppConstants.audioSampleRate.toDouble(),
      bufferSize: AppConstants.bufferSize,
    );
    _needleController = AnimationController(
      vsync: this,
      duration: AppConstants.needleAnimationDuration,
    );
    _needleAnimation = Tween<double>(begin: 0, end: 0).animate(
      CurvedAnimation(parent: _needleController, curve: Curves.easeOutCubic),
    )..addListener(() {
      if (mounted) setState(() => cents = _needleAnimation.value.round());
    });
    _initApp();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    platform.invokeMethod('toggle', false);
    _stopTuning();
    _audioRecorder.dispose();
    _needleController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      _stopTuning();
    } else if (state == AppLifecycleState.resumed) {
      _checkPermission();
      _startTuning();
    }
  }

  Future<void> _checkPermission() async {
    final hasPermission = await _audioRecorder.hasPermission();
    if (mounted) {
      setState(() {
        _hasMicPermission = hasPermission;
      });
    }
  }

  Future<void> _openAppSettings() async {
    try {
      await platform.invokeMethod('openSettings');
    } catch (e) {
      debugPrint("Failed to open settings: $e");
    }
  }

  Future<void> _initApp() async {
    _prefs = await SharedPreferences.getInstance();
    _loadSettings();
    await _checkPermission();
    await _startTuning();
    if (mounted) setState(() => _isInitialized = true);
  }

  void _loadSettings() {
    if (_prefs == null) return;
    setState(() {
      _visualMode = VisualMode.values[_prefs!.getInt('visualMode') ?? 1];
      targetGain =
          _prefs!.getDouble('targetGain') ?? AppConstants.defaultTargetGain;
      sensitivity =
          _prefs!.getDouble('sensitivity') ?? AppConstants.defaultSensitivity;
      smoothingSpeed =
          _prefs!.getDouble('smoothingSpeed') ??
          AppConstants.defaultSmoothingSpeed;
      pianoRollZoom =
          _prefs!.getDouble('pianoRollZoom') ??
          AppConstants.defaultPianoRollZoom;
      traceLerpFactor =
          _prefs!.getDouble('traceLerpFactor') ??
          AppConstants.defaultTraceLerpFactor;
      _selectedPresetIndex =
          _prefs!.getInt('presetIndex') ?? AppConstants.defaultPresetIndex;
      scrollSpeed =
          _prefs!.getDouble('scrollSpeed') ?? AppConstants.defaultScrollSpeed;

      gain = targetGain;

      // Load unified presets
      List<String>? savedPresets = _prefs!.getStringList('saved_presets');
      if (savedPresets != null && savedPresets.isNotEmpty) {
        _presets =
            savedPresets
                .map((e) => TuningPreset.fromJson(jsonDecode(e)))
                .toList();
      } else {
        // Fallback to defaults (already set)
        _presets = List.from(_kDefaultPresets);
      }

      // Validation: Ensure index is valid
      if (_selectedPresetIndex >= _presets.length) {
        _selectedPresetIndex = AppConstants.defaultPresetIndex;
      }
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
    await _prefs!.setDouble('scrollSpeed', scrollSpeed);

    // Save all presets
    List<String> presetsJson =
        _presets.map((e) => jsonEncode(e.toJson())).toList();
    await _prefs!.setStringList('saved_presets', presetsJson);
  }

  void _resetToDefaults() {
    setState(() {
      _visualMode = AppConstants.defaultVisualMode;
      targetGain = AppConstants.defaultTargetGain;
      sensitivity = AppConstants.defaultSensitivity;
      smoothingSpeed = AppConstants.defaultSmoothingSpeed;
      pianoRollZoom = AppConstants.defaultPianoRollZoom;
      traceLerpFactor = AppConstants.defaultTraceLerpFactor;
      _selectedPresetIndex = AppConstants.defaultPresetIndex;
      scrollSpeed = AppConstants.defaultScrollSpeed;
      gain = targetGain;
      // Note: resetting defaults does NOT delete custom tunings in this implementation,
      // it just resets settings. If user wants to reset tunings, they can delete them?
      // Or should "Reset to Defaults" also restore the default tuning list?
      // Usually "Reset Settings" is separate from "Factory Reset".
      // The prompt was "Reset to Defaults".
      // Let's reset the tuning list to strict defaults too, as that seems safer for a "Reset" action.
      _presets = List.from(_kDefaultPresets);
    });
    _saveSettings();
  }

  static const platform = MethodChannel('com.philip.centigrade/wakelock');

  Future<void> _startTuning() async {
    if (_audioStreamSubscription != null) return; // Already recording

    if (await _audioRecorder.hasPermission()) {
      try {
        await platform.invokeMethod('toggle', true);
      } catch (e) {
        debugPrint("Failed to enable wakelock: $e");
      }

      const config = RecordConfig(
        encoder: AudioEncoder.pcm16bits,
        sampleRate: AppConstants.audioSampleRate,
        numChannels: 1,
      );
      final stream = await _audioRecorder.startStream(config);
      _audioStreamSubscription = stream.listen(
        (Uint8List data) => _processBytes(data),
      );
    }
  }

  Future<void> _stopTuning() async {
    _audioStreamSubscription?.cancel();
    _audioStreamSubscription = null;
    await _audioRecorder.stop();
    try {
      await platform.invokeMethod('toggle', false);
    } catch (e) {
      debugPrint("Failed to disable wakelock: $e");
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
    while (_audioBuffer.length >= AppConstants.bufferSize) {
      final List<double> processingBuffer = _audioBuffer.sublist(
        0,
        AppConstants.bufferSize,
      );
      _audioBuffer.removeRange(
        0,
        2048,
      ); // Leaving overlap. Could be a constant too?
      final result = await _pitchDetector.getPitchFromFloatBuffer(
        processingBuffer,
      );
      if (result.pitched &&
          result.probability > sensitivity &&
          result.pitch > 30) {
        _updateTunerLogic(result.pitch);
      } else {
        // We still want to add history points for "silence" or just let time pass?
        // With time-based rendering, we only need points when there is data,
        // OR we need explicit "gap" points if we want the line to break.
        // The painter draws lines between adjacent points in history.
        // If we stop adding points, the line stops growing, but the old points will scroll off.
        // If we want a continuous line of "silence", we should add points.
        // The old logic added (0,0) which is probably "Center Cents, Center Note"?
        // 0 cents, 0 note index seems wrong if we are tracking specific notes.
        // Let's stick to the minimal change: duplicate last point or add a "gap".
        // Use an out-of-bounds note to indicate gap? Or just skip adding?
        // If we skip adding, the visualizer just draws a straight line between the last point and the next valid one?
        // No, it draws segments between history[i] and history[i+1].
        // If time gaps are large, the line will be long and straight.
        // Let's add "silence" points if needed, or just let it be.
        // The original logic inserted (0,0) or last point.
        // Let's replicate duplicate last point behavior for now to maintain continuity if that was desired.
        /*
        if (_traceHistory.isNotEmpty) {
           // Should we replicate? 
           // If we replicate, we need a new timestamp.
           // But if no pitch is detected, maybe we shouldn't draw anything?
        }
        */
        // For now, let's NOT add points when silent, to see if it looks cleaner (just gap in data).
        // Actually, if we don't add points, the last point stays at the "top" of the history stack,
        // and as time progresses, it will slide down.
        // Wait, the history is a list of points. The "top" is the most recent.
        // In time-based, Y = currentTimestamp - pointTimestamp.
        // If we stop adding points, all existing points get older and slide down.
        // The "pen" (current time) moves away from the last point.
        // So the line will end at the last point.
        // This is correct for "no data".
      }
    }
    if (mounted) setState(() => _wavePoints = currentChunk.take(80).toList());
  }

  // Stabilization State
  double? _lastConfirmedPitch;
  int _jumpGuardCounter = 0;
  static const int _jumpGuardThreshold =
      AppConstants.jumpGuardThreshold; // Frames to confirm a jump

  void _updateTunerLogic(double newPitch) {
    // Jump Guard Logic
    if (_lastConfirmedPitch != null) {
      double semitoneDiff =
          12 * (log(newPitch / _lastConfirmedPitch!) / log(2));
      if (semitoneDiff.abs() > 3.0) {
        // Should be a large jump?
        _jumpGuardCounter++;
        if (_jumpGuardCounter < _jumpGuardThreshold) {
          // Ignore this pitch for now, it might be a glitch
          return;
        }
        // Confirmed jump
        _lastConfirmedPitch = newPitch;
        _jumpGuardCounter = 0;
        _pitchHistory.clear(); // Clear history on jump so median doesn't drag
      } else {
        _lastConfirmedPitch = newPitch;
        _jumpGuardCounter = 0;
      }
    } else {
      _lastConfirmedPitch = newPitch;
    }

    _pitchHistory.add(newPitch);
    if (_pitchHistory.length > 9) _pitchHistory.removeAt(0); // Increased buffer
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

    // Smooth the visual cents
    _visualCents =
        lerpDouble(_visualCents, newCents, traceLerpFactor) ?? newCents;

    _currentLerpedNote =
        lerpDouble(_currentLerpedNote, n, traceLerpFactor) ?? n;
    _dynamicZoomMultiplier =
        lerpDouble(_dynamicZoomMultiplier, targetZoomMult, 0.1) ?? 1.0;

    _traceHistory.insert(
      0,
      TracePoint(
        cents: newCents,
        note: _currentLerpedNote,
        timestamp: DateTime.now().millisecondsSinceEpoch,
      ),
    );

    // Prune history based on time? Or Count?
    // Count is safer for memory, but for visual length:
    // Visible duration = 5000 / scrollSpeed ms.
    // If we keep 10 seconds of history, that's safe.
    // If update rate is 60Hz, 10s = 600 points.
    // Let's keep a generous count buffer.
    if (_traceHistory.length > AppConstants.maxTracePoints)
      _traceHistory.removeLast();

    if (mounted) {
      setState(() {
        hz = medianHz;
        note = targetName;
        octave = targetOctave;
      });
      _needleAnimation = Tween<double>(
        begin: _needleAnimation.value,
        end: newCents,
      ).animate(
        CurvedAnimation(parent: _needleController, curve: Curves.easeOut),
      );
      _needleController.duration = Duration(
        milliseconds: smoothingSpeed.toInt(),
      );
      _needleController.forward(from: 0);
    }
  }

  void _showTuningMenu() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppConstants.tuningMenuBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppConstants.tuningMenuBorderRadius),
        ),
      ),
      builder:
          (context) => TuningMenu(
            presets: _presets,
            selectedIndex: _selectedPresetIndex,
            onPresetSelected: (index) {
              setState(() {
                _selectedPresetIndex = index;
                _traceHistory.clear();
              });
              _saveSettings();
            },
            onCreateNew: () {
              Navigator.pop(context); // Close menu first
              showDialog(
                context: context,
                builder:
                    (context) => AddTuningDialog(
                      onAdd: (newPreset) {
                        setState(() {
                          _presets.add(newPreset);
                          _selectedPresetIndex =
                              _presets.length - 1; // Select the new one
                          _traceHistory.clear();
                        });
                        _saveSettings();
                      },
                    ),
              );
            },
            onDelete: (preset) {
              setState(() {
                _presets.remove(preset);
                if (_selectedPresetIndex >= _presets.length) {
                  _selectedPresetIndex = AppConstants.defaultPresetIndex;
                }
                _traceHistory.clear();
              });
              Navigator.pop(context);
              _saveSettings();
            },
          ),
    );
  }

  void _showSettings() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppConstants.tuningMenuBackgroundColor,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppConstants.tuningMenuBorderRadius),
        ),
      ),
      builder:
          (context) => SettingsSheet(
            visualMode: _visualMode,
            targetGain: targetGain,
            sensitivity: sensitivity,
            smoothingSpeed: smoothingSpeed,
            pianoRollZoom: pianoRollZoom,
            traceLerpFactor: traceLerpFactor,
            scrollSpeed: scrollSpeed,
            onVisualModeChanged: (v) {
              setState(() => _visualMode = v);
              _saveSettings();
            },
            onTargetGainChanged: (v) {
              setState(() => targetGain = v);
              _saveSettings();
            },
            onSensitivityChanged: (v) {
              setState(() => sensitivity = v);
              _saveSettings();
            },
            onSmoothingSpeedChanged: (v) {
              setState(() => smoothingSpeed = v);
              _saveSettings();
            },
            onPianoRollZoomChanged: (v) {
              setState(() => pianoRollZoom = v);
              _saveSettings();
            },
            onTraceLerpFactorChanged: (v) {
              setState(() => traceLerpFactor = v);
              _saveSettings();
            },
            onScrollSpeedChanged: (v) {
              setState(() => scrollSpeed = v);
              _saveSettings();
            },
            onResetToDefaults: _resetToDefaults,
            hasMicPermission: _hasMicPermission,
            onOpenSettings: _openAppSettings,
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_isInitialized) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
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
                Expanded(
                  child: Text(
                    currentPreset.name,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                    overflow: TextOverflow.visible,
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          Stack(
            alignment: Alignment.topRight,
            children: [
              IconButton(
                onPressed: _showSettings,
                icon: const Icon(Icons.settings),
              ),
              if (!_hasMicPermission)
                Positioned(
                  top: 8,
                  right: 8,
                  child: Container(
                    width: 14,
                    height: 14,
                    decoration: const BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                    ),
                    child: const Center(
                      child: Text(
                        "!",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
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
                    text: TextSpan(
                      children: [
                        TextSpan(
                          text: note,
                          style: TextStyle(
                            fontSize: 100,
                            fontWeight: FontWeight.bold,
                            color:
                                isCorrect ? Colors.greenAccent : Colors.white,
                            shadows:
                                isCorrect
                                    ? [
                                      const Shadow(
                                        blurRadius: 20,
                                        color: Colors.greenAccent,
                                      ),
                                    ]
                                    : null,
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
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          Text(
            "${hz.toStringAsFixed(1)} Hz",
            style: const TextStyle(fontSize: 20, color: Colors.blueAccent),
          ),

          Expanded(
            child: Container(
              margin: const EdgeInsets.symmetric(vertical: 20),
              width: double.infinity,
              clipBehavior: Clip.hardEdge,
              decoration: const BoxDecoration(color: Colors.black),
              child:
                  _visualMode == VisualMode.needle
                      ? Center(
                        child: SizedBox(
                          height: 120,
                          width: double.infinity,
                          child: CustomPaint(painter: WavePainter(_wavePoints)),
                        ),
                      )
                      : RollingVisualizer(
                        history: _traceHistory,
                        currentCents: _visualCents,
                        centerNoteIndex: _currentLerpedNote,
                        zoom: pianoRollZoom * _dynamicZoomMultiplier,
                        scrollSpeed: scrollSpeed,
                        filteredNotes: currentPreset.notes,
                      ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 20),
            child: Column(
              children: [
                SizedBox(
                  height: 40,
                  width: double.infinity,
                  child: CustomPaint(
                    painter: CentsMeterPainter(cents.toDouble()),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  "${cents.abs()} cents ${cents > 0 ? 'sharp' : 'flat'}",
                  style: TextStyle(
                    fontSize: 16,
                    color: isCorrect ? Colors.greenAccent : Colors.white70,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
