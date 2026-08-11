import 'package:flutter/material.dart';

import '../../../core/ink/ink_stroke.dart';
import '../../../core/models/enums.dart';
import '../ink/stroke_renderer.dart';

/// Paints all committed strokes for a page. Lives behind a [RepaintBoundary]
/// so it only repaints when the stroke list identity changes.
class CommittedInkPainter extends CustomPainter {
  const CommittedInkPainter(this.strokes);
  final List<InkStroke> strokes;

  @override
  void paint(Canvas canvas, Size size) {
    for (final stroke in strokes) {
      final path = StrokeRenderer.pathFor(stroke);
      canvas.drawPath(path, _paintFor(stroke.color, stroke.tool));
    }
  }

  @override
  bool shouldRepaint(covariant CommittedInkPainter old) =>
      !identical(old.strokes, strokes);
}

/// Paints the single in-progress stroke. Repaints on every pointer move.
class ActiveStrokePainter extends CustomPainter {
  const ActiveStrokePainter({
    required this.points,
    required this.tool,
    required this.color,
    required this.width,
  });

  final List<StrokePoint> points;
  final ToolType tool;
  final int color;
  final double width;

  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty) return;
    final path = StrokeRenderer.pathFrom(tool, width, points, isComplete: false);
    canvas.drawPath(path, _paintFor(color, tool));
  }

  @override
  bool shouldRepaint(covariant ActiveStrokePainter old) =>
      !identical(old.points, points) ||
      old.color != color ||
      old.width != width ||
      old.tool != tool;
}

Paint _paintFor(int color, ToolType tool) {
  final paint = Paint()
    ..color = Color(color)
    ..style = PaintingStyle.fill
    ..isAntiAlias = true;
  if (tool == ToolType.highlighter) {
    // Multiply keeps overlaps readable rather than opaque.
    paint.blendMode = BlendMode.multiply;
  }
  return paint;
}
