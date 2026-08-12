import 'package:flutter/material.dart';

import '../state/lasso_selection.dart';

/// Draws the in-progress lasso outline and the marching-ants box around a
/// completed selection.
class LassoPainter extends CustomPainter {
  const LassoPainter({
    required this.lasso,
    required this.selection,
    required this.offset,
  });

  /// Points of the lasso currently being drawn (content coordinates).
  final List<Offset> lasso;

  /// Completed selection for this page, if any.
  final LassoSelection? selection;

  /// Content origin within the sheet (extendable margins).
  final Offset offset;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.translate(offset.dx, offset.dy);

    if (lasso.length > 1) {
      final path = Path()..addPolygon(lasso, false);
      canvas.drawPath(
        path,
        Paint()
          ..color = const Color(0xFF3D6DF0)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.6,
      );
      canvas.drawPath(
        Path()..addPolygon(lasso, true),
        Paint()..color = const Color(0x143D6DF0),
      );
    }

    final sel = selection;
    if (sel != null) {
      final rect = sel.movedBounds.inflate(6);
      canvas.drawRect(rect, Paint()..color = const Color(0x103D6DF0));
      _dashedRect(canvas, rect);
      // Corner handles.
      final handle = Paint()..color = const Color(0xFF3D6DF0);
      for (final c in [
        rect.topLeft,
        rect.topRight,
        rect.bottomLeft,
        rect.bottomRight,
      ]) {
        canvas.drawCircle(c, 4, handle);
      }
    }
    canvas.restore();
  }

  void _dashedRect(Canvas canvas, Rect rect) {
    final paint = Paint()
      ..color = const Color(0xFF3D6DF0)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4;
    const dash = 8.0, gap = 5.0;
    void line(Offset a, Offset b) {
      final total = (b - a).distance;
      if (total == 0) return;
      final dir = (b - a) / total;
      var t = 0.0;
      while (t < total) {
        final end = (t + dash).clamp(0.0, total);
        canvas.drawLine(a + dir * t, a + dir * end, paint);
        t = end + gap;
      }
    }

    line(rect.topLeft, rect.topRight);
    line(rect.topRight, rect.bottomRight);
    line(rect.bottomRight, rect.bottomLeft);
    line(rect.bottomLeft, rect.topLeft);
  }

  @override
  bool? hitTest(Offset position) => false;

  @override
  bool shouldRepaint(covariant LassoPainter old) =>
      !identical(old.lasso, lasso) ||
      old.selection != selection ||
      old.offset != offset;
}
