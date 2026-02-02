import 'package:flutter/material.dart';
import '../../models/tuning_preset.dart';

class AddTuningDialog extends StatefulWidget {
  final ValueChanged<TuningPreset> onAdd;
  const AddTuningDialog({super.key, required this.onAdd});

  @override
  State<AddTuningDialog> createState() => _AddTuningDialogState();
}

class _AddTuningDialogState extends State<AddTuningDialog> {
  final _nameController = TextEditingController();
  final _notesController = TextEditingController();
  String? _errorText;

  void _submit() {
    final name = _nameController.text.trim();
    final notesStr = _notesController.text.trim();
    
    if (name.isEmpty) {
      setState(() => _errorText = "Name cannot be empty");
      return;
    }
    if (notesStr.isEmpty) {
      setState(() => _errorText = "Notes cannot be empty");
      return;
    }

    // Parse notes, expect "A2 D3" format
    final noteList = notesStr.split(RegExp(r'\s+')).map((e) => e.toUpperCase()).toList();
    
    // Simple validation
    RegExp noteRegex = RegExp(r"^[A-G][#]?\d$");
    for (var note in noteList) {
      if (!noteRegex.hasMatch(note)) {
        setState(() => _errorText = "Invalid note: $note. Usage: 'E2 A2 D3'");
        return;
      }
    }

    widget.onAdd(TuningPreset(name: name, notes: noteList, isCustom: true));
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: Colors.grey[900],
      title: const Text("New Tuning"),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(
          controller: _nameController,
          decoration: const InputDecoration(labelText: "Name", hintText: "e.g. Drop D"),
          style: const TextStyle(color: Colors.white),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _notesController,
          decoration: InputDecoration(
            labelText: "Notes (space separated)", 
            hintText: "e.g. D2 A2 D3 G3 B3 E4",
            errorText: _errorText,
          ),
          style: const TextStyle(color: Colors.white),
        ),
      ]),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
        FilledButton.tonal(onPressed: _submit, child: const Text("Create")),
      ],
    );
  }
}
