import 'package:flutter/material.dart';
import '../../models/app_theme.dart';
import '../../models/tuning_preset.dart';

class TuningMenu extends StatefulWidget {
  final AppThemeColors themeColors;
  final List<TuningPreset> presets;
  final int selectedIndex;
  final ValueChanged<int> onPresetSelected;
  final VoidCallback onCreateNew;
  final ValueChanged<TuningPreset>? onDelete;
  final VoidCallback? onRestoreDefaults;

  const TuningMenu({
    super.key,
    required this.themeColors,
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

  AppThemeColors get tc => widget.themeColors;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: tc.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        border: Border(top: BorderSide(color: tc.border, width: 1)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 12, bottom: 4),
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: tc.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 16, 16, 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.music_note_rounded,
                      color: tc.primary,
                      size: 20,
                    ),
                    const SizedBox(width: 10),
                    Text(
                      'Tunings',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: tc.textPrimary,
                        letterSpacing: -0.3,
                      ),
                    ),
                  ],
                ),
                IconButton(
                  onPressed: widget.onCreateNew,
                  icon: Icon(
                    Icons.add_circle_outline_rounded,
                    size: 22,
                    color: tc.primary,
                  ),
                  tooltip: 'New Tuning',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                ),
              ],
            ),
          ),

          Flexible(
            child: ListView.builder(
              shrinkWrap: true,
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              itemCount: widget.presets.length + 1,
              itemBuilder: (context, index) {
                if (index == widget.presets.length) {
                  if (widget.onRestoreDefaults == null) {
                    return const SizedBox.shrink();
                  }
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
      margin: const EdgeInsets.only(top: 4, bottom: 4),
      child: SizedBox(
        width: double.infinity,
        child: OutlinedButton(
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
          style: OutlinedButton.styleFrom(
            foregroundColor: _isConfirmingRestore
                ? const Color(0xFFFF453A)
                : tc.textSecondary,
            side: BorderSide(
              color: _isConfirmingRestore
                  ? const Color(0xFFFF453A).withValues(alpha: 0.5)
                  : tc.border,
            ),
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: Text(
            _isConfirmingRestore ? 'Tap again to confirm' : 'Restore Defaults',
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
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
    final IconData leadingIcon =
        isChromatic ? Icons.blur_on_rounded : Icons.music_note_rounded;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: isSelected
            ? tc.primary.withValues(alpha: 0.08)
            : tc.surfaceContainer,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isSelected ? tc.primary.withValues(alpha: 0.5) : tc.border,
          width: isSelected ? 1.5 : 1,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          splashColor: tc.primary.withValues(alpha: 0.08),
          highlightColor: tc.primary.withValues(alpha: 0.04),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                // Leading icon container
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? tc.primary.withValues(alpha: 0.15)
                        : tc.border.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    leadingIcon,
                    color: isSelected ? tc.primary : tc.textSecondary,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 14),

                // Content
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        preset.name,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: tc.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        preset.notes.isEmpty
                            ? 'All notes'
                            : preset.notes.join(' · '),
                        style: TextStyle(
                          fontSize: 12,
                          color: tc.textMuted,
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
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: tc.primary,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Icon(
                          Icons.check_rounded,
                          color: Colors.white,
                          size: 14,
                        ),
                      ),
                    if (onDelete != null) ...[
                      const SizedBox(width: 6),
                      IconButton(
                        onPressed: () {
                          onDelete();
                          Navigator.pop(context);
                        },
                        icon: const Icon(Icons.delete_outline_rounded),
                        color: const Color(0xFFFF453A).withValues(alpha: 0.7),
                        iconSize: 18,
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
