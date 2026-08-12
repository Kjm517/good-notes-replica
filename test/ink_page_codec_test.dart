import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:notably/core/ink/ink_page_codec.dart';
import 'package:notably/core/ink/ink_stroke.dart';
import 'package:notably/core/models/enums.dart';

/// The codec packs a whole page of ink into one blob so sync costs one cloud
/// write per page instead of one per stroke. If it loses fidelity, users lose
/// drawings — hence the round-trip coverage here.
void main() {
  InkStroke stroke({
    required String id,
    ToolType tool = ToolType.pen,
    StrokeStyle style = StrokeStyle.solid,
    StrokeTip tip = StrokeTip.round,
    bool filled = false,
    int seq = 0,
    List<StrokePoint>? points,
  }) =>
      InkStroke(
        id: id,
        tool: tool,
        color: 0xFF123456,
        width: 3.5,
        opacity: 0.8,
        seq: seq,
        style: style,
        tip: tip,
        filled: filled,
        points: points ??
            const [
              StrokePoint(1, 2, 0.4),
              StrokePoint(10.5, 20.25, 0.9),
              StrokePoint(30, 40, 1.0),
            ],
      );

  test('round-trips a single stroke with all its attributes', () {
    final blob = encodeInkPageFromStrokes([
      stroke(
        id: 'a',
        tool: ToolType.highlighter,
        style: StrokeStyle.dashed,
        tip: StrokeTip.square,
        filled: true,
        seq: 7,
      ),
    ]);

    final out = decodeInkPage(blob);
    expect(out, hasLength(1));
    final s = out.single;
    expect(s.id, 'a');
    expect(s.tool, ToolType.highlighter);
    expect(s.style, StrokeStyle.dashed);
    expect(s.tip, StrokeTip.square);
    expect(s.filled, isTrue);
    expect(s.seq, 7);
    expect(s.color, 0xFF123456);
    expect(s.width, closeTo(3.5, 1e-6));
    expect(s.opacity, closeTo(0.8, 1e-6));
  });

  test('preserves point coordinates and pressure', () {
    final blob = encodeInkPageFromStrokes([stroke(id: 'a')]);
    final points = decodeInkPage(blob).single.points;
    expect(points, hasLength(3));
    expect(points[1].x, closeTo(10.5, 1e-4));
    expect(points[1].y, closeTo(20.25, 1e-4));
    expect(points[1].pressure, closeTo(0.9, 1e-4));
  });

  test('keeps multiple strokes distinct and in order', () {
    final blob = encodeInkPageFromStrokes([
      stroke(id: 'first', seq: 1),
      stroke(id: 'second', seq: 2, points: const [
        StrokePoint(100, 100, 0.5),
        StrokePoint(200, 150, 0.5),
      ]),
      stroke(id: 'third', seq: 3),
    ]);

    final out = decodeInkPage(blob);
    expect(out.map((s) => s.id), ['first', 'second', 'third']);
    expect(out[1].points.first.x, closeTo(100, 1e-4));
    expect(out[1].points, hasLength(2));
  });

  test('an empty page encodes and decodes to nothing', () {
    final blob = encodeInkPageFromStrokes(const []);
    expect(decodeInkPage(blob), isEmpty);
  });

  test('garbage input is ignored rather than throwing', () {
    expect(decodeInkPage(Uint8List(0)), isEmpty);
    expect(decodeInkPage(Uint8List.fromList([1, 2, 3])), isEmpty);
  });
}
