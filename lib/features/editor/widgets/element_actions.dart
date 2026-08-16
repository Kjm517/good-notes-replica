import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/design.dart';
import '../../../core/db/database.dart';
import '../../../core/models/enums.dart';
import '../../../core/models/image_element.dart';
import '../../../core/models/text_element.dart';
import '../providers.dart';
import '../state/tool_settings.dart';
import 'image_crop_dialog.dart';

/// Floating bar for the currently selected canvas object.
///
/// Text, stickers, images and sticky notes all share this one bar so settings
/// never stack on the page. Image-specific actions appear for pictures;
/// type, colour and weight appear for text.
class ElementActions extends ConsumerWidget {
  const ElementActions({
    super.key,
    required this.documentId,
    required this.pageWidth,
    this.editingElementId,
    this.onBeginEdit,
    this.onEndEdit,
  });

  final String documentId;
  final double pageWidth;
  final String? editingElementId;
  final ValueChanged<String>? onBeginEdit;
  final VoidCallback? onEndEdit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    final state = ref.watch(editorControllerProvider(documentId));
    final controller = ref.read(editorControllerProvider(documentId).notifier);
    final repo = ref.read(elementRepositoryProvider);
    final pageId = state.currentPageId;
    final selectedId = state.selectedElementId;
    final imageTool = state.tool == ToolType.image;

    if (!imageTool && selectedId == null) return const SizedBox.shrink();

    final pageElements = pageId == null
        ? const <CanvasElement>[]
        : ref.watch(pageElementsProvider(pageId)).asData?.value ?? const [];
    CanvasElement? selected;
    for (final element in pageElements) {
      if (element.id == selectedId) selected = element;
    }
    final selectedImage = selected?.type == ElementType.image;
    final selectedText =
        selected?.type == ElementType.text ||
        selected?.type == ElementType.sticky;
    final sticky = selected?.type == ElementType.sticky;
    final editing = selectedId != null && selectedId == editingElementId;
    final textData = selectedText && selected != null
        ? TextElementData.fromJson(selected.data)
        : null;

    Widget iconBtn({
      required String tooltip,
      required IconData icon,
      required VoidCallback? onPressed,
      Color? color,
      bool active = false,
    }) {
      return IconButton(
        tooltip: tooltip,
        icon: Icon(icon, color: color ?? (active ? t.accentText : t.text)),
        onPressed: onPressed,
        style: active
            ? IconButton.styleFrom(backgroundColor: t.accentSoft)
            : null,
      );
    }

    Widget divider() => Container(
      width: 1,
      height: 22,
      margin: const EdgeInsets.symmetric(horizontal: 4),
      color: t.lineStrong,
    );

    return ConstrainedBox(
      constraints: BoxConstraints(
        maxWidth: MediaQuery.sizeOf(context).width - 24,
      ),
      child: Material(
        elevation: 6,
        borderRadius: BorderRadius.circular(Radii.control),
        color: t.surface,
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (imageTool)
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
                          if (element != null) {
                            controller.selectElement(element.id);
                          }
                        },
                ),
              if (selectedId != null) ...[
                if (imageTool) divider(),
                if (textData != null) ...[
                  SizedBox(
                    width: 112,
                    height: 36,
                    child: SliderTheme(
                      data: SliderTheme.of(context).copyWith(
                        trackHeight: 2,
                        thumbShape: const RoundSliderThumbShape(
                          enabledThumbRadius: 6,
                        ),
                        overlayShape: const RoundSliderOverlayShape(
                          overlayRadius: 10,
                        ),
                        activeTrackColor: t.accent,
                        inactiveTrackColor: t.lineStrong,
                        thumbColor: t.accent,
                        overlayColor: t.accent.withValues(alpha: 0.12),
                      ),
                      child: Slider(
                        value: TextElementData.clampFontSize(textData.fontSize),
                        min: TextElementData.minFontSize,
                        max: TextElementData.maxFontSize,
                        onChanged: (v) => repo.updateTextData(
                          selectedId,
                          textData.copyWith(fontSize: v),
                        ),
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 28,
                    child: Text(
                      '${textData.fontSize.round()}',
                      textAlign: TextAlign.center,
                      style: AppTokens.mono(size: 11, color: t.textSecondary),
                    ),
                  ),
                  iconBtn(
                    tooltip: 'Bold',
                    icon: Icons.format_bold_rounded,
                    active: textData.bold,
                    onPressed: () => repo.updateTextData(
                      selectedId,
                      textData.copyWith(bold: !textData.bold),
                    ),
                  ),
                  if (!sticky)
                    for (final c in kColorPalette.take(6))
                      GestureDetector(
                        onTap: () => repo.updateTextData(
                          selectedId,
                          textData.copyWith(colorValue: c),
                        ),
                        child: Container(
                          width: 22,
                          height: 36,
                          alignment: Alignment.center,
                          child: Container(
                            width: 16,
                            height: 16,
                            decoration: BoxDecoration(
                              color: Color(c),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: textData.colorValue == c
                                    ? t.text
                                    : t.lineStrong,
                                width: textData.colorValue == c ? 2 : 1,
                              ),
                            ),
                          ),
                        ),
                      ),
                  iconBtn(
                    tooltip: editing ? 'Done' : 'Edit',
                    icon: editing ? Icons.check_rounded : Icons.edit_rounded,
                    onPressed: editing
                        ? onEndEdit
                        : () => onBeginEdit?.call(selectedId),
                  ),
                  divider(),
                ],
                if (selectedImage)
                  iconBtn(
                    tooltip: 'Crop',
                    icon: Icons.crop_rounded,
                    onPressed: () => _crop(context, ref, selectedId),
                  ),
                iconBtn(
                  tooltip: 'Send backward',
                  icon: Icons.flip_to_back_rounded,
                  onPressed: () => repo.shiftZ(selectedId, forward: false),
                ),
                iconBtn(
                  tooltip: 'Bring forward',
                  icon: Icons.flip_to_front_rounded,
                  onPressed: () => repo.shiftZ(selectedId, forward: true),
                ),
                iconBtn(
                  tooltip: 'Delete',
                  icon: Icons.delete_outline_rounded,
                  color: Theme.of(context).colorScheme.error,
                  onPressed: () async {
                    await repo.deleteElement(selectedId);
                    controller.selectElement(null);
                  },
                ),
                iconBtn(
                  tooltip: 'Deselect',
                  icon: Icons.close_rounded,
                  onPressed: () {
                    onEndEdit?.call();
                    controller.selectElement(null);
                  },
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _crop(
    BuildContext context,
    WidgetRef ref,
    String elementId,
  ) async {
    final repo = ref.read(elementRepositoryProvider);
    final element = await repo.getElement(elementId);
    if (element == null || element.type != ElementType.image) return;

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
