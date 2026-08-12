import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/db/database.dart';
import '../../../core/models/image_element.dart';
import '../canvas/ink_painters.dart';
import '../pages/background_painter.dart';
import '../pages/paper_painter.dart';
import '../providers.dart';

/// A non-interactive miniature of a page: paper or PDF background, the ink
/// drawn on it, and any placed images.
///
/// It reuses the same painters as the editor, so a preview can't drift out of
/// step with what the page actually looks like.
class PagePreview extends ConsumerWidget {
  const PagePreview({
    super.key,
    required this.page,
    required this.baseSize,
    this.background,
  });

  final NotePage page;

  /// Content size before extendable margins are applied.
  final Size baseSize;

  /// Pre-loaded background image, if the caller already has one.
  final ui.Image? background;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final margins = page.marginSpec;
    final sheet = margins.outerSize(baseSize);
    final offset = margins.contentOffset;

    final strokes = ref.watch(pageStrokesProvider(page.id)).asData?.value ??
        const [];
    final elements =
        ref.watch(pageElementsProvider(page.id)).asData?.value ?? const [];

    return FittedBox(
      fit: BoxFit.fill,
      child: SizedBox(
        width: sheet.width,
        height: sheet.height,
        child: Stack(
          clipBehavior: Clip.hardEdge,
          children: [
            CustomPaint(
              size: sheet,
              painter: background != null
                  ? BackgroundPainter(
                      image: background!,
                      margins: margins,
                      baseSize: baseSize,
                    )
                  : PaperPainter(
                      template: page.template,
                      paperColor: page.paperColor,
                      margins: margins,
                      baseSize: baseSize,
                    ),
            ),
            // Placed images sit above the page and below the ink, matching the
            // editor's layer order.
            for (final element in elements)
              _PreviewImage(element: element, offset: offset),
            if (strokes.isNotEmpty)
              CustomPaint(
                size: sheet,
                painter: CommittedInkPainter(strokes, offset: offset),
              ),
          ],
        ),
      ),
    );
  }
}

/// One image element, drawn flat (no handles, no interaction).
class _PreviewImage extends ConsumerWidget {
  const _PreviewImage({required this.element, required this.offset});

  final CanvasElement element;
  final Offset offset;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ImageElementData.fromJson(element.data);
    return Positioned(
      left: element.x + offset.dx,
      top: element.y + offset.dy,
      width: element.width,
      height: element.height,
      child: Transform.rotate(
        angle: element.rotation,
        child: FutureBuilder<Uint8List?>(
          future: ref.read(elementRepositoryProvider).imageBytes(data.assetId),
          builder: (context, snapshot) {
            final bytes = snapshot.data;
            if (bytes == null) return const SizedBox.shrink();
            return Opacity(
              opacity: data.opacity,
              child: Image.memory(
                bytes,
                fit: BoxFit.fill,
                gaplessPlayback: true,
                // Previews are tiny; decoding at full size would be wasteful.
                cacheWidth: 320,
              ),
            );
          },
        ),
      ),
    );
  }
}
