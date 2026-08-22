import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/platform/save_image.dart';
import '../ink/selection_snapshot.dart';
import '../providers.dart';
import '../state/tool_settings.dart';

/// Floating action bar shown while a lasso selection is active: snapshot
/// ("screenshot" the selection), recolour, delete, or dismiss.
class SelectionActions extends ConsumerWidget {
  const SelectionActions({super.key, required this.documentId});
  final String documentId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(editorControllerProvider(documentId));
    final controller = ref.read(editorControllerProvider(documentId).notifier);
    final selection = state.selection;
    if (selection == null) return const SizedBox.shrink();

    return Material(
      elevation: 6,
      borderRadius: BorderRadius.circular(24),
      color: Theme.of(context).colorScheme.surface,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Text('${selection.strokeIds.length} selected',
                  style: Theme.of(context).textTheme.labelMedium),
            ),
            const _Sep(),
            IconButton(
              tooltip: 'Save as image (screenshot)',
              icon: const Icon(Icons.photo_camera_outlined),
              onPressed: () => _snapshot(context, ref),
            ),
            IconButton(
              tooltip: 'Change colour',
              icon: const Icon(Icons.palette_outlined),
              onPressed: () => _pickColor(context, controller),
            ),
            IconButton(
              tooltip: 'Delete selection',
              icon: const Icon(Icons.delete_outline_rounded),
              color: Theme.of(context).colorScheme.error,
              onPressed: controller.deleteSelection,
            ),
            const _Sep(),
            IconButton(
              tooltip: 'Done',
              icon: const Icon(Icons.close_rounded),
              onPressed: controller.clearSelection,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _snapshot(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    final controller = ref.read(editorControllerProvider(documentId).notifier);
    final state = ref.read(editorControllerProvider(documentId));
    final selection = state.selection;
    if (selection == null) return;

    final strokes = controller.selectedStrokes();
    final bytes = await SelectionSnapshot.render(
      strokes: strokes,
      bounds: selection.bounds.shift(selection.offset),
    );
    if (bytes == null) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Nothing to capture')),
      );
      return;
    }
    final name = 'selection-${DateTime.now().millisecondsSinceEpoch}.png';
    final where = await savePng(bytes, name);
    final onMobile = !kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.iOS ||
            defaultTargetPlatform == TargetPlatform.android);
    messenger.showSnackBar(
      SnackBar(
        content: Text(onMobile ? 'Selection shared' : 'Saved $where'),
      ),
    );
  }

  Future<void> _pickColor(BuildContext context, dynamic controller) async {
    final chosen = await showDialog<int>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Change colour'),
        content: Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            for (final c in kColorPalette)
              GestureDetector(
                onTap: () => Navigator.pop(context, c),
                child: Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: Color(c | 0xFF000000),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.black26),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
    if (chosen != null) await controller.recolorSelection(chosen);
  }
}

class _Sep extends StatelessWidget {
  const _Sep();
  @override
  Widget build(BuildContext context) =>
      Container(width: 1, height: 22, color: Colors.black12);
}
