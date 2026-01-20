import 'dart:async';
import 'dart:math';
import 'dart:typed_data';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:pitch_detector_dart/pitch_detector.dart';
import 'package:record/record.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() => runApp(const TunerApp());

enum VisualMode { needle, rollingTrace }

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

class _TunerHomeState extends State<TunerHome> with SingleTickerProviderStateMixin {
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
  int currentNoteIndex = 0;
  bool _isInitialized = false;

  VisualMode _visualMode = VisualMode.rollingTrace;
  double gain = 1.0;
  double targetGain = 5.0;
  double sensitivity = 0.4;
  double smoothingSpeed = 100.0;
  double pianoRollZoom = 1.0;

  @override
  void initState() {
    super.initState();
    _pitchDetector = PitchDetector(audioSampleRate: 44100, bufferSize: 4096);
    _needleController = AnimationController(vsync: this, duration: const Duration(milliseconds: 100));
    _needleAnimation = Tween<double>(begin: 0, end: 0).animate(
        CurvedAnimation(parent: _needleController, curve: Curves.easeOutCubic)
    )..addListener(() {
      if (mounted) setState(() => cents = _needleAnimation.value.round());
    });
    _initApp();
  }

  Future<void> _initApp() async {
    try {
      _prefs = await SharedPreferences.getInstance();
      _loadSettings();
    } catch (e) {
      debugPrint("Prefs error: $e");
    }
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
  }

  Future<void> _startTuning() async {
    if (await _audioRecorder.hasPermission()) {
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
        _traceHistory.insert(0, const Point(-999.0, -999.0));
        if (_traceHistory.length > _maxTracePoints) _traceHistory.removeLast();
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
    int roundedN = n.round();
    const noteNames = ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"];

    int chromaticIndex = (roundedN + 57) % 12;
    int detectedOctave = ((roundedN + 57) / 12).floor();
    double newCents = (n - roundedN) * 100;

    _traceHistory.insert(0, Point(newCents, n));
    if (_traceHistory.length > _maxTracePoints) _traceHistory.removeLast();

    if (mounted) {
      setState(() {
        hz = medianHz;
        note = noteNames[chromaticIndex];
        octave = detectedOctave.toString();
        currentNoteIndex = roundedN;
      });
      _needleAnimation = Tween<double>(begin: _needleAnimation.value, end: newCents).animate(
          CurvedAnimation(parent: _needleController, curve: Curves.easeOut)
      );
      _needleController.duration = Duration(milliseconds: smoothingSpeed.toInt());
      _needleController.forward(from: 0);
    }
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
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text("Tuning Settings", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            const Divider(height: 32, color: Colors.white24),

            const Text("Visual Mode", style: TextStyle(color: Colors.grey)),
            const SizedBox(height: 8),
            SegmentedButton<VisualMode>(
              segments: const [
                ButtonSegment(value: VisualMode.needle, label: Text("Oscilloscope"), icon: Icon(Icons.waves)),
                ButtonSegment(value: VisualMode.rollingTrace, label: Text("Piano Roll"), icon: Icon(Icons.linear_scale)),
              ],
              selected: {_visualMode},
              onSelectionChanged: (val) {
                setModalState(() => _visualMode = val.first);
                setState(() => _visualMode = val.first);
                _saveSettings();
              },
            ),
            _settingLabel("Note Spacing", pianoRollZoom.toStringAsFixed(1)),
            Slider(value: pianoRollZoom, min: 0.5, max: 4.0, onChanged: (v) {
              setModalState(() => pianoRollZoom = v);
              setState(() => pianoRollZoom = v);
              _saveSettings();
            }),
            _settingLabel("Lerp Speed", "${smoothingSpeed.toInt()}ms"),
            Slider(value: smoothingSpeed, min: 50, max: 500, onChanged: (v) {
              setModalState(() => smoothingSpeed = v);
              setState(() => smoothingSpeed = v);
              _saveSettings();
            }),
            _settingLabel("Gain Cap", "${targetGain.toStringAsFixed(1)}x"),
            Slider(value: targetGain, min: 1.0, max: 20.0, onChanged: (v) {
              setModalState(() => targetGain = v);
              setState(() => targetGain = v);
              _saveSettings();
            }),
          ]),
        ),
      ),
    );
  }

  Widget _settingLabel(String title, String value) {
    return Padding(
      padding: const EdgeInsets.only(top: 16.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title, style: const TextStyle(color: Colors.white70)),
          Text(value, style: const TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _needleController.dispose();
    _audioStreamSubscription?.cancel();
    _audioRecorder.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isInitialized) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    bool isCorrect = cents.abs() < 5 && note != "--";

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(backgroundColor: Colors.transparent, actions: [
        IconButton(onPressed: _showSettings, icon: const Icon(Icons.settings))
      ]),
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
            decoration: const BoxDecoration(), // Added fix for Clip assertion
            child: _visualMode == VisualMode.needle
                ? Center(child: SizedBox(height: 120, width: double.infinity, child: CustomPaint(painter: WavePainter(_wavePoints))))
                : CustomPaint(painter: RollingRollPainter(_traceHistory, currentNoteIndex.toDouble(), pianoRollZoom)),
          ),
        ),

        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 20),
          child: Column(children: [
            Slider(value: cents.toDouble().clamp(-50, 50), min: -50, max: 50, onChanged: null, activeColor: isCorrect ? Colors.green : Colors.red),
            Text(cents == 0 ? "Perfect" : "${cents.abs()} cents ${cents > 0 ? 'sharp' : 'flat'}",
                style: TextStyle(fontSize: 16, color: isCorrect ? Colors.green : Colors.white70)),
          ]),
        ),
      ]),
    );
  }
}

