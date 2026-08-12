import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/db/database.dart';
import '../../../core/models/image_element.dart';
import '../providers.dart';
import 'image_crop_dialog.dart';

/// Floating bar for the Image tool: insert a picture, and crop/delete the
/// selected one.
class ImageActions extends ConsumerWidget {
  const ImageActions({
    super.key,
    required this.documentId,
    required this.pageWidth,
  });

  final String documentId;

  /// Content width of the current page, used to size a newly placed image.
  final double pageWidth;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(editorControllerProvider(documentId));
    final controller = ref.read(editorControllerProvider(documentId).notifier);
    final repo = ref.read(elementRepositoryProvider);
    final pageId = state.currentPageId;
    final selectedId = state.selectedElementId;

    return Material(
      elevation: 6,
      borderRadius: BorderRadius.circular(24),
      color: Theme.of(context).colorScheme.surface,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextButton.icon(
              icon: const Icon(Icons.add_photo_alternate_outlined),
              label: const Text('Add image'),
              onPressed: pageId == null
                  ? null
                  : () async {
                      final element = await repo.pickAndInsertImage(
                        pageId: pageId,
                        maxWidth: pageWidth * 0.5,
                      );
                      if (element != null) controller.selectElement(element.id);
                    },
            ),
            if (selectedId != null) ...[
              Container(width: 1, height: 22, color: Colors.black12),
              IconButton(
                tooltip: 'Crop',
                icon: const Icon(Icons.crop_rounded),
                onPressed: () => _crop(context, ref, selectedId),
              ),
              IconButton(
                tooltip: 'Delete image',
                icon: const Icon(Icons.delete_outline_rounded),
                color: Theme.of(context).colorScheme.error,
                onPressed: () async {
                  await repo.deleteElement(selectedId);
                  controller.selectElement(null);
                },
              ),
              IconButton(
                tooltip: 'Deselect',
                icon: const Icon(Icons.close_rounded),
                onPressed: () => controller.selectElement(null),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _crop(
      BuildContext context, WidgetRef ref, String elementId) async {
    final repo = ref.read(elementRepositoryProvider);
    final state = ref.read(editorControllerProvider(documentId));
    final pageId = state.currentPageId;
    if (pageId == null) return;

    final elements = await repo.getElements(pageId);
    CanvasElement? element;
    for (final e in elements) {
      if (e.id == elementId) element = e;
    }
    if (element == null) return;

    final data = ImageElementData.fromJson(element.data);
    final bytes = await repo.imageBytes(data.assetId);
    if (bytes == null || !context.mounted) return;

    final result = await ImageCropDialog.show(
      context,
      bytes: bytes,
      data: data,
      rotation: element.rotation,
    );
    if (result != null) {
      final (updatedData, rotation) = result;
      await repo.updateData(elementId, updatedData);
      await repo.updateTransform(elementId, rotation: rotation);
    }
  }
}
