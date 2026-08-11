import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/enums.dart';
import '../providers.dart';
import '../state/tool_settings.dart';

/// The main editor toolbar: tools, colour, thickness and undo/redo.
class EditorToolbar extends ConsumerWidget {
  const EditorToolbar({super.key, required this.documentId});
  final String documentId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(editorControllerProvider(documentId));
    final controller = ref.read(editorControllerProvider(documentId).notifier);
    final scheme = Theme.of(context).colorScheme;

    final palette =
        state.tool == ToolType.highlighter ? kHighlighterPalette : kColorPalette;
    final thicknesses = kThicknessPresets[state.tool];

    return Material(
      elevation: 2,
      color: Theme.of(context).colorScheme.surface,
      child: SafeArea(
        bottom: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              child: Row(
                children: [
                  _ToolButton(
                    icon: Icons.edit_rounded,
                    label: 'Pen',
                    selected: state.tool == ToolType.pen,
                    onTap: () => controller.setTool(ToolType.pen),
                  ),
                  _ToolButton(
                    icon: Icons.gesture_rounded,
                    label: 'Pencil',
                    selected: state.tool == ToolType.pencil,
                    onTap: () => controller.setTool(ToolType.pencil),
                  ),
                  _ToolButton(
                    icon: Icons.brush_rounded,
                    label: 'Marker',
                    selected: state.tool == ToolType.highlighter,
                    onTap: () => controller.setTool(ToolType.highlighter),
                  ),
                  _ToolButton(
                    icon: Icons.cleaning_services_rounded,
                    label: 'Eraser',
                    selected: state.tool == ToolType.eraser,
                    onTap: () => controller.setTool(ToolType.eraser),
                  ),
                  const _Divider(),
                  _ToolButton(
                    icon: Icons.pan_tool_alt_rounded,
                    label: 'Hand',
                    selected: state.tool == ToolType.hand,
                    onTap: () => controller.setTool(ToolType.hand),
                  ),
                  const _Divider(),
                  IconButton(
                    tooltip: 'Undo',
                    icon: const Icon(Icons.undo_rounded),
                    onPressed: state.canUndo ? controller.undo : null,
                  ),
                  IconButton(
                    tooltip: 'Redo',
                    icon: const Icon(Icons.redo_rounded),
                    onPressed: state.canRedo ? controller.redo : null,
                  ),
                ],
              ),
            ),
            if (state.isDrawingTool)
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
                child: Row(
                  children: [
                    // Colour swatches.
                    Expanded(
                      child: SizedBox(
                        height: 34,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: palette.length,
                          separatorBuilder: (_, _) => const SizedBox(width: 8),
                          itemBuilder: (context, i) {
                            final c = palette[i];
                            final selected = state.activeSettings.color == c;
                            return GestureDetector(
                              onTap: () => controller.setColor(c),
                              child: Container(
                                width: 30,
                                decoration: BoxDecoration(
                                  color: Color(c | 0xFF000000),
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: selected
                                        ? scheme.primary
                                        : Colors.black26,
                                    width: selected ? 3 : 1,
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (thicknesses != null)
                      for (final w in thicknesses)
                        Padding(
                          padding: const EdgeInsets.only(left: 4),
                          child: _ThicknessButton(
                            width: w,
                            selected:
                                (state.activeSettings.width - w).abs() < 0.01,
                            onTap: () => controller.setWidth(w),
                          ),
                        ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ToolButton extends StatelessWidget {
  const _ToolButton({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: selected ? scheme.primaryContainer : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon,
                  size: 22,
                  color: selected ? scheme.onPrimaryContainer : null),
              Text(label, style: Theme.of(context).textTheme.labelSmall),
            ],
          ),
        ),
      ),
    );
  }
}

class _ThicknessButton extends StatelessWidget {
  const _ThicknessButton({
    required this.width,
    required this.selected,
    required this.onTap,
  });
  final double width;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          color: selected ? scheme.primaryContainer : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.black12),
        ),
        alignment: Alignment.center,
        child: Container(
          width: (width * 1.4).clamp(3, 16),
          height: (width * 1.4).clamp(3, 16),
          decoration: BoxDecoration(
            color: scheme.onSurface,
            shape: BoxShape.circle,
          ),
        ),
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  const _Divider();
  @override
  Widget build(BuildContext context) => Container(
        width: 1,
        height: 32,
        margin: const EdgeInsets.symmetric(horizontal: 6),
        color: Colors.black12,
      );
}
