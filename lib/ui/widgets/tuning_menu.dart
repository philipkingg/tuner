import 'package:flutter/material.dart';
import '../../models/tuning_preset.dart';

class TuningMenu extends StatelessWidget {
  final List<TuningPreset> presets;
  final int selectedIndex;
  final ValueChanged<int> onPresetSelected;
  final VoidCallback onCreateNew;
  final ValueChanged<TuningPreset>? onDelete;
  final VoidCallback? onRestoreDefaults;

  const TuningMenu({
    super.key,
    required this.presets,
    required this.selectedIndex,
    required this.onPresetSelected,
    required this.onCreateNew,
    this.onDelete,
    this.onRestoreDefaults,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Padding(
                padding: EdgeInsets.only(left: 20),
                child: Text(
                  "Select Tuning",
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
              ),
              Row(
                children: [
                  if (onRestoreDefaults != null)
                    TextButton.icon(
                      onPressed: () {
                        onRestoreDefaults!();
                        Navigator.pop(context);
                      },
                      icon: const Icon(Icons.restore, size: 18),
                      label: const Text("Restore"),
                    ),
                  Padding(
                    padding: const EdgeInsets.only(right: 8.0),
                    child: TextButton.icon(
                      onPressed: () {
                        // Close this menu first? Or keep it open?
                        // Usually dialog on top is fine.
                        onCreateNew();
                      },
                      icon: const Icon(Icons.add),
                      label: const Text("New"),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),
          Flexible(
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: presets.length,
              itemBuilder: (context, index) {
                final preset = presets[index];
                return ListTile(
                  leading: Icon(
                    index == 0 ? Icons.blur_on : Icons.music_note,
                    color: Colors.blueAccent,
                  ),
                  title: Text(preset.name),
                  subtitle: Text(
                    preset.notes.isEmpty
                        ? "All notes"
                        : preset.notes.join(" • "),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (selectedIndex == index)
                        const Icon(Icons.check, color: Colors.green),
                      if (preset.name != "Chromatic" && onDelete != null)
                        IconButton(
                          icon: const Icon(
                            Icons.delete,
                            color: Colors.redAccent,
                            size: 20,
                          ),
                          onPressed: () => onDelete!(preset),
                        ),
                    ],
                  ),
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
