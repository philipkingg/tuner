import 'dart:async';
import 'dart:math';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:pitch_detector_dart/pitch_detector.dart';
import 'package:record/record.dart';

void main() => runApp(const TunerApp());

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

class _TunerHomeState extends State<TunerHome> {
  final _audioRecorder = AudioRecorder();

  // INCREASED BUFFER: 4096 provides much better frequency resolution
  final _pitchDetector = PitchDetector(audioSampleRate: 44100, bufferSize: 4096);
  StreamSubscription<Uint8List>? _audioStreamSubscription;

  List<double> _audioBuffer = [];
  List<double> _wavePoints = [];
  List<double> _pitchHistory = []; // For Median Smoothing

  double hz = 0.0;
  String note = "--";
  int cents = 0;
  double gain = 1.0;
  double sensitivity = 0.6; // Probability threshold

  @override
  void initState() {
    super.initState();
    _startTuning();
  }

  Future<void> _startTuning() async {
    if (await _audioRecorder.hasPermission()) {
      const config = RecordConfig(
        encoder: AudioEncoder.pcm16bits,
        sampleRate: 44100,
        numChannels: 1,
      );

      final stream = await _audioRecorder.startStream(config);
      _audioStreamSubscription = stream.listen((Uint8List data) {
        _processBytes(data);
      });
    }
  }

  void _processBytes(Uint8List data) async {
    // Use ByteData to handle endianness correctly
    final ByteData byteData = ByteData.sublistView(data);
    final List<double> currentChunk = [];

    // Iterate through bytes 2 at a time (16-bit = 2 bytes)
    for (int i = 0; i < data.length - 1; i += 2) {
      // We try Little Endian first. If the wave still looks like a sawtooth,
      // change 'true' to 'false' for Big Endian.
      int sample = byteData.getInt16(i, Endian.little);
      currentChunk.add((sample / 32768.0 * gain).clamp(-1.0, 1.0));
    }

    if (mounted) {
      setState(() => _wavePoints = currentChunk.take(150).toList());
    }

    // Noise gate
    double rms = sqrt(currentChunk.map((x) => x * x).reduce((a, b) => a + b) / currentChunk.length);
    if (rms < 0.2) return;

    _audioBuffer.addAll(currentChunk);

    while (_audioBuffer.length >= 4096) {
      final processingBuffer = _audioBuffer.sublist(0, 4096);
      _audioBuffer.removeRange(0, 2048);

      final result = await _pitchDetector.getPitchFromFloatBuffer(processingBuffer);

      if (result.pitched && result.probability > sensitivity) {
        _smoothPitch(result.pitch);
      }
    }
  }

  // Median Smoothing: Prevents the UI from jumping if one bad reading hits
  void _smoothPitch(double newPitch) {
    _pitchHistory.add(newPitch);
    if (_pitchHistory.length > 5) _pitchHistory.removeAt(0);

    List<double> sorted = List.from(_pitchHistory)..sort();
    double median = sorted[sorted.length ~/ 2];
    _updateUI(median);
  }

  void _updateUI(double frequency) {
    const notes = ["A", "A#", "B", "C", "C#", "D", "D#", "E", "F", "F#", "G", "G#"];
    double n = 12 * (log(frequency / 440) / log(2));
    int roundedN = n.round();
    String detectedNote = notes[(roundedN % 12 + 12) % 12];
    int detectedCents = ((n - roundedN) * 100).toInt();

    if (mounted) {
      setState(() {
        hz = frequency;
        note = detectedNote;
        cents = detectedCents;
      });
    }
  }

  @override
  void dispose() {
    _audioStreamSubscription?.cancel();
    _audioRecorder.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 40),
            Text(note, style: const TextStyle(fontSize: 120, fontWeight: FontWeight.bold)),
            Text("${hz.toStringAsFixed(1)} Hz",
                style: const TextStyle(fontSize: 24, color: Colors.blueAccent)),

            const Spacer(),
            SizedBox(
              height: 100,
              width: double.infinity,
              child: CustomPaint(painter: WavePainter(_wavePoints)),
            ),
            const Spacer(),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 30),
              child: Column(
                children: [
                  Text("Sensitivity: ${(sensitivity * 100).toInt()}%"),
                  Slider(
                    value: sensitivity,
                    min: 0.1,
                    max: 0.9,
                    onChanged: (v) => setState(() => sensitivity = v),
                  ),
                  Text("Gain: ${gain.toStringAsFixed(1)}x"),
                  Slider(
                    value: gain,
                    min: 0.5,
                    max: 50.0,
                    onChanged: (v) => setState(() => gain = v),
                  ),
                  const SizedBox(height: 20),
                  Slider(value: cents.toDouble().clamp(-50, 50), min: -50, max: 50, onChanged: null),
                  Text("$cents Cents"),
                ],
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}

class WavePainter extends CustomPainter {
  final List<double> points;
  WavePainter(this.points);
  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty) return;
    final paint = Paint()
      ..color = points.any((p) => p.abs() >= 0.98) ? Colors.red : Colors.blueAccent
      ..strokeWidth = 2.0..style = PaintingStyle.stroke;
    final path = Path()..moveTo(0, size.height / 2);
    for (var i = 0; i < points.length; i++) {
      path.lineTo(size.width * (i / points.length), (size.height / 2) + (points[i] * size.height / 2));
    }
    canvas.drawPath(path, paint);
  }
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}