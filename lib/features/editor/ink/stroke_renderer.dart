import 'dart:ui';

import 'package:perfect_freehand/perfect_freehand.dart' as pf;

import '../../../core/ink/ink_stroke.dart';
import '../../../core/models/enums.dart';

/// Converts [InkStroke]s into fillable [Path]s using perfect_freehand, with
/// per-tool feel (pressure response, taper, width).
class StrokeRenderer {
  const StrokeRenderer._();

  static pf.StrokeOptions optionsFor(
      ToolType tool, double width, List<StrokePoint> points,
      {bool isComplete = true}) {
    // If the pointer gave no pressure variation (mouse/touch), let the library
    // simulate pressure from velocity for a natural look.
    final simulate = _isPressureless(points);
    switch (tool) {
      case ToolType.pen:
        return pf.StrokeOptions(
          size: width,
          thinning: 0.55,
          smoothing: 0.5,
          streamline: 0.5,
          simulatePressure: simulate,
          isComplete: isComplete,
        );
      case ToolType.pencil:
        return pf.StrokeOptions(
          size: width,
          thinning: 0.35,
          smoothing: 0.62,
          streamline: 0.45,
          simulatePressure: simulate,
          isComplete: isComplete,
        );
      case ToolType.highlighter:
        return pf.StrokeOptions(
          size: width,
          thinning: 0.0,
          smoothing: 0.4,
          streamline: 0.6,
          simulatePressure: false,
          start: pf.StrokeEndOptions.start(cap: false, taperEnabled: false),
          end: pf.StrokeEndOptions.end(cap: false, taperEnabled: false),
          isComplete: isComplete,
        );
      default:
        return pf.StrokeOptions(size: width, isComplete: isComplete);
    }
  }

  /// Builds a fill path for a finished stroke.
  static Path pathFor(InkStroke stroke) => pathFrom(
        stroke.tool,
        stroke.width,
        stroke.points,
        isComplete: true,
      );

  /// Builds a fill path from raw points (used for the live in-progress stroke).
  static Path pathFrom(
    ToolType tool,
    double width,
    List<StrokePoint> points, {
    bool isComplete = true,
  }) {
    if (points.isEmpty) return Path();
    final input = [
      for (final p in points) pf.PointVector(p.x, p.y, p.pressure),
    ];
    final outline = pf.getStroke(
      input,
      options: optionsFor(tool, width, points, isComplete: isComplete),
    );
    return _outlineToPath(outline);
  }

  static Path _outlineToPath(List<Offset> outline) {
    final path = Path();
    if (outline.isEmpty) return path;
    path.moveTo(outline.first.dx, outline.first.dy);
    // Smooth the polygon with quadratics through midpoints.
    for (var i = 1; i < outline.length - 1; i++) {
      final p0 = outline[i];
      final p1 = outline[i + 1];
      final mid = Offset((p0.dx + p1.dx) / 2, (p0.dy + p1.dy) / 2);
      path.quadraticBezierTo(p0.dx, p0.dy, mid.dx, mid.dy);
    }
    path.close();
    return path;
  }

  static bool _isPressureless(List<StrokePoint> points) {
    if (points.length < 2) return true;
    var min = 1.0, max = 0.0;
    for (final p in points) {
      if (p.pressure < min) min = p.pressure;
      if (p.pressure > max) max = p.pressure;
    }
    return (max - min) < 0.02;
  }
}
