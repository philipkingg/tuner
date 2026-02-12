import 'package:flutter/material.dart';
import '../../models/tuning_preset.dart';

class TuningMenu extends StatefulWidget {
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
  State<TuningMenu> createState() => _TuningMenuState();
}

class _TuningMenuState extends State<TuningMenu> {
  bool _isConfirmingRestore = false;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1C1C1E).withValues(alpha: 0.75),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 64, 24, 24),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.music_note,
                      color: Colors.greenAccent.shade400,
                      size: 24,
                    ),
                    const SizedBox(width: 12),
                    const Text(
                      'Tunings',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
                IconButton(
                  onPressed: widget.onCreateNew,
                  icon: const Icon(Icons.add_circle_outline, size: 24),
                  color: Colors.greenAccent.shade400,
                  tooltip: 'New Tuning',
                ),
              ],
            ),
          ),

          // Presets List
          Flexible(
            child: ListView.builder(
              shrinkWrap: true,
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              itemCount: widget.presets.length + 1, // +1 for restore button
              itemBuilder: (context, index) {
                // Restore button at the end
                if (index == widget.presets.length) {
                  if (widget.onRestoreDefaults == null)
                    return const SizedBox.shrink();
                  return _buildRestoreButton();
                }

                final preset = widget.presets[index];
                final isSelected = index == widget.selectedIndex;
                final isChromatic = preset.name == "Chromatic";

                return _buildPresetCard(
                  context: context,
                  preset: preset,
                  isSelected: isSelected,
                  isChromatic: isChromatic,
                  onTap: () {
                    widget.onPresetSelected(index);
                    Navigator.pop(context);
                  },
                  onDelete:
                      (!isChromatic && widget.onDelete != null)
                          ? () => widget.onDelete!(preset)
                          : null,
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRestoreButton() {
    return Container(
      margin: const EdgeInsets.only(top: 8, bottom: 8),
      child: SizedBox(
        width: double.infinity,
        child: FilledButton(
          onPressed: () {
            if (_isConfirmingRestore) {
              widget.onRestoreDefaults!();
              Navigator.pop(context);
            } else {
              setState(() => _isConfirmingRestore = true);
              Future.delayed(const Duration(seconds: 3), () {
                if (mounted) setState(() => _isConfirmingRestore = false);
              });
            }
          },
          style: FilledButton.styleFrom(
            backgroundColor:
                _isConfirmingRestore
                    ? Colors.redAccent
                    : const Color(0xFF1E1E20),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: Text(
            _isConfirmingRestore ? 'Are you sure?' : 'Restore Defaults',
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
          ),
        ),
      ),
    );
  }

  Widget _buildPresetCard({
    required BuildContext context,
    required TuningPreset preset,
    required bool isSelected,
    required bool isChromatic,
    required VoidCallback onTap,
    VoidCallback? onDelete,
  }) {
    IconData leadingIcon;
    if (isChromatic) {
      leadingIcon = Icons.blur_on;
    } else if (preset.notes.length > 4) {
      leadingIcon = Icons.piano;
    } else {
      leadingIcon = Icons.music_note;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E20),
        borderRadius: BorderRadius.circular(12),
        border:
            isSelected
                ? Border.all(color: Colors.greenAccent.shade700, width: 2)
                : null,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // Leading Icon
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color:
                        isSelected
                            ? Colors.greenAccent.shade700.withValues(alpha: 0.2)
                            : const Color(0xFF1C1C1E),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    leadingIcon,
                    color:
                        isSelected
                            ? Colors.greenAccent.shade400
                            : Colors.white70,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 16),

                // Content
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        preset.name,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        preset.notes.isEmpty
                            ? 'All notes'
                            : preset.notes.join(' • '),
                        style: const TextStyle(
                          fontSize: 13,
                          color: Colors.white60,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),

                // Trailing
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (isSelected)
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: Colors.greenAccent.shade700,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Icon(
                          Icons.check,
                          color: Colors.white,
                          size: 16,
                        ),
                      ),
                    if (onDelete != null) ...[
                      const SizedBox(width: 8),
                      IconButton(
                        onPressed: () {
                          onDelete();
                          Navigator.pop(context);
                        },
                        icon: const Icon(Icons.delete_outline),
                        color: Colors.redAccent,
                        iconSize: 20,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(
                          minWidth: 32,
                          minHeight: 32,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
