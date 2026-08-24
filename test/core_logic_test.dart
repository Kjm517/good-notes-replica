import 'package:flutter/widgets.dart' show Offset, Size;
import 'package:flutter_test/flutter_test.dart';
import 'package:notably/core/db/database.dart';
import 'package:notably/core/ink/ink_stroke.dart';
import 'package:notably/core/models/enums.dart';
import 'package:notably/core/models/margin_spec.dart';
import 'package:notably/core/models/page_geometry.dart';
import 'package:notably/features/editor/ink/stroke_renderer.dart';
import 'package:notably/features/editor/state/editor_state.dart';

void main() {
  group('MarginSpec', () {
    test('round-trips through JSON', () {
      const spec = MarginSpec(
        enabled: true,
        left: 72,
        top: 10,
        right: 5,
        bottom: 20,
        showGuides: false,
      );
      final restored = MarginSpec.fromJson(spec.toJson());
      expect(restored, spec);
    });

    test('leftRule preset enables a left inset', () {
      final spec = MarginSpec.leftRule(inset: 60);
      expect(spec.enabled, isTrue);
      expect(spec.left, 60);
    });

    test('guide-only margins inset the content within the page', () {
      const spec = MarginSpec(
        enabled: true,
        left: 10,
        top: 20,
        right: 30,
        bottom: 40,
        extend: false,
      );
      final rect = spec.contentRect(const Size(200, 300));
      expect(rect.left, 10);
      expect(rect.top, 20);
      expect(rect.right, 170);
      expect(rect.bottom, 260);
    });

    test('contentRect is full page when disabled', () {
      final rect = MarginSpec.none.contentRect(const Size(200, 300));
      expect(rect.left, 0);
      expect(rect.right, 200);
    });

    group('extendable margins', () {
      const base = Size(200, 300);
      const spec = MarginSpec(
        enabled: true,
        left: 10,
        top: 20,
        right: 30,
        bottom: 40,
      );

      test('grow the sheet by the margin amounts', () {
        final outer = spec.outerSize(base);
        expect(outer.width, 240); // 200 + 10 + 30
        expect(outer.height, 360); // 300 + 20 + 40
      });

      test('offset the content by left/top', () {
        expect(spec.contentOffset, const Offset(10, 20));
        final content = spec.contentRectIn(base);
        expect(content.left, 10);
        expect(content.top, 20);
        expect(content.width, base.width);
        expect(content.height, base.height);
      });

      test('guide-only mode leaves the sheet size unchanged', () {
        final guideOnly = spec.copyWith(extend: false);
        expect(guideOnly.outerSize(base), base);
        expect(guideOnly.contentOffset, Offset.zero);
      });

      test('disabled margins never grow the sheet', () {
        final off = spec.copyWith(enabled: false);
        expect(off.outerSize(base), base);
      });

      test('extend flag survives a JSON round-trip', () {
        final restored = MarginSpec.fromJson(spec.toJson());
        expect(restored.extend, isTrue);
        expect(restored.outerSize(base), const Size(240, 360));
      });
    });
  });

  group('InkStroke packing', () {
    test('packs and unpacks points losslessly', () {
      final stroke = InkStroke(
        id: 'a',
        tool: ToolType.pen,
        color: 0xFF112233,
        width: 3,
        points: const [
          StrokePoint(1, 2, 0.5),
          StrokePoint(3.5, 4.25, 0.9),
          StrokePoint(10, 11, 1.0),
        ],
      );
      final bytes = stroke.packPoints();
      final restored = InkStroke.unpackPoints(bytes);
      expect(restored.length, 3);
      expect(restored[1].x, closeTo(3.5, 1e-4));
      expect(restored[1].y, closeTo(4.25, 1e-4));
      expect(restored[2].pressure, closeTo(1.0, 1e-4));
    });

    test('bounds inflate by width', () {
      final stroke = InkStroke(
        id: 'a',
        tool: ToolType.pen,
        color: 0xFF000000,
        width: 4,
        points: const [StrokePoint(10, 10, 1), StrokePoint(20, 30, 1)],
      );
      final b = stroke.bounds;
      expect(b.left, lessThanOrEqualTo(6));
      expect(b.right, greaterThanOrEqualTo(24));
    });
  });

  group('StrokeRenderer', () {
    test('produces a non-empty path for a multi-point stroke', () {
      final path = StrokeRenderer.pathFrom(
        ToolType.pen,
        3,
        const [
          StrokePoint(0, 0, 0.5),
          StrokePoint(10, 0, 0.6),
          StrokePoint(20, 5, 0.7),
        ],
      );
      expect(path.getBounds().isEmpty, isFalse);
    });

    test('empty points yield an empty path', () {
      final path = StrokeRenderer.pathFrom(ToolType.pen, 3, const []);
      expect(path.getBounds().isEmpty, isTrue);
    });
  });

  group('PageSizePreset', () {
    test('landscape swaps dimensions', () {
      final p = PageSizePreset.a4.size(PageOrientation.portrait);
      final l = PageSizePreset.a4.size(PageOrientation.landscape);
      expect(l.width, p.height);
      expect(l.height, p.width);
    });
  });

  group('mergeWatchedPages', () {
    NotePage page({
      required DateTime updatedAt,
      required MarginSpec marginSpec,
    }) {
      return NotePage(
        updatedAt: updatedAt,
        dirty: true,
        id: 'page-1',
        documentId: 'doc',
        pageIndex: 0,
        template: PaperTemplate.lined,
        paperColor: PaperColor.white,
        marginSpec: marginSpec,
        createdAt: updatedAt,
      );
    }

    test('keeps a newer local margin over a stale apply-to-all snapshot', () {
      final applied = DateTime.utc(2026, 8, 16, 12);
      final edited = applied.add(const Duration(seconds: 1));
      const appliedSpec = MarginSpec(enabled: true, left: 40, extend: true);
      const editedSpec = MarginSpec(enabled: true, left: 80, extend: true);

      final merged = mergeWatchedPages(
        local: [page(updatedAt: edited, marginSpec: editedSpec)],
        incoming: [page(updatedAt: applied, marginSpec: appliedSpec)],
      );

      expect(merged.single.marginSpec, editedSpec);
    });

    test('keeps a live preview on the page being dragged', () {
      final t = DateTime.utc(2026, 8, 16, 12);
      const appliedSpec = MarginSpec(enabled: true, left: 40, extend: true);
      const previewSpec = MarginSpec(enabled: true, left: 90, extend: true);

      final merged = mergeWatchedPages(
        local: [page(updatedAt: t, marginSpec: appliedSpec)],
        incoming: [page(updatedAt: t, marginSpec: appliedSpec)],
        previewMargins: previewSpec,
        previewPageId: 'page-1',
      );

      expect(merged.single.marginSpec, previewSpec);
    });
  });

  group('pagesRenderEqual', () {
    NotePage page({
      required String id,
      required int pageIndex,
      required DateTime updatedAt,
      bool dirty = true,
      MarginSpec marginSpec = MarginSpec.none,
      String? bookmarkTitle,
    }) {
      return NotePage(
        updatedAt: updatedAt,
        dirty: dirty,
        id: id,
        documentId: 'doc',
        pageIndex: pageIndex,
        template: PaperTemplate.lined,
        paperColor: PaperColor.white,
        marginSpec: marginSpec,
        bookmarkTitle: bookmarkTitle,
        createdAt: DateTime.utc(2026, 8, 16),
      );
    }

    final t = DateTime.utc(2026, 8, 16, 12);

    test('a sync touch alone does not count as a change', () {
      final before = [
        page(id: 'a', pageIndex: 0, updatedAt: t, dirty: false),
        page(id: 'b', pageIndex: 1, updatedAt: t, dirty: false),
      ];
      final afterStroke = [
        page(id: 'a', pageIndex: 0, updatedAt: t.add(const Duration(seconds: 5))),
        page(id: 'b', pageIndex: 1, updatedAt: t, dirty: false),
      ];

      expect(pagesRenderEqual(before, afterStroke), isTrue);
    });

    test('a margin edit, reorder, insert or bookmark does count', () {
      final before = [
        page(id: 'a', pageIndex: 0, updatedAt: t),
        page(id: 'b', pageIndex: 1, updatedAt: t),
      ];

      expect(
        pagesRenderEqual(before, [
          page(
            id: 'a',
            pageIndex: 0,
            updatedAt: t,
            marginSpec: const MarginSpec(enabled: true, left: 40),
          ),
          before[1],
        ]),
        isFalse,
      );
      expect(
        pagesRenderEqual(before, [before[1], before[0]]),
        isFalse,
      );
      expect(
        pagesRenderEqual(before, [
          ...before,
          page(id: 'c', pageIndex: 2, updatedAt: t),
        ]),
        isFalse,
      );
      expect(
        pagesRenderEqual(before, [
          page(id: 'a', pageIndex: 0, updatedAt: t, bookmarkTitle: 'Intro'),
          before[1],
        ]),
        isFalse,
      );
    });
  });
}
