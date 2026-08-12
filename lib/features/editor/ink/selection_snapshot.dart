import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../../core/ink/ink_stroke.dart';
import '../canvas/ink_painters.dart';

/// Renders a lasso selection to a PNG — the "screenshot" of the selected ink,
/// optionally over the page background behind it.
class SelectionSnapshot {
  const SelectionSnapshot._();

  /// [bounds] is the selection rect in content coordinates.
  static Future<Uint8List?> render({
    required List<InkStroke> strokes,
    required Rect bounds,
    ui.Image? background,
    Offset backgroundOffset = Offset.zero,
    Size? backgroundSize,
    double pixelRatio = 2.0,
    Color fallbackColor = const Color(0xFFFFFFFF),
  }) async {
    if (strokes.isEmpty || bounds.isEmpty) return null;
    final padded = bounds.inflate(10);

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.scale(pixelRatio);
    // Draw everything relative to the selection's top-left.
    canvas.translate(-padded.left, -padded.top);

    if (background != null && backgroundSize != null) {
      // Paint the matching slice of the page behind the ink.
      final dst = backgroundOffset & backgroundSize;
      canvas.drawRect(dst, Paint()..color = fallbackColor);
      canvas.drawImageRect(
        background,
        Rect.fromLTWH(0, 0, background.width.toDouble(),
            background.height.toDouble()),
        dst,
        Paint()..filterQuality = FilterQuality.medium,
      );
    } else {
      canvas.drawRect(padded, Paint()..color = fallbackColor);
    }

    CommittedInkPainter(strokes).paint(canvas, padded.size);

    final picture = recorder.endRecording();
    final image = await picture.toImage(
      (padded.width * pixelRatio).ceil(),
      (padded.height * pixelRatio).ceil(),
    );
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    picture.dispose();
    image.dispose();
    return data?.buffer.asUint8List();
  }
}
