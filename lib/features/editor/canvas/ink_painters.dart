import 'package:flutter/material.dart';

import '../../../core/ink/ink_stroke.dart';
import '../../../core/models/enums.dart';
import '../ink/stroke_renderer.dart';

/// Paints all committed strokes for a page. Lives behind a [RepaintBoundary]
/// so it only repaints when the stroke list identity changes.
class CommittedInkPainter extends CustomPainter {
  const CommittedInkPainter(
    this.strokes, {
    this.offset = Offset.zero,
    this.shiftedIds,
    this.shift = Offset.zero,
  });

  final List<InkStroke> strokes;

  /// Where the content area starts within the sheet (non-zero when extendable
  /// margins add space). Strokes are stored in content coordinates so they stay
  /// aligned with the page when margins change.
  final Offset offset;

  /// Strokes in an active lasso selection, drawn at [shift] while dragging.
  final Set<String>? shiftedIds;
  final Offset shift;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.translate(offset.dx, offset.dy);
    final ids = shiftedIds;
    for (final stroke in strokes) {
      final moved =
          ids != null && shift != Offset.zero && ids.contains(stroke.id);
      paintStroke(canvas, stroke, moved ? shift : Offset.zero);
    }
    canvas.restore();
  }

  /// Purely visual: never swallow pointer events aimed at layers below.
  @override
  bool? hitTest(Offset position) => false;

  @override
  bool shouldRepaint(covariant CommittedInkPainter old) =>
      !identical(old.strokes, strokes) ||
      old.offset != offset ||
      old.shift != shift ||
      old.shiftedIds != shiftedIds;
}

/// Paints the single in-progress stroke. Repaints on every pointer move.
class ActiveStrokePainter extends CustomPainter {
  const ActiveStrokePainter({
    required this.points,
    required this.tool,
    required this.color,
    required this.width,
    this.style = StrokeStyle.solid,
    this.filled = false,
    this.tip = StrokeTip.round,
    this.offset = Offset.zero,
  });

  final List<StrokePoint> points;
  final ToolType tool;
  final int color;
  final double width;
  final StrokeStyle style;
  final bool filled;
  final StrokeTip tip;
  final Offset offset;

  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty) return;
    canvas.save();
    canvas.translate(offset.dx, offset.dy);
    paintStroke(
      canvas,
      InkStroke(
        id: 'active',
        tool: tool,
        color: color,
        width: width,
        points: points,
        style: style,
        filled: filled,
        tip: tip,
      ),
      Offset.zero,
      isComplete: false,
    );
    canvas.restore();
  }

  @override
  bool? hitTest(Offset position) => false;

  @override
  bool shouldRepaint(covariant ActiveStrokePainter old) =>
      !identical(old.points, points) ||
      old.color != color ||
      old.width != width ||
      old.tool != tool ||
      old.style != style ||
      old.filled != filled ||
      old.tip != tip ||
      old.offset != offset;
}

/// Draws one stroke honouring its line style and fill.
void paintStroke(Canvas canvas, InkStroke stroke, Offset shift,
    {bool isComplete = true}) {
  final paint = _paintFor(stroke.color, stroke.tool);

  // Shapes can be filled with a translucent wash of the stroke colour.
  if (stroke.filled && stroke.points.length > 2) {
    final fill = Path()
      ..addPolygon(
        [for (final p in stroke.points) Offset(p.x, p.y)],
        true,
      );
    canvas.drawPath(
      shift == Offset.zero ? fill : fill.shift(shift),
      Paint()
        ..color = Color(stroke.color).withValues(alpha: 0.25)
        ..style = PaintingStyle.fill,
    );
  }

  if (stroke.style == StrokeStyle.solid) {
    final path = StrokeRenderer.pathFrom(
      stroke.tool,
      stroke.width,
      stroke.points,
      isComplete: isComplete,
      tip: stroke.tip,
    );
    canvas.drawPath(shift == Offset.zero ? path : path.shift(shift), paint);
    return;
  }

  // Dashed / dotted: stroke the centre line so the gaps are visible.
  final line = StrokeRenderer.centerlineFor(stroke.points);
  final w = stroke.width;
  final dashed = stroke.style == StrokeStyle.dashed
      ? StrokeRenderer.dashPath(line, w * 3, w * 2.4)
      : StrokeRenderer.dashPath(line, w * 0.1, w * 1.9);
  canvas.drawPath(
    shift == Offset.zero ? dashed : dashed.shift(shift),
    Paint()
      ..color = paint.color
      ..blendMode = paint.blendMode
      ..style = PaintingStyle.stroke
      ..strokeWidth = w
      ..strokeCap = stroke.tip == StrokeTip.square
          ? StrokeCap.square
          : (stroke.style == StrokeStyle.dotted
              ? StrokeCap.round
              : StrokeCap.butt)
      ..isAntiAlias = true,
  );
}

Paint _paintFor(int color, ToolType tool) {
  final paint = Paint()
    ..color = Color(color)
    ..style = PaintingStyle.fill
    ..isAntiAlias = true;
  if (tool == ToolType.highlighter || tool == ToolType.tape) {
    // Multiply keeps overlaps readable rather than opaque.
    paint.blendMode = BlendMode.multiply;
  }
  return paint;
}
