import 'package:flutter/material.dart';
import 'ui/screens/tuner_home.dart';

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