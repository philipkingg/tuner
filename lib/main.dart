import 'dart:async';
import 'dart:math';
import 'dart:typed_data';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:pitch_detector_dart/pitch_detector.dart';
import 'package:record/record.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

void main() => runApp(const TunerApp());

enum VisualMode { needle, rollingTrace }

class TuningPreset {
  final String name;
  final List<String> notes;
  TuningPreset({required this.name, required this.notes});
}

class TunerApp extends StatelessWidget {
  const TunerApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: ThemeData.dark(useMaterial3: true),
    home: const TunerHome(),
  );
}

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

  List<double> _audioBuffer = [];
  List<double> _wavePoints = [];
  final List<double> _pitchHistory = [];

  double hz = 0.0;
  String note = "--";
  String octave = "";
  int cents = 0;

  double _currentLerpedNote = 0.0;
  bool _isInitialized = false;

  final List<TuningPreset> _presets = [
    TuningPreset(name: "Chromatic", notes: []),
    TuningPreset(name: "Guitar (Standard)", notes: ["E2", "A2", "D3", "G3", "B3", "E4"]),
    TuningPreset(name: "Guitar (7-String)", notes: ["B1", "E2", "A2", "D3", "G3", "B3", "E4"]),
    TuningPreset(name: "Bass (Standard)", notes: ["E1", "A1", "D2", "G2"]),
  ];
  int _selectedPresetIndex = 0;

  static const VisualMode _defaultVisualMode = VisualMode.rollingTrace;
  static const double _defaultTargetGain = 5.0;
  static const double _defaultSensitivity = 0.4;
  static const double _defaultSmoothingSpeed = 100.0;
  static const double _defaultPianoRollZoom = 1.0;
  static const double _defaultTraceLerpFactor = 0.15;

  VisualMode _visualMode = _defaultVisualMode;
  double gain = 1.0;
  double targetGain = _defaultTargetGain;
  double sensitivity = _defaultSensitivity;
  double smoothingSpeed = _defaultSmoothingSpeed;
  double pianoRollZoom = _defaultPianoRollZoom;
  double traceLerpFactor = _defaultTraceLerpFactor;

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
      _visualMode = VisualMode.values[_prefs!.getInt('visualMode') ?? _defaultVisualMode.index];
      targetGain = _prefs!.getDouble('targetGain') ?? _defaultTargetGain;
      sensitivity = _prefs!.getDouble('sensitivity') ?? _defaultSensitivity;
      smoothingSpeed = _prefs!.getDouble('smoothingSpeed') ?? _defaultSmoothingSpeed;
      pianoRollZoom = _prefs!.getDouble('pianoRollZoom') ?? _defaultPianoRollZoom;
      traceLerpFactor = _prefs!.getDouble('traceLerpFactor') ?? _defaultTraceLerpFactor;
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
      _visualMode = _defaultVisualMode;
      targetGain = _defaultTargetGain;
      sensitivity = _defaultSensitivity;
      smoothingSpeed = _defaultSmoothingSpeed;
      pianoRollZoom = _defaultPianoRollZoom;
      traceLerpFactor = _defaultTraceLerpFactor;
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
      if (val.abs() > peak) peak = val.abs();
    }
    if (peak >= 0.98) gain *= 0.8;
    else if (peak < 0.4 && gain < targetGain) gain *= 1.02;
    _audioBuffer.addAll(currentChunk);
    while (_audioBuffer.length >= 4096) {
      final List<double> processingBuffer = _audioBuffer.sublist(0, 4096);
      _audioBuffer.removeRange(0, 2048);
      final result = await _pitchDetector.getPitchFromFloatBuffer(processingBuffer);
      if (result.pitched && result.probability > sensitivity && result.pitch > 30) {
        _updateTunerLogic(result.pitch);
      } else {
        if (_traceHistory.isNotEmpty) _traceHistory.insert(0, _traceHistory.first);
        else _traceHistory.insert(0, const Point(0, 0));
        if (_traceHistory.length > _maxTracePoints) _traceHistory.removeLast();
      }
    }
    if (mounted) setState(() => _wavePoints = currentChunk.take(80).toList());
  }

  // Helper to convert "E2" style strings to MIDI-offset semitones (A4=0)
  double _noteToN(String noteStr) {
    const names = ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"];
    RegExp re = RegExp(r"([A-G]#?)(\d)");
    var match = re.firstMatch(noteStr);
    if (match == null) return 0;
    int noteIdx = names.indexOf(match.group(1)!);
    int octave = int.parse(match.group(2)!);
    return (noteIdx + (octave * 12)) - 57.0;
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
      // Chromatic snapping
      int roundedN = n.round();
      targetN = roundedN.toDouble();
      const noteNames = ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"];
      targetName = noteNames[(roundedN + 57) % 12];
      targetOctave = ((roundedN + 57) / 12).floor().toString();
    } else {
      // TUNING SNAP LOGIC: Find closest note in current instrument list
      double minDiff = double.infinity;
      double closestN = _noteToN(currentPreset.notes.first);
      String closestLabel = currentPreset.notes.first;

      for (var noteStr in currentPreset.notes) {
        double presetN = _noteToN(noteStr);
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

    double newCents = (n - targetN) * 100;
    _currentLerpedNote = lerpDouble(_currentLerpedNote, n, traceLerpFactor) ?? n;
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
      builder: (context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text("Select Tuning", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: _presets.length,
                itemBuilder: (context, index) {
                  final preset = _presets[index];
                  return ListTile(
                    leading: Icon(index == 0 ? Icons.blur_on : Icons.music_note, color: Colors.blueAccent),
                    title: Text(preset.name),
                    subtitle: Text(preset.notes.isEmpty ? "All notes" : preset.notes.join(" • ")),
                    trailing: _selectedPresetIndex == index ? const Icon(Icons.check, color: Colors.green) : null,
                    onTap: () {
                      setState(() {
                        _selectedPresetIndex = index;
                        _traceHistory.clear(); // Clear history when changing tuning
                      });
                      _saveSettings();
                      Navigator.pop(context);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showSettings() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.grey[900],
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Container(
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
                  setModalState(() => _visualMode = val.first);
                  setState(() => _visualMode = val.first);
                  _saveSettings();
                },
              ),
              const SizedBox(height: 16),
              if (_visualMode == VisualMode.rollingTrace) ...[
                _settingLabel("Zoom (Note Spacing)", pianoRollZoom.toStringAsFixed(1)),
                Slider(value: pianoRollZoom, min: 0.2, max: 2.0, onChanged: (v) {
                  setModalState(() => pianoRollZoom = v);
                  setState(() => pianoRollZoom = v);
                  _saveSettings();
                }),
                _settingLabel("Trace Glide", traceLerpFactor.toStringAsFixed(2)),
                Slider(value: traceLerpFactor, min: 0.01, max: 0.5, onChanged: (v) {
                  setModalState(() => traceLerpFactor = v);
                  setState(() => traceLerpFactor = v);
                  _saveSettings();
                }),
              ],
              _settingLabel("Needle Speed", "${smoothingSpeed.toInt()}ms"),
              Slider(value: smoothingSpeed, min: 50, max: 500, onChanged: (v) {
                setModalState(() => smoothingSpeed = v);
                setState(() => smoothingSpeed = v);
                _saveSettings();
              }),
              _settingLabel("Max Audio Gain", targetGain.toStringAsFixed(1)),
              Slider(value: targetGain, min: 1.0, max: 20.0, onChanged: (v) {
                setModalState(() => targetGain = v);
                setState(() => targetGain = v);
                _saveSettings();
              }),
              _settingLabel("Pitch Sensitivity", sensitivity.toStringAsFixed(2)),
              Slider(value: sensitivity, min: 0.1, max: 0.9, onChanged: (v) {
                setModalState(() => sensitivity = v);
                setState(() => sensitivity = v);
                _saveSettings();
              }),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: FilledButton.tonalIcon(
                  onPressed: () { _resetToDefaults(); setModalState(() {}); },
                  icon: const Icon(Icons.restore),
                  label: const Text("Reset to Defaults"),
                  style: FilledButton.styleFrom(backgroundColor: Colors.redAccent.withOpacity(0.1), foregroundColor: Colors.redAccent),
                ),
              ),
            ]),
          ),
        ),
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

  @override
  Widget build(BuildContext context) {
    if (!_isInitialized) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    bool isCorrect = cents.abs() < 5 && note != "--";
    final currentPreset = _presets[_selectedPresetIndex];

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        leading: IconButton(
          onPressed: _showTuningMenu,
          icon: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            const Icon(Icons.tune, size: 20),
            Text(currentPreset.name.split(' ').first, style: const TextStyle(fontSize: 8)),
          ]),
        ),
        actions: [IconButton(onPressed: _showSettings, icon: const Icon(Icons.settings))],
      ),
      body: Column(children: [
        RichText(text: TextSpan(children: [
          TextSpan(text: note, style: TextStyle(fontSize: 100, fontWeight: FontWeight.bold, color: isCorrect ? Colors.green : Colors.white)),
          TextSpan(text: octave, style: TextStyle(fontSize: 30, color: Colors.blueAccent.withOpacity(0.7), fontFeatures: const [FontFeature.subscripts()])),
        ])),
        Text("${hz.toStringAsFixed(1)} Hz", style: const TextStyle(fontSize: 20, color: Colors.blueAccent)),
        Expanded(
          child: Container(
            margin: const EdgeInsets.symmetric(vertical: 20),
            width: double.infinity,
            clipBehavior: Clip.hardEdge,
            decoration: const BoxDecoration(color: Colors.black),
            child: _visualMode == VisualMode.needle
                ? Center(child: SizedBox(height: 120, width: double.infinity, child: CustomPaint(painter: WavePainter(_wavePoints))))
                : CustomPaint(painter: RollingRollPainter(_traceHistory, _currentLerpedNote, pianoRollZoom, currentPreset.notes)),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 20),
          child: Column(children: [
            SizedBox(height: 40, width: double.infinity, child: CustomPaint(painter: CentsMeterPainter(cents.toDouble()))),
            const SizedBox(height: 10),
            Text("${cents.abs()} cents ${cents > 0 ? 'sharp' : 'flat'}", style: TextStyle(fontSize: 16, color: isCorrect ? Colors.green : Colors.white70)),
          ]),
        ),
      ]),
    );
  }
}

