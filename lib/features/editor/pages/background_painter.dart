import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../../core/models/margin_spec.dart';
import 'margin_guides.dart';

/// Paints an imported image / rendered PDF page as the page background.
///
/// [baseSize] is the original content size; the canvas may be larger when
/// extendable margins add space around it, in which case the content is drawn
/// inset by [MarginSpec.contentOffset] and the surrounding margin area is left
/// blank for annotations.
class BackgroundPainter extends CustomPainter {
  const BackgroundPainter({
    required this.image,
    required this.margins,
    required this.baseSize,
  });

  final ui.Image image;
  final MarginSpec margins;
  final Size baseSize;

  @override
  void paint(Canvas canvas, Size size) {
    // Sheet (including any extended margin area).
    canvas.drawRect(Offset.zero & size, Paint()..color = const Color(0xFFFFFFFF));

    final src =
        Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble());
    final dst = margins.contentOffset & baseSize;
    canvas.drawImageRect(
        image, src, dst, Paint()..filterQuality = FilterQuality.medium);

    paintMarginGuides(canvas, margins, baseSize);
  }

  @override
  bool? hitTest(Offset position) => false;

  @override
  bool shouldRepaint(covariant BackgroundPainter old) =>
      !identical(old.image, image) ||
      old.margins != margins ||
      old.baseSize != baseSize;
}