class RollingRollPainter extends CustomPainter {
  final List<Point<double>> history;
  final double centerNoteIndex;
  final double zoom;
  RollingRollPainter(this.history, this.centerNoteIndex, this.zoom);

  @override
  void paint(Canvas canvas, Size size) {
    final double midX = size.width / 2;
    final double stepX = (size.width / 2) * zoom;

    canvas.drawLine(Offset(midX, 0), Offset(midX, size.height), Paint()..color = Colors.green.withOpacity(0.3)..strokeWidth = 2);

    if (history.isEmpty) return;
    final path = Path();
    bool first = true;

    for (int i = 0; i < history.length; i++) {
      if (history[i].x == -999.0) { first = true; continue; }

      double relativeSemitones = history[i].y - centerNoteIndex;
      double xPos = midX + (relativeSemitones * stepX);
      double yPos = size.height - (i * (size.height / 120));

      if (first) { path.moveTo(xPos, yPos); first = false; }
      else { path.lineTo(xPos, yPos); }
    }

    // Safely check history.first to determine current color
    double currentCents = history.isNotEmpty ? history.first.x.abs() : 0.0;
    double t = (currentCents / 30.0).clamp(0.0, 1.0);
    Color lineColor = Color.lerp(Colors.greenAccent, Colors.redAccent, t)!;

    canvas.drawPath(path, Paint()
      ..color = lineColor
      ..strokeWidth = 3.0
      ..style = PaintingStyle.stroke
      ..strokeJoin = StrokeJoin.round);
  }
  @override bool shouldRepaint(RollingRollPainter old) => true;
}

class WavePainter extends CustomPainter {
  final List<double> points;
  WavePainter(this.points);
  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty) return;
    final paint = Paint()..color = Colors.blueAccent..strokeWidth = 3.0..style = PaintingStyle.stroke;
    final path = Path()..moveTo(0, size.height / 2);
    for (var i = 0; i < points.length; i++) {
      path.lineTo(size.width * (i / points.length), (size.height / 2) + (points[i] * size.height / 2));
    }
    canvas.drawPath(path, paint);
  }
  @override bool shouldRepaint(covariant CustomPainter old) => true;
}