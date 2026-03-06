import 'package:flutter/material.dart';
import '../../models/app_theme.dart';
import '../../models/tuning_preset.dart';

class AddTuningDialog extends StatefulWidget {
  final AppThemeColors themeColors;
  final ValueChanged<TuningPreset> onAdd;

  const AddTuningDialog({
    super.key,
    required this.themeColors,
    required this.onAdd,
  });

  @override
  State<AddTuningDialog> createState() => _AddTuningDialogState();
}

class _AddTuningDialogState extends State<AddTuningDialog> {
  final _nameController = TextEditingController();
  final _notesController = TextEditingController();
  String? _errorText;

  AppThemeColors get tc => widget.themeColors;

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

    final noteList =
        notesStr.split(RegExp(r'\s+')).map((e) => e.toUpperCase()).toList();

    RegExp noteRegex = RegExp(r"^[A-G][#]?\d*$");
    for (var note in noteList) {
      if (!noteRegex.hasMatch(note)) {
        setState(
          () =>
              _errorText = "Invalid note: $note. Usage: 'E2 A2 D3' or 'C D E'",
        );
        return;
      }
    }

    widget.onAdd(TuningPreset(name: name, notes: noteList, isCustom: true));
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final inputBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: BorderSide(color: tc.border),
    );
    final focusedBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: BorderSide(color: tc.primary, width: 1.5),
    );

    return AlertDialog(
      backgroundColor: tc.surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: tc.border),
      ),
      title: Text(
        'New Tuning',
        style: TextStyle(
          color: tc.textPrimary,
          fontSize: 18,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.3,
        ),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _nameController,
            style: TextStyle(color: tc.textPrimary, fontSize: 15),
            decoration: InputDecoration(
              labelText: 'Name',
              labelStyle: TextStyle(color: tc.textSecondary, fontSize: 13),
              hintText: 'e.g. Drop D',
              hintStyle: TextStyle(color: tc.textMuted),
              filled: true,
              fillColor: tc.surfaceContainer,
              enabledBorder: inputBorder,
              focusedBorder: focusedBorder,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 12,
              ),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _notesController,
            style: TextStyle(color: tc.textPrimary, fontSize: 15),
            decoration: InputDecoration(
              labelText: 'Notes (space separated)',
              labelStyle: TextStyle(color: tc.textSecondary, fontSize: 13),
              hintText: 'e.g. D2 A2 D3 or C D E F G',
              hintStyle: TextStyle(color: tc.textMuted),
              errorText: _errorText,
              errorStyle: const TextStyle(
                color: Color(0xFFFF453A),
                fontSize: 12,
              ),
              filled: true,
              fillColor: tc.surfaceContainer,
              enabledBorder: inputBorder,
              focusedBorder: focusedBorder,
              errorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: Color(0xFFFF453A)),
              ),
              focusedErrorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(
                  color: Color(0xFFFF453A),
                  width: 1.5,
                ),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 12,
              ),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          style: TextButton.styleFrom(foregroundColor: tc.textSecondary),
          child: const Text(
            'Cancel',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
        FilledButton(
          onPressed: _submit,
          style: FilledButton.styleFrom(
            backgroundColor: tc.primary,
            foregroundColor: tc.onPrimary,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(9),
            ),
          ),
          child: const Text(
            'Create',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }
}
