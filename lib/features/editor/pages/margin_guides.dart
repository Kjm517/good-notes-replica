import 'package:flutter/material.dart';

import '../../../core/models/margin_spec.dart';

/// Draws the margin guide lines for [margins] around a content area of
/// [baseSize]. Shared by the paper and background painters so extended and
/// guide-only margins look identical.
void paintMarginGuides(Canvas canvas, MarginSpec margins, Size baseSize) {
  if (!margins.enabled || !margins.showGuides) return;
  final content = margins.contentRectIn(baseSize);
  final paint = Paint()
    ..color = margins.guideColor
    ..strokeWidth = 1.4
    ..style = PaintingStyle.stroke;

  if (margins.left > 0) {
    canvas.drawLine(Offset(content.left, 0),
        Offset(content.left, content.bottom + margins.bottom), paint);
  }
  if (margins.right > 0) {
    canvas.drawLine(Offset(content.right, 0),
        Offset(content.right, content.bottom + margins.bottom), paint);
  }
  if (margins.top > 0) {
    canvas.drawLine(Offset(0, content.top),
        Offset(content.right + margins.right, content.top), paint);
  }
  if (margins.bottom > 0) {
    canvas.drawLine(Offset(0, content.bottom),
        Offset(content.right + margins.right, content.bottom), paint);
  }
}
