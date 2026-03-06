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
import '../../models/app_theme.dart';
import '../../models/tuning_preset.dart';
import '../../models/visual_mode.dart';
import '../../models/spectral_frame.dart';
import '../../utils/note_utils.dart';
import '../painters/wave_painter.dart';
import '../painters/cents_meter_painter.dart';
import '../widgets/rolling_visualizer.dart';
import '../widgets/spectrograph_visualizer.dart';
import '../../models/trace_point.dart';
import '../widgets/settings_sheet.dart';
import '../widgets/tuning_menu.dart';
import '../widgets/add_tuning_dialog.dart';
import '../../utils/app_constants.dart';
import '../../main.dart';

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
  final List<SpectralFrame> _spectralFrames = [];
  double _spectroRunningMax = 100.0;

  final List<double> _audioBuffer = [];
  List<double> _wavePoints = [];
  final List<double> _pitchHistory = [];

  double hz = 0.0;
  String note = "--";
  String octave = "";
  int cents = 0;

  double _currentLerpedNote = 0.0;
  double _emaHz = 0.0;
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
    appThemeNotifier.addListener(_onThemeChange);
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
    );
    _initApp();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    appThemeNotifier.removeListener(_onThemeChange);
    platform.invokeMethod('toggle', false);
    _stopTuning();
    _audioRecorder.dispose();
    _needleController.dispose();
    super.dispose();
  }

  void _onThemeChange() {
    if (mounted) setState(() {});
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

      final themeIndex = _prefs!.getInt('colorTheme') ?? 0;
      appThemeNotifier.value = AppColorTheme.values[themeIndex];

      List<String>? savedPresets = _prefs!.getStringList('saved_presets');
      if (savedPresets != null && savedPresets.isNotEmpty) {
        _presets =
            savedPresets
                .map((e) => TuningPreset.fromJson(jsonDecode(e)))
                .toList();
      } else {
        _presets = List.from(_kDefaultPresets);
      }

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
    await _prefs!.setInt('colorTheme', appThemeNotifier.value.index);

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
      appThemeNotifier.value = AppColorTheme.earthy;
      _presets = List.from(_kDefaultPresets);
    });
    _saveSettings();
  }

  static const platform = MethodChannel('com.philip.centigrade/wakelock');

  Future<void> _startTuning() async {
    if (_audioStreamSubscription != null) return;

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
      _audioBuffer.removeRange(0, AppConstants.audioBufferStride);
      // Spectral analysis: only in spectrograph mode, every other cycle (~21 fps)
      if (_visualMode == VisualMode.spectrograph) {
        _spectroSkip++;
        if (_spectroSkip >= 2) {
          _spectroSkip = 0;
          final SpectralFrame frame = _computeSpectralFrame(processingBuffer);
          _spectralFrames.add(frame);
          if (_spectralFrames.length > AppConstants.maxSpectralFrames) {
            _spectralFrames.removeAt(0);
          }
        }
      }

      final result = await _pitchDetector.getPitchFromFloatBuffer(
        processingBuffer,
      );
      if (result.pitched &&
          result.probability > sensitivity &&
          result.pitch > 30) {
        _updateTunerLogic(result.pitch);
      }
    }
    if (mounted) setState(() => _wavePoints = currentChunk.take(80).toList());
  }

  // --- Spectrograph ---

  // Goertzel coefficients precomputed once (2*cos(2π·f/sampleRate) per bin).
  // Using a smaller window (2048 samples) halves CPU vs the 4096 pitch window.
  static const int _spectroWindowSize = 2048;
  static final List<double> _spectroCoeffs = List<double>.generate(
    AppConstants.spectroNumBins,
    (i) {
      final int noteN = AppConstants.spectroMinN + i;
      final double freq = 440.0 * pow(2.0, noteN / 12.0);
      final double omega = 2 * pi * freq / AppConstants.audioSampleRate;
      return 2 * cos(omega);
    },
  );

  // Skip counter — compute spectro every other detection cycle (~21 fps).
  int _spectroSkip = 0;

  double _goertzelCoeff(List<double> samples, int n, double coeff) {
    double s1 = 0, s2 = 0;
    for (int i = 0; i < n; i++) {
      final double s0 = samples[i] + coeff * s1 - s2;
      s2 = s1;
      s1 = s0;
    }
    return sqrt((s1 * s1 + s2 * s2 - coeff * s1 * s2).abs());
  }

  SpectralFrame _computeSpectralFrame(List<double> samples) {
    final int n = samples.length.clamp(0, _spectroWindowSize);
    final List<double> rawMags =
        List<double>.filled(AppConstants.spectroNumBins, 0.0);

    for (int i = 0; i < AppConstants.spectroNumBins; i++) {
      rawMags[i] = _goertzelCoeff(samples, n, _spectroCoeffs[i]);
    }

    // Adaptive running peak with slow decay
    final double framePeak = rawMags.reduce(max);
    if (framePeak > _spectroRunningMax) _spectroRunningMax = framePeak;
    _spectroRunningMax =
        (_spectroRunningMax * 0.999).clamp(100.0, double.infinity);

    // Log-scale normalisation: log₁₀(1 + x·9) → [0, 1]
    int loudestBin = 0;
    double maxNorm = 0;
    final List<double> normalized =
        List<double>.filled(AppConstants.spectroNumBins, 0.0);
    for (int i = 0; i < rawMags.length; i++) {
      final double v =
          (log(1.0 + rawMags[i] / _spectroRunningMax * 9.0) / log(10.0))
              .clamp(0.0, 1.0);
      normalized[i] = v;
      if (v > maxNorm) {
        maxNorm = v;
        loudestBin = i;
      }
    }

    return SpectralFrame(
      magnitudes: normalized,
      loudestBin: loudestBin,
      timestamp: DateTime.now().millisecondsSinceEpoch,
    );
  }

  // Stabilization State
  double? _lastConfirmedPitch;
  int _jumpGuardCounter = 0;
  static const int _jumpGuardThreshold = AppConstants.jumpGuardThreshold;

  void _updateTunerLogic(double newPitch) {
    if (_lastConfirmedPitch != null) {
      double semitoneDiff =
          12 * (log(newPitch / _lastConfirmedPitch!) / log(2));
      if (semitoneDiff.abs() > 3.0) {
        _jumpGuardCounter++;
        if (_jumpGuardCounter < _jumpGuardThreshold) {
          return;
        }
        _lastConfirmedPitch = newPitch;
        _jumpGuardCounter = 0;
        _pitchHistory.clear();
        _emaHz = 0.0;
      } else {
        _lastConfirmedPitch = newPitch;
        _jumpGuardCounter = 0;
      }
    } else {
      _lastConfirmedPitch = newPitch;
    }

    _pitchHistory.add(newPitch);
    if (_pitchHistory.length > 9) _pitchHistory.removeAt(0);
    if (_emaHz == 0.0) {
      _emaHz = newPitch;
    } else {
      _emaHz =
          AppConstants.emaAlpha * newPitch + (1.0 - AppConstants.emaAlpha) * _emaHz;
    }
    final double medianHz = _emaHz;

    if ((medianHz - 60).abs() < 5 || (medianHz - 120).abs() < 8) {
      if (_pitchHistory.length < 7) {
        return;
      }
      double variance = 0;
      for (var hz in _pitchHistory) {
        variance += (hz - medianHz).abs();
      }
      variance /= _pitchHistory.length;
      if (variance > 2.0) {
        return;
      }
    }

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
        double presetN = NoteUtils.getClosestN(noteStr, n);
        double diff = (n - presetN).abs();
        if (diff < minDiff) {
          minDiff = diff;
          closestN = presetN;
          closestLabel = noteStr;
        }
      }
      targetN = closestN;

      if (NoteUtils.isGeneric(closestLabel)) {
        targetName = closestLabel;
        int oct = ((targetN + 57) / 12).floor();
        targetOctave = oct.toString();
      } else {
        RegExp re = RegExp(r"([A-G]#?)(\d+)");
        var match = re.firstMatch(closestLabel);
        targetName = match?.group(1) ?? "--";
        targetOctave = match?.group(2) ?? "";
      }
    }

    double distance = (n - targetN).abs();
    double targetZoomMult = 1.0;
    if (distance > 0.5) {
      targetZoomMult = (1.0 / (distance * 1.5)).clamp(0.2, 1.0);
    }

    double newCents = (n - targetN) * 100;
    _currentLerpedNote =
        lerpDouble(_currentLerpedNote, n, traceLerpFactor) ?? n;
    _dynamicZoomMultiplier =
        lerpDouble(_dynamicZoomMultiplier, targetZoomMult, 0.3) ?? 1.0;

    _traceHistory.add(
      TracePoint(
        cents: newCents,
        note: _currentLerpedNote,
        timestamp: DateTime.now().millisecondsSinceEpoch,
      ),
    );
    if (_traceHistory.length > AppConstants.maxTracePoints) {
      _traceHistory.removeAt(0);
    }

    if (mounted) {
      setState(() {
        hz = medianHz;
        note = targetName;
        octave = targetOctave;
        cents = newCents.round();
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
    final tc = AppThemeColors.fromType(appThemeNotifier.value);
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppConstants.tuningMenuBorderRadius),
        ),
      ),
      builder:
          (context) => TuningMenu(
            themeColors: tc,
            presets: _presets,
            selectedIndex: _selectedPresetIndex,
            onPresetSelected: (index) {
              setState(() {
                _selectedPresetIndex = index;
                _traceHistory.clear();
                _dynamicZoomMultiplier = pianoRollZoom;
              });
              _saveSettings();
            },
            onCreateNew: () {
              Navigator.pop(context);
              showDialog(
                context: context,
                builder:
                    (context) => AddTuningDialog(
                      themeColors: tc,
                      onAdd: (newPreset) {
                        setState(() {
                          _presets.add(newPreset);
                          _selectedPresetIndex = _presets.length - 1;
                          _traceHistory.clear();
                          _dynamicZoomMultiplier = pianoRollZoom;
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
                _dynamicZoomMultiplier = pianoRollZoom;
              });
              Navigator.pop(context);
              _saveSettings();
            },
            onRestoreDefaults: () {
              setState(() {
                for (var defaultPreset in _kDefaultPresets) {
                  bool exists = _presets.any(
                    (p) => p.name == defaultPreset.name,
                  );
                  if (!exists) {
                    _presets.add(defaultPreset);
                  }
                }
                _traceHistory.clear();
              });
              _saveSettings();
            },
          ),
    );
  }

  void _showSettings() {
    final tc = AppThemeColors.fromType(appThemeNotifier.value);
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppConstants.tuningMenuBorderRadius),
        ),
      ),
      builder:
          (context) => SettingsSheet(
            themeColors: tc,
            visualMode: _visualMode,
            targetGain: targetGain,
            sensitivity: sensitivity,
            smoothingSpeed: smoothingSpeed,
            pianoRollZoom: pianoRollZoom,
            traceLerpFactor: traceLerpFactor,
            scrollSpeed: scrollSpeed,
            selectedColorTheme: appThemeNotifier.value,
            onColorThemeChanged: (t) {
              appThemeNotifier.value = t;
              _saveSettings();
            },
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
    final tc = AppThemeColors.fromType(appThemeNotifier.value);

    if (!_isInitialized) {
      return Scaffold(
        backgroundColor: tc.background,
        body: Center(
          child: CircularProgressIndicator(
            color: tc.primary,
            strokeWidth: 2,
          ),
        ),
      );
    }

    bool isCorrect = cents.abs() < 5 && note != "--";
    final currentPreset = _presets[_selectedPresetIndex];

    return Scaffold(
      backgroundColor: tc.background,
      appBar: AppBar(
        backgroundColor: tc.background,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        automaticallyImplyLeading: false,
        titleSpacing: 12,
        title: Row(
          children: [
            GestureDetector(
              onTap: _showTuningMenu,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                decoration: BoxDecoration(
                  color: tc.surface,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: tc.border, width: 1),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.tune_rounded, size: 14, color: tc.primary),
                    const SizedBox(width: 6),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 130),
                      child: Text(
                        currentPreset.name,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: tc.textPrimary,
                        ),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      Icons.keyboard_arrow_down_rounded,
                      size: 14,
                      color: tc.textSecondary,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        actions: [
          Stack(
            alignment: Alignment.topRight,
            children: [
              IconButton(
                onPressed: _showSettings,
                icon: Icon(
                  Icons.settings_outlined,
                  color: tc.textSecondary,
                  size: 22,
                ),
              ),
              if (!_hasMicPermission)
                Positioned(
                  top: 10,
                  right: 10,
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: Color(0xFFFF453A),
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          _buildNoteDisplay(tc, isCorrect),
          Expanded(
            child: Container(
              clipBehavior: Clip.hardEdge,
              decoration: BoxDecoration(color: tc.background),
              child:
                  switch (_visualMode) {
                    VisualMode.needle => Center(
                      child: SizedBox(
                        height: 120,
                        width: double.infinity,
                        child: CustomPaint(
                          painter: WavePainter(
                            _wavePoints,
                            color: tc.primary,
                          ),
                        ),
                      ),
                    ),
                    VisualMode.rollingTrace => RollingVisualizer(
                      history: _traceHistory,
                      currentCents: cents.toDouble(),
                      centerNoteIndex: _currentLerpedNote,
                      zoom: pianoRollZoom * _dynamicZoomMultiplier,
                      scrollSpeed: scrollSpeed,
                      filteredNotes: currentPreset.notes,
                      gridLineColor: tc.border,
                      gridLineActiveColor: tc.gridLineActive,
                    ),
                    VisualMode.spectrograph => SpectrographVisualizer(
                      frames: _spectralFrames,
                      primaryColor: tc.primary,
                      backgroundColor: tc.background,
                    ),
                  },
            ),
          ),
          _buildCentsMeter(tc, isCorrect),
        ],
      ),
    );
  }

  Widget _buildNoteDisplay(AppThemeColors tc, bool isCorrect) {
    final Color noteColor = isCorrect ? tc.inTune : tc.textPrimary;

    return SizedBox(
      height: 180,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Radial glow when in tune
          if (isCorrect)
            IgnorePointer(
              child: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      tc.inTune.withValues(alpha: 0.18),
                      Colors.transparent,
                    ],
                    radius: 0.65,
                  ),
                ),
              ),
            ),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Note name + octave
              Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    note,
                    style: TextStyle(
                      fontSize: 96,
                      fontWeight: FontWeight.w200,
                      color: noteColor,
                      height: 1.0,
                      letterSpacing: -2,
                      shadows:
                          isCorrect
                              ? [
                                Shadow(
                                  blurRadius: 28,
                                  color: tc.inTune.withValues(alpha: 0.5),
                                ),
                              ]
                              : null,
                    ),
                  ),
                  if (octave.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 14),
                      child: Text(
                        octave,
                        style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w400,
                          color: tc.primary.withValues(alpha: 0.75),
                          height: 1.0,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 4),
              // Hz readout
              Text(
                hz > 0 ? "${hz.toStringAsFixed(1)} Hz" : "— Hz",
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: tc.textSecondary,
                  letterSpacing: 0.8,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCentsMeter(AppThemeColors tc, bool isCorrect) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 14),
      decoration: BoxDecoration(
        color: tc.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isCorrect
              ? tc.inTune.withValues(alpha: 0.35)
              : tc.border,
          width: 1,
        ),
      ),
      child: AnimatedBuilder(
        animation: _needleAnimation,
        builder: (context, child) {
          final int animatedCents = _needleAnimation.value.round();
          final bool animatedCorrect = animatedCents.abs() < 5 && note != "--";
          return Column(
            children: [
              SizedBox(
                height: 40,
                width: double.infinity,
                child: CustomPaint(
                  painter: CentsMeterPainter(
                    animatedCents.toDouble(),
                    trackColor: tc.border,
                    inTuneColor: tc.inTune,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                animatedCorrect
                    ? "in tune"
                    : "${animatedCents.abs()} cents ${animatedCents > 0 ? 'sharp' : 'flat'}",
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: animatedCorrect ? tc.inTune : tc.textSecondary,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
