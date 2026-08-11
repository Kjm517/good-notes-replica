import 'package:flutter/material.dart';

import '../../../core/models/enums.dart';
import '../../../core/models/margin_spec.dart';
import '../../../core/models/page_geometry.dart';

/// Paints the static page background: paper colour, template ruling, and the
/// adjustable margin guides. This layer is cheap and is cached by a
/// [RepaintBoundary] in the editor so it only repaints on template/margin/size
/// changes.
class PaperPainter extends CustomPainter {
  const PaperPainter({
    required this.template,
    required this.paperColor,
    required this.margins,
    this.lineSpacing = 34,
  });

  final PaperTemplate template;
  final PaperColor paperColor;
  final MarginSpec margins;
  final double lineSpacing;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;

    // Background.
    canvas.drawRect(rect, Paint()..color = paperColor.color);

    final linePaint = Paint()
      ..color = paperColor.lineColor
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;

    switch (template) {
      case PaperTemplate.blank:
      case PaperTemplate.custom:
        break;
      case PaperTemplate.lined:
        _horizontalLines(canvas, size, lineSpacing, linePaint);
      case PaperTemplate.gridSmall:
        _grid(canvas, size, 18, linePaint);
      case PaperTemplate.gridLarge:
        _grid(canvas, size, 36, linePaint);
      case PaperTemplate.dotted:
        _dots(canvas, size, 24, paperColor.lineColor);
      case PaperTemplate.cornell:
        _cornell(canvas, size, linePaint);
      case PaperTemplate.music:
        _music(canvas, size, linePaint);
      case PaperTemplate.planner:
        _planner(canvas, size, linePaint);
    }

    _marginGuides(canvas, size);
  }

  void _horizontalLines(Canvas canvas, Size size, double gap, Paint p,
      {double top = 0, double bottom = 0}) {
    final start = top == 0 ? gap : top;
    final end = bottom == 0 ? size.height : bottom;
    for (double y = start; y < end; y += gap) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), p);
    }
  }

  void _grid(Canvas canvas, Size size, double gap, Paint p) {
    for (double y = gap; y < size.height; y += gap) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), p);
    }
    for (double x = gap; x < size.width; x += gap) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), p);
    }
  }

  void _dots(Canvas canvas, Size size, double gap, Color color) {
    final p = Paint()..color = color;
    for (double y = gap; y < size.height; y += gap) {
      for (double x = gap; x < size.width; x += gap) {
        canvas.drawCircle(Offset(x, y), 1.1, p);
      }
    }
  }

  void _cornell(Canvas canvas, Size size, Paint p) {
    final cueX = size.width * 0.28;
    final summaryY = size.height * 0.82;
    final headerY = size.height * 0.08;
    // Header + summary separators.
    canvas.drawLine(Offset(0, headerY), Offset(size.width, headerY), p);
    canvas.drawLine(Offset(0, summaryY), Offset(size.width, summaryY), p);
    // Cue column divider.
    canvas.drawLine(Offset(cueX, headerY), Offset(cueX, summaryY), p);
    // Note lines in the main area.
    for (double y = headerY + 34; y < summaryY; y += 34) {
      canvas.drawLine(Offset(cueX, y), Offset(size.width, y), p);
    }
  }

  void _music(Canvas canvas, Size size, Paint p) {
    const staffGap = 9.0; // between the 5 lines
    const groupGap = 46.0; // between staves
    double y = groupGap;
    while (y + staffGap * 4 < size.height) {
      for (int i = 0; i < 5; i++) {
        final ly = y + i * staffGap;
        canvas.drawLine(Offset(24, ly), Offset(size.width - 24, ly), p);
      }
      y += groupGap + staffGap * 4;
    }
  }

  void _planner(Canvas canvas, Size size, Paint p) {
    final headerY = size.height * 0.12;
    canvas.drawLine(Offset(0, headerY), Offset(size.width, headerY), p);
    _horizontalLines(canvas, size, 34, p, top: headerY + 34);
  }

  void _marginGuides(Canvas canvas, Size size) {
    if (!margins.enabled || !margins.showGuides) return;
    final p = Paint()
      ..color = margins.guideColor
      ..strokeWidth = 1.4
      ..style = PaintingStyle.stroke;
    if (margins.left > 0) {
      canvas.drawLine(
          Offset(margins.left, 0), Offset(margins.left, size.height), p);
    }
    if (margins.right > 0) {
      final x = size.width - margins.right;
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), p);
    }
    if (margins.top > 0) {
      canvas.drawLine(
          Offset(0, margins.top), Offset(size.width, margins.top), p);
    }
    if (margins.bottom > 0) {
      final y = size.height - margins.bottom;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), p);
    }
  }

  @override
  bool shouldRepaint(covariant PaperPainter old) =>
      old.template != template ||
      old.paperColor != paperColor ||
      old.margins != margins ||
      old.lineSpacing != lineSpacing;
}
