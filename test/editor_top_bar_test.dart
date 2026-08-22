import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:notably/features/editor/canvas/continuous_canvas.dart';
import 'package:notably/features/editor/widgets/editor_top_bar.dart';

/// Scaffold sizes the app bar purely from [EditorTopBar.preferredSize], so if
/// that sum doesn't match what the rows actually paint, the toolbar Column
/// overflows (the yellow and black stripes). Row separators are drawn as
/// borders *inside* each row, so the sum is exactly the row heights.
EditorTopBar _bar(EditorBarLayout layout) {
  final controller = ContinuousCanvasController();
  addTearDown(controller.dispose);
  return EditorTopBar(
    documentId: 'doc',
    title: 'Test document',
    subtitle: 'Page 1 of 10',
    sidebarOpen: true,
    onToggleSidebar: () {},
    currentIndex: 0,
    pageCount: 10,
    canvasController: controller,
    pageSizeFor: (_) => const Size(800, 1000),
    onRename: () {},
    onToggleBookmark: () {},
    bookmarked: false,
    onOpenPageSettings: () {},
    layout: layout,
    onFind: () {},
    onQuiz: () {},
    onBack: () {},
  );
}

void main() {
  group('EditorTopBar.preferredSize', () {
    test('phone reserves the title row only', () {
      expect(_bar(EditorBarLayout.phone).preferredSize.height, 56);
    });

    // Title row 56 + tool row 60.
    test('stacked is the sum of its two rows', () {
      expect(_bar(EditorBarLayout.stacked).preferredSize.height, 116);
    });

    test('desktop fits everything on one row', () {
      expect(_bar(EditorBarLayout.single).preferredSize.height, 60);
    });

    test('tablet rail keeps a compact title row', () {
      expect(_bar(EditorBarLayout.tabletRail).preferredSize.height, 56);
    });

    test('the tool row is exactly what stacked adds over phone', () {
      final stacked = _bar(EditorBarLayout.stacked).preferredSize.height;
      final phone = _bar(EditorBarLayout.phone).preferredSize.height;
      expect(stacked - phone, 60);
    });
  });

  group('EditorBarLayout.forWidth', () {
    test('phones get the bottom dock', () {
      expect(EditorBarLayout.forWidth(390), EditorBarLayout.phone);
      expect(EditorBarLayout.forWidth(759), EditorBarLayout.phone);
      expect(EditorBarLayout.forWidth(390).showsTools, isFalse);
    });

    test('tablets and small windows stack the rows', () {
      expect(EditorBarLayout.forWidth(760), EditorBarLayout.stacked);
      expect(EditorBarLayout.forWidth(1024), EditorBarLayout.stacked);
      expect(EditorBarLayout.forWidth(1239), EditorBarLayout.stacked);
    });

    test('wide desktops collapse to a single row', () {
      expect(EditorBarLayout.forWidth(1240), EditorBarLayout.single);
      expect(EditorBarLayout.forWidth(1920), EditorBarLayout.single);
    });

    test('size-aware layout handles phone, tablet, and desktop', () {
      expect(
        EditorBarLayout.forSize(const Size(390, 844)),
        EditorBarLayout.phone,
      );
      expect(
        EditorBarLayout.forSize(const Size(1024, 1366)),
        EditorBarLayout.stacked,
      );
      expect(
        EditorBarLayout.forSize(const Size(1194, 834)),
        EditorBarLayout.tabletRail,
      );
      expect(
        EditorBarLayout.forSize(const Size(1366, 1024)),
        EditorBarLayout.tabletRail,
      );
      expect(
        EditorBarLayout.forSize(const Size(1920, 1080)),
        EditorBarLayout.tabletRail,
      );
      expect(
        EditorBarLayout.forSize(const Size(2560, 1440)),
        EditorBarLayout.single,
      );
    });

    test('every layout above phone shows the tools inline', () {
      expect(EditorBarLayout.stacked.showsTools, isTrue);
      expect(EditorBarLayout.single.showsTools, isTrue);
    });
  });
}