class CentsMeterPainter extends CustomPainter {
  final double cents;
  CentsMeterPainter(this.cents);

  @override
  void paint(Canvas canvas, Size size) {
    final double midX = size.width / 2;
    final double range = 50.0;
    canvas.drawLine(Offset(0, size.height / 2), Offset(size.width, size.height / 2), Paint()..color = Colors.white12..strokeWidth = 2);
    for (int i = -50; i <= 50; i += 10) {
      double x = midX + (i / range) * midX;
      bool isCenter = i == 0;
      double h = isCenter ? 20 : (i % 50 == 0 ? 15 : 8);
      canvas.drawLine(Offset(x, (size.height / 2) - h/2), Offset(x, (size.height / 2) + h/2), Paint()..color = isCenter ? Colors.white70 : Colors.white24..strokeWidth = isCenter ? 2 : 1);
    }
    double needleX = midX + (cents.clamp(-50, 50) / range) * midX;
    canvas.drawLine(Offset(needleX, 0), Offset(needleX, size.height), Paint()..color = _getNeedleColor(cents.abs())..strokeWidth = 3..strokeCap = StrokeCap.round);
  }

  Color _getNeedleColor(double absCents) => absCents < 5 ? Colors.greenAccent : (absCents < 20 ? Colors.yellowAccent : Colors.redAccent);
  @override bool shouldRepaint(CentsMeterPainter old) => old.cents != cents;
}

