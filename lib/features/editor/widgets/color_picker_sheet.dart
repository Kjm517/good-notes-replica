import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/enums.dart';
import '../providers.dart';
import '../state/tool_settings.dart';
import 'tool_options_sheet.dart';

/// Palette picker for the active tool.
///
/// A single swatch in the toolbar opens this, rather than laying ten circles
/// across the top bar — on a phone that strip didn't fit, and each swatch was
/// too small to hit reliably.
class ColorPickerSheet extends ConsumerWidget {
  const ColorPickerSheet({super.key, required this.documentId});

  final String documentId;

  static Future<void> show(BuildContext context, String documentId) {
    return showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (_) => ColorPickerSheet(documentId: documentId),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(editorControllerProvider(documentId));
    final controller = ref.read(editorControllerProvider(documentId).notifier);
    final palette = paletteFor(state.tool);
    final selected = state.activeSettings.color;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text('${ToolOptionsSheet.labelFor(state.tool)} colour',
                    style: Theme.of(context).textTheme.titleMedium),
                const Spacer(),
                TextButton.icon(
                  icon: const Icon(Icons.tune_rounded, size: 18),
                  label: const Text('More options'),
                  onPressed: () {
                    Navigator.pop(context);
                    ToolOptionsSheet.show(context, documentId);
                  },
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 14,
              runSpacing: 14,
              children: [
                for (final c in palette)
                  _Swatch(
                    color: c,
                    selected: c == selected,
                    // Highlighter/tape colours are translucent; show them on
                    // white so they look like they will on the page.
                    onWhite: state.tool == ToolType.highlighter ||
                        state.tool == ToolType.tape,
                    onTap: () {
                      controller.setColor(c);
                      Navigator.pop(context);
                    },
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Swatch extends StatelessWidget {
  const _Swatch({
    required this.color,
    required this.selected,
    required this.onTap,
    required this.onWhite,
  });

  final int color;
  final bool selected;
  final bool onWhite;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 52,
        height: 52,
        decoration: BoxDecoration(
          color: onWhite ? Colors.white : null,
          shape: BoxShape.circle,
          border: Border.all(
            color: selected ? scheme.primary : scheme.outlineVariant,
            width: selected ? 3 : 1,
          ),
        ),
        child: Center(
          child: Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: Color(onWhite ? color : (color | 0xFF000000)),
              shape: BoxShape.circle,
            ),
            child: selected
                ? Icon(Icons.check_rounded,
                    size: 20,
                    color: _contrastOn(Color(color | 0xFF000000)))
                : null,
          ),
        ),
      ),
    );
  }

  /// Tick colour that stays legible on light and dark swatches alike.
  static Color _contrastOn(Color background) =>
      background.computeLuminance() > 0.5 ? Colors.black87 : Colors.white;
}
