import 'package:flutter/material.dart';
import '../../models/tuning_preset.dart';

class TuningMenu extends StatelessWidget {
  final List<TuningPreset> presets;
  final int selectedIndex;
  final ValueChanged<int> onPresetSelected;

  const TuningMenu({super.key, required this.presets, required this.selectedIndex, required this.onPresetSelected});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text("Select Tuning", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          Flexible(
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: presets.length,
              itemBuilder: (context, index) {
                final preset = presets[index];
                return ListTile(
                  leading: Icon(index == 0 ? Icons.blur_on : Icons.music_note, color: Colors.blueAccent),
                  title: Text(preset.name),
                  subtitle: Text(preset.notes.isEmpty ? "All notes" : preset.notes.join(" • ")),
                  trailing: selectedIndex == index ? const Icon(Icons.check, color: Colors.green) : null,
                  onTap: () {
                    onPresetSelected(index);
                    Navigator.pop(context);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
