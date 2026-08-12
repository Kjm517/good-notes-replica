import 'dart:math' as math;

import 'package:flutter/widgets.dart' show Offset;
import 'package:flutter_test/flutter_test.dart';
import 'package:notably/core/ink/ink_stroke.dart';
import 'package:notably/core/models/enums.dart';
import 'package:notably/features/editor/ink/shape_recognizer.dart';
import 'package:notably/features/editor/ink/stroke_renderer.dart';
import 'package:notably/features/editor/state/lasso_selection.dart';
import 'package:notably/features/editor/state/tool_settings.dart';

List<StrokePoint> _pts(List<Offset> offsets) =>
    [for (final o in offsets) StrokePoint(o.dx, o.dy, 0.5)];

InkStroke _stroke(String id, List<Offset> offsets,
        {ToolType tool = ToolType.pen}) =>
    InkStroke(
      id: id,
      tool: tool,
      color: 0xFF000000,
      width: 3,
      points: _pts(offsets),
    );

void main() {
  group('ShapeRecognizer', () {
    test('snaps a nearly straight stroke to a two-point line', () {
      final wobbly = <Offset>[
        for (var i = 0; i <= 20; i++)
          Offset(i * 10, (i.isEven ? 1 : -1).toDouble()),
      ];
      final result = ShapeRecognizer.recognize(_pts(wobbly));
      expect(result.length, 2);
      expect(result.first.x, closeTo(0, 0.001));
      expect(result.last.x, closeTo(200, 0.001));
    });

    test('recognises a rough circle as a closed ellipse', () {
      final circle = <Offset>[
        for (var i = 0; i <= 40; i++)
          Offset(
            100 + 50 * math.cos(i / 40 * 2 * math.pi),
            100 + 50 * math.sin(i / 40 * 2 * math.pi),
          ),
      ];
      final result = ShapeRecognizer.recognize(_pts(circle));
      // Ellipse output is densified well beyond the 41 input points.
      expect(result.length, greaterThan(50));
      // Every point should sit near the original radius.
      for (final p in result) {
        final r = (Offset(p.x, p.y) - const Offset(100, 100)).distance;
        expect(r, closeTo(50, 3));
      }
    });

    test('recognises a rough rectangle with square corners', () {
      final rect = <Offset>[
        for (var i = 0; i <= 10; i++) Offset(i * 10, 0),
        for (var i = 0; i <= 10; i++) Offset(100, i * 6),
        for (var i = 10; i >= 0; i--) Offset(i * 10, 60),
        for (var i = 10; i >= 0; i--) Offset(0, i * 6),
      ];
      final result = ShapeRecognizer.recognize(_pts(rect));
      expect(result.length, greaterThan(4));
      final xs = result.map((p) => p.x);
      final ys = result.map((p) => p.y);
      expect(xs.reduce(math.min), closeTo(0, 0.5));
      expect(xs.reduce(math.max), closeTo(100, 0.5));
      expect(ys.reduce(math.min), closeTo(0, 0.5));
      expect(ys.reduce(math.max), closeTo(60, 0.5));
    });

    test('leaves very short strokes untouched', () {
      final tiny = _pts([const Offset(0, 0), const Offset(1, 1)]);
      expect(ShapeRecognizer.recognize(tiny), same(tiny));
    });
  });

  group('LassoSelection', () {
    // A square lasso covering roughly x,y in [0,100].
    final lasso = <Offset>[
      const Offset(0, 0),
      const Offset(100, 0),
      const Offset(100, 100),
      const Offset(0, 100),
    ];

    test('selects strokes that lie inside the outline', () {
      final inside =
          _stroke('in', [const Offset(20, 20), const Offset(40, 40)]);
      final outside =
          _stroke('out', [const Offset(300, 300), const Offset(320, 320)]);
      final sel = LassoSelection.fromLasso(
        pageId: 'p1',
        lasso: lasso,
        strokes: [inside, outside],
      );
      expect(sel, isNotNull);
      expect(sel!.strokeIds, {'in'});
    });

    test('ignores strokes only grazing the lasso', () {
      // Mostly outside: only one of five points falls inside.
      final grazing = _stroke('graze', [
        const Offset(95, 95),
        const Offset(200, 200),
        const Offset(240, 240),
        const Offset(280, 280),
        const Offset(320, 320),
      ]);
      final sel = LassoSelection.fromLasso(
        pageId: 'p1',
        lasso: lasso,
        strokes: [grazing],
      );
      expect(sel, isNull);
    });

    test('returns null when nothing is captured', () {
      final far = _stroke('far', [const Offset(500, 500)]);
      expect(
        LassoSelection.fromLasso(pageId: 'p1', lasso: lasso, strokes: [far]),
        isNull,
      );
    });

    test('hit testing follows the dragged offset', () {
      final sel = LassoSelection.fromLasso(
        pageId: 'p1',
        lasso: lasso,
        strokes: [_stroke('in', [const Offset(20, 20), const Offset(40, 40)])],
      )!;
      expect(sel.hitTest(const Offset(30, 30)), isTrue);
      final moved = sel.copyWith(offset: const Offset(500, 0));
      expect(moved.hitTest(const Offset(30, 30)), isFalse);
      expect(moved.hitTest(const Offset(530, 30)), isTrue);
    });
  });

  group('tool settings', () {
    test('every ink tool has defaults, presets and a width range', () {
      final defaults = defaultToolSettings();
      for (final tool in kInkTools) {
        expect(defaults[tool], isNotNull, reason: 'defaults for $tool');
        expect(kThicknessPresets[tool], isNotNull, reason: 'presets for $tool');
        expect(kWidthRange[tool], isNotNull, reason: 'range for $tool');
      }
    });

    test('default width sits inside the tool width range', () {
      final defaults = defaultToolSettings();
      for (final tool in kInkTools) {
        final (minW, maxW) = kWidthRange[tool]!;
        final w = defaults[tool]!.width;
        expect(w, inInclusiveRange(minW, maxW), reason: '$tool width $w');
      }
    });

    test('highlighter and tape use translucent palettes', () {
      for (final c in kHighlighterPalette) {
        expect(c >> 24 & 0xFF, lessThan(0xFF), reason: 'highlighter alpha');
      }
      for (final c in kTapePalette) {
        expect(c >> 24 & 0xFF, lessThan(0xFF), reason: 'tape alpha');
      }
    });

    test('paletteFor returns a tool-appropriate palette', () {
      expect(paletteFor(ToolType.highlighter), kHighlighterPalette);
      expect(paletteFor(ToolType.tape), kTapePalette);
      expect(paletteFor(ToolType.fountainPen), kFountainPalette);
      expect(paletteFor(ToolType.pen), kColorPalette);
    });
  });

  group('LassoOptions filters', () {
    test('handwriting toggle covers pen, fountain pen and pencil', () {
      const off = LassoOptions(includeHandwriting: false);
      expect(off.includes(ToolType.pen), isFalse);
      expect(off.includes(ToolType.fountainPen), isFalse);
      expect(off.includes(ToolType.pencil), isFalse);
      // Other categories are unaffected.
      expect(off.includes(ToolType.shape), isTrue);
      expect(off.includes(ToolType.highlighter), isTrue);
    });

    test('each category can be excluded independently', () {
      expect(
        const LassoOptions(includeShapes: false).includes(ToolType.shape),
        isFalse,
      );
      expect(
        const LassoOptions(includeHighlighter: false)
            .includes(ToolType.highlighter),
        isFalse,
      );
      expect(
        const LassoOptions(includeTape: false).includes(ToolType.tape),
        isFalse,
      );
    });

    test('defaults include everything', () {
      const o = LassoOptions();
      for (final t in kInkTools) {
        expect(o.includes(t), isTrue, reason: '$t should be selectable');
      }
    });
  });

  group('StrokeStyle', () {
    test('dashed and dotted survive a copyWith', () {
      final s = _stroke('a', [const Offset(0, 0), const Offset(10, 0)])
          .copyWith(style: StrokeStyle.dashed, filled: true);
      expect(s.style, StrokeStyle.dashed);
      expect(s.filled, isTrue);
      // copyWith without the field keeps it.
      expect(s.copyWith(color: 0xFF00FF00).style, StrokeStyle.dashed);
    });

    test('style indices are stable for persistence', () {
      expect(StrokeStyle.solid.index, 0);
      expect(StrokeStyle.dashed.index, 1);
      expect(StrokeStyle.dotted.index, 2);
    });
  });

  group('StrokeTip (highlighter nib shape)', () {
    test('defaults to round and survives copyWith', () {
      final base = _stroke('a', [const Offset(0, 0), const Offset(30, 0)],
          tool: ToolType.highlighter);
      expect(base.tip, StrokeTip.round);
      final square = base.copyWith(tip: StrokeTip.square);
      expect(square.tip, StrokeTip.square);
      // Unrelated copyWith keeps the tip.
      expect(square.copyWith(width: 40).tip, StrokeTip.square);
    });

    test('changes the rendered outline', () {
      const points = [
        StrokePoint(0, 0, 0.5),
        StrokePoint(60, 0, 0.5),
      ];
      final round = StrokeRenderer.pathFrom(
          ToolType.highlighter, 24, points, tip: StrokeTip.round);
      final square = StrokeRenderer.pathFrom(
          ToolType.highlighter, 24, points, tip: StrokeTip.square);
      // A capped (round) nib extends past the end points; a flat one does not.
      expect(round.getBounds().width,
          greaterThan(square.getBounds().width),
          reason: 'round tip should overhang the stroke ends');
    });

    test('tip indices are stable for persistence', () {
      expect(StrokeTip.round.index, 0);
      expect(StrokeTip.square.index, 1);
    });

    test('only the broad tools expose a nib shape', () {
      expect(kTipTools, contains(ToolType.highlighter));
      expect(kTipTools, contains(ToolType.tape));
      expect(kTipTools, isNot(contains(ToolType.pen)));
    });
  });

  group('ToolType persistence', () {
    // Stroke.tool is stored by index, so existing data breaks if these move.
    test('existing tool indices are stable', () {
      expect(ToolType.pen.index, 0);
      expect(ToolType.pencil.index, 1);
      expect(ToolType.highlighter.index, 2);
      expect(ToolType.eraser.index, 3);
      expect(ToolType.lasso.index, 4);
      expect(ToolType.shape.index, 5);
      expect(ToolType.hand.index, 8);
      // New tools appended at the end.
      expect(ToolType.fountainPen.index, 9);
      expect(ToolType.tape.index, 10);
    });
  });
}
