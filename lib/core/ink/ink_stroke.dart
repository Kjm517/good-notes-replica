import 'dart:typed_data';
import 'dart:ui';

import '../models/enums.dart';

/// A single sampled input point with pressure (0..1).
class StrokePoint {
  const StrokePoint(this.x, this.y, this.pressure);
  final double x;
  final double y;
  final double pressure;

  Offset get offset => Offset(x, y);
}

/// An in-memory ink stroke. Points are stored densely and (de)serialised to a
/// packed Float32 blob for the database.
class InkStroke {
  InkStroke({
    required this.id,
    required this.tool,
    required this.color,
    required this.width,
    required this.points,
    this.opacity = 1.0,
    this.seq = 0,
  });

  final String id;
  final ToolType tool;

  /// ARGB colour value.
  final int color;

  /// Base stroke width in page points.
  final double width;
  final double opacity;
  final int seq;
  final List<StrokePoint> points;

  Rect get bounds {
    if (points.isEmpty) return Rect.zero;
    var minX = points.first.x, maxX = points.first.x;
    var minY = points.first.y, maxY = points.first.y;
    for (final p in points) {
      if (p.x < minX) minX = p.x;
      if (p.x > maxX) maxX = p.x;
      if (p.y < minY) minY = p.y;
      if (p.y > maxY) maxY = p.y;
    }
    // Inflate by width so hit-testing/erasing accounts for stroke thickness.
    return Rect.fromLTRB(minX, minY, maxX, maxY).inflate(width);
  }

  /// Packs points as little-endian Float32 triples: x, y, pressure.
  Uint8List packPoints() {
    final data = Float32List(points.length * 3);
    for (var i = 0; i < points.length; i++) {
      data[i * 3] = points[i].x;
      data[i * 3 + 1] = points[i].y;
      data[i * 3 + 2] = points[i].pressure;
    }
    return data.buffer.asUint8List();
  }

  static List<StrokePoint> unpackPoints(Uint8List bytes) {
    final f = bytes.buffer.asFloat32List(
        bytes.offsetInBytes, bytes.lengthInBytes ~/ Float32List.bytesPerElement);
    final out = <StrokePoint>[];
    for (var i = 0; i + 2 < f.length; i += 3) {
      out.add(StrokePoint(f[i], f[i + 1], f[i + 2]));
    }
    return out;
  }

  InkStroke copyWith({
    String? id,
    List<StrokePoint>? points,
    int? color,
    double? width,
    double? opacity,
    int? seq,
  }) {
    return InkStroke(
      id: id ?? this.id,
      tool: tool,
      color: color ?? this.color,
      width: width ?? this.width,
      opacity: opacity ?? this.opacity,
      seq: seq ?? this.seq,
      points: points ?? this.points,
    );
  }
}
