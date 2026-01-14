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
  Widget build(BuildContext context) => MaterialApp(theme: ThemeData.dark(), home: const TunerHome());
}

class TunerHome extends StatefulWidget {
  const TunerHome({super.key});
  @override
  State<TunerHome> createState() => _TunerHomeState();
}

class _TunerHomeState extends State<TunerHome> {
  final _audioRecorder = AudioRecorder();
  final _pitchDetector = PitchDetector(audioSampleRate: 44100, bufferSize: 2048);
  StreamSubscription<Uint8List>? _audioStreamSubscription;

  double hz = 0.0;
  String note = "--";
  int cents = 0;

  @override
  void initState() {
    super.initState();
    _startTuning();
  }

  Future<void> _startTuning() async {
    if (await _audioRecorder.hasPermission()) {
      // Configure for raw PCM 16-bit
      const config = RecordConfig(
        encoder: AudioEncoder.pcm16bits,
        sampleRate: 44100,
        numChannels: 1,
      );

      final stream = await _audioRecorder.startStream(config);

      _audioStreamSubscription = stream.listen((Uint8List data) async {
        // Convert the byte array (Uint8List) to double list for the pitch detector
        // PCM 16-bit means 2 bytes per sample.
        final Int16List int16Data = data.buffer.asInt16List();
        final List<double> doubleBuffer = int16Data.map((e) => e / 32768.0).toList();

        final result = await _pitchDetector.getPitchFromFloatBuffer(doubleBuffer);
        if (result.pitched && result.probability > 0.8) {
          _updateMusicalData(result.pitch);
        }
      });
    }
  }

  void _updateMusicalData(double frequency) {
    const notes = ["A", "A#", "B", "C", "C#", "D", "D#", "E", "F", "F#", "G", "G#"];
    double n = 12 * (log(frequency / 440) / log(2));
    int roundedN = n.round();
    String detectedNote = notes[(roundedN % 12 + 12) % 12];
    int detectedCents = ((n - roundedN) * 100).toInt();

    setState(() {
      hz = frequency;
      note = detectedNote;
      cents = detectedCents;
    });
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
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(note, style: const TextStyle(fontSize: 100, fontWeight: FontWeight.bold)),
            Text("${hz.toStringAsFixed(1)} Hz", style: const TextStyle(fontSize: 20)),
            const SizedBox(height: 20),
            // Visual feedback
            Slider(value: cents.toDouble(), min: -50, max: 50, onChanged: null),
            Text("$cents cents"),
          ],
        ),
      ),
    );
  }
}