import 'dart:math' as math;
import 'dart:ui';

import '../../../core/ink/ink_stroke.dart';

/// Turns a rough freehand stroke into a clean geometric shape: straight line,
/// arrow, rectangle, ellipse or triangle. Returns the idealised points, or the
/// original points when nothing matches confidently.
class ShapeRecognizer {
  const ShapeRecognizer._();

  /// Recognises [points] and returns the snapped outline.
  static List<StrokePoint> recognize(List<StrokePoint> points) {
    if (points.length < 3) return points;

    final pts = [for (final p in points) Offset(p.x, p.y)];
    final bounds = _bounds(pts);
    // Guard on the LONGEST side: a straight horizontal/vertical line is a
    // legitimate shape whose shortest side is near zero.
    if (bounds.longestSide < 8) return points;

    final start = pts.first;
    final end = pts.last;
    final closed = (end - start).distance <
        0.28 * math.max(bounds.width, bounds.height);

    if (!closed) {
      // Open stroke: a straight line if it barely deviates from start→end.
      if (_maxDeviationFromLine(pts, start, end) <
          0.06 * (end - start).distance + 3) {
        return _line(start, end);
      }
      return points;
    }

    // Closed stroke: decide between circle/ellipse, rectangle and triangle.
    final centre = bounds.center;
    final radii = [for (final p in pts) (p - centre).distance];
    final meanR = radii.reduce((a, b) => a + b) / radii.length;
    final variance = radii
            .map((r) => (r - meanR) * (r - meanR))
            .reduce((a, b) => a + b) /
        radii.length;
    final roundness = math.sqrt(variance) / (meanR == 0 ? 1 : meanR);

    if (roundness < 0.16) return _ellipse(bounds);

    final corners = _dominantCorners(pts);
    if (corners == 3) return _polygon(bounds, 3);
    return _rectangle(bounds);
  }

  // ---- Shape builders ------------------------------------------------------

  static List<StrokePoint> _line(Offset a, Offset b) => [
        StrokePoint(a.dx, a.dy, 0.6),
        StrokePoint(b.dx, b.dy, 0.6),
      ];

  static List<StrokePoint> _rectangle(Rect r) => _closedPath([
        r.topLeft,
        r.topRight,
        r.bottomRight,
        r.bottomLeft,
      ]);

  static List<StrokePoint> _ellipse(Rect r) {
    const steps = 64;
    final out = <StrokePoint>[];
    for (var i = 0; i <= steps; i++) {
      final t = i / steps * 2 * math.pi;
      out.add(StrokePoint(
        r.center.dx + r.width / 2 * math.cos(t),
        r.center.dy + r.height / 2 * math.sin(t),
        0.6,
      ));
    }
    return out;
  }

  static List<StrokePoint> _polygon(Rect r, int sides) {
    if (sides == 3) {
      return _closedPath([
        Offset(r.center.dx, r.top),
        r.bottomRight,
        r.bottomLeft,
      ]);
    }
    return _rectangle(r);
  }

  /// Densifies a corner list so the stroke renderer draws crisp edges.
  static List<StrokePoint> _closedPath(List<Offset> corners) {
    final out = <StrokePoint>[];
    for (var i = 0; i < corners.length; i++) {
      final a = corners[i];
      final b = corners[(i + 1) % corners.length];
      const steps = 12;
      for (var s = 0; s < steps; s++) {
        final t = s / steps;
        out.add(StrokePoint(
          a.dx + (b.dx - a.dx) * t,
          a.dy + (b.dy - a.dy) * t,
          0.6,
        ));
      }
    }
    out.add(StrokePoint(corners.first.dx, corners.first.dy, 0.6));
    return out;
  }

  // ---- Geometry helpers ----------------------------------------------------

  static Rect _bounds(List<Offset> pts) {
    var minX = pts.first.dx, maxX = pts.first.dx;
    var minY = pts.first.dy, maxY = pts.first.dy;
    for (final p in pts) {
      if (p.dx < minX) minX = p.dx;
      if (p.dx > maxX) maxX = p.dx;
      if (p.dy < minY) minY = p.dy;
      if (p.dy > maxY) maxY = p.dy;
    }
    return Rect.fromLTRB(minX, minY, maxX, maxY);
  }

  static double _maxDeviationFromLine(List<Offset> pts, Offset a, Offset b) {
    final len = (b - a).distance;
    if (len == 0) return double.infinity;
    var worst = 0.0;
    for (final p in pts) {
      final cross =
          ((b.dx - a.dx) * (a.dy - p.dy) - (a.dx - p.dx) * (b.dy - a.dy)).abs();
      final d = cross / len;
      if (d > worst) worst = d;
    }
    return worst;
  }

  /// Counts sharp direction changes, used to tell triangles from rectangles.
  static int _dominantCorners(List<Offset> pts) {
    final simplified = _resample(pts, 40);
    var corners = 0;
    for (var i = 2; i < simplified.length; i++) {
      final v1 = simplified[i - 1] - simplified[i - 2];
      final v2 = simplified[i] - simplified[i - 1];
      if (v1.distance == 0 || v2.distance == 0) continue;
      final cos = (v1.dx * v2.dx + v1.dy * v2.dy) / (v1.distance * v2.distance);
      final angle = math.acos(cos.clamp(-1.0, 1.0));
      if (angle > math.pi / 4) corners++;
    }
    // Closed shapes repeat the first corner; 3–4 turns ≈ triangle.
    return corners <= 3 ? 3 : 4;
  }

  static List<Offset> _resample(List<Offset> pts, int count) {
    if (pts.length <= count) return pts;
    final step = pts.length / count;
    return [for (var i = 0; i < count; i++) pts[(i * step).floor()]];
  }
}