class RollingRollPainter extends CustomPainter {
  final List<Point<double>> history;
  final double centerNoteIndex;
  final double zoom;
  final List<String> filteredNotes;
  RollingRollPainter(this.history, this.centerNoteIndex, this.zoom, this.filteredNotes);

  static const noteNames = ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"];

  double _noteToN(String noteStr) {
    RegExp re = RegExp(r"([A-G]#?)(\d)");
    var match = re.firstMatch(noteStr);
    if (match == null) return 0;
    int noteIdx = noteNames.indexOf(match.group(1)!);
    int octave = int.parse(match.group(2)!);
    return (noteIdx + (octave * 12)) - 57.0;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final double midX = size.width / 2;
    final double stepX = (size.width / 2) * zoom;
    final double drawingHeight = size.height - 40.0;

    _drawGrid(canvas, size, drawingHeight, midX, stepX);

    if (history.isEmpty) return;
    final path = Path();
    for (int i = 0; i < history.length; i++) {
      double xPos = midX + ((history[i].y - centerNoteIndex) * stepX);
      double yPos = drawingHeight - (i * (drawingHeight / 120));
      if (i == 0) path.moveTo(xPos, yPos); else path.lineTo(xPos, yPos);
    }
    canvas.drawPath(path, Paint()..color = _getColor(history.first.x.abs())..strokeWidth = 3.5..style = PaintingStyle.stroke..strokeJoin = StrokeJoin.round);
    canvas.drawLine(Offset(midX, 0), Offset(midX, drawingHeight), Paint()..color = Colors.white.withOpacity(0.3)..strokeWidth = 1.5);
  }

  void _drawGrid(Canvas canvas, Size size, double drawingHeight, double midX, double stepX) {
    if (filteredNotes.isEmpty) {
      // Chromatic Grid
      int minN = (centerNoteIndex - (1 / zoom) - 2).floor();
      int maxN = (centerNoteIndex + (1 / zoom) + 2).ceil();
      for (int n = minN; n <= maxN; n++) {
        _drawSingleLine(canvas, n.toDouble(), midX, stepX, drawingHeight);
      }
    } else {
      // TUNING GRID: Only show notes in the preset
      for (var noteStr in filteredNotes) {
        _drawSingleLine(canvas, _noteToN(noteStr), midX, stepX, drawingHeight);
      }
    }
  }

  void _drawSingleLine(Canvas canvas, double n, double midX, double stepX, double drawingHeight) {
    double xPos = midX + ((n - centerNoteIndex) * stepX);
    if (xPos < -50 || xPos > midX * 2 + 50) return;

    bool isActive = (n - centerNoteIndex).abs() < 0.2;
    canvas.drawLine(Offset(xPos, 0), Offset(xPos, drawingHeight), Paint()
      ..color = isActive ? Colors.blueAccent.withOpacity(0.6) : Colors.white.withOpacity(0.08)
      ..strokeWidth = isActive ? 3 : 1);

    String label = "${noteNames[((n + 57) % 12).toInt()]}${((n + 57) / 12).floor()}";
    TextPainter(text: TextSpan(text: label, style: TextStyle(color: isActive ? Colors.blueAccent : Colors.white.withOpacity(0.4), fontSize: isActive ? 14 : 11, fontWeight: FontWeight.bold)), textDirection: TextDirection.ltr)
      ..layout()..paint(canvas, Offset(xPos - 8, drawingHeight + 5));
  }

  Color _getColor(double cents) {
    if (cents < 5) return Colors.greenAccent;
    if (cents < 20) return Color.lerp(Colors.greenAccent, Colors.yellowAccent, (cents - 5) / 15)!;
    return Color.lerp(Colors.yellowAccent, Colors.redAccent, (cents - 20) / 30.0.clamp(0.1, 1.0))!;
  }
  @override bool shouldRepaint(RollingRollPainter old) => true;
}

class WavePainter extends CustomPainter {
  final List<double> points;
  WavePainter(this.points);
  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty) return;
    final path = Path()..moveTo(0, size.height / 2);
    for (var i = 0; i < points.length; i++) path.lineTo(size.width * (i / points.length), (size.height / 2) + (points[i] * size.height / 2));
    canvas.drawPath(path, Paint()..color = Colors.blueAccent..strokeWidth = 3.0..style = PaintingStyle.stroke);
  }
  @override bool shouldRepaint(covariant CustomPainter old) => true;
}