import 'package:flutter_test/flutter_test.dart';
import 'package:notably/core/models/outline_entry.dart';
import 'package:notably/features/editor/search/outline_heading_detector.dart';

void main() {
  group('OutlineNode.nest', () {
    test('rebuilds a medical-microbiology style tree from depth tags', () {
      const entries = [
        OutlineEntry(title: 'SECTION 1 - Introduction', pageIndex: 0, depth: 0),
        OutlineEntry(
          title: '1. Introduction to Medical Microbiology',
          pageIndex: 1,
          depth: 1,
        ),
        OutlineEntry(title: 'Viruses', pageIndex: 2, depth: 2),
        OutlineEntry(title: 'Bacteria', pageIndex: 3, depth: 2),
        OutlineEntry(title: 'Fungi', pageIndex: 4, depth: 2),
        OutlineEntry(
          title: '2. Human Microbiome in Health and Disease',
          pageIndex: 10,
          depth: 1,
        ),
        OutlineEntry(
          title: '3. Sterilization, Disinfection, and Antisepsis',
          pageIndex: 18,
          depth: 1,
        ),
        OutlineEntry(
          title: 'SECTION 2 - General Principles of Laboratory Diagnosis',
          pageIndex: 30,
          depth: 0,
        ),
      ];

      final tree = OutlineNode.nest(entries);
      expect(tree, hasLength(2));
      expect(tree[0].id, '0');
      expect(tree[0].title, startsWith('SECTION 1'));
      expect(tree[0].children, hasLength(3));
      expect(tree[0].children[0].id, '0.0');
      expect(tree[0].children[0].children, hasLength(3));
      expect(tree[0].children[0].children[0].title, 'Viruses');
      expect(tree[0].children[0].children[0].id, '0.0.0');
      expect(tree[1].id, '1');
      expect(tree[1].children, isEmpty);
    });

    test('round-trips stored JSON without children', () {
      const entries = [
        OutlineEntry(title: 'A', pageIndex: 0, depth: 0),
        OutlineEntry(title: 'A.1', pageIndex: 2, depth: 1),
      ];
      final json = OutlineEntry.encode(entries);
      expect(OutlineEntry.decode(json), hasLength(2));
      expect(OutlineEntry.decode(json).first.depth, 0);
    });
  });

  group('OutlineNode.activeIdForPage', () {
    late List<OutlineNode> tree;

    setUp(() {
      tree = OutlineNode.nest(const [
        OutlineEntry(title: 'Ch 1', pageIndex: 0, depth: 0),
        OutlineEntry(title: '1.1', pageIndex: 2, depth: 1),
        OutlineEntry(title: '1.2', pageIndex: 10, depth: 1),
        OutlineEntry(title: 'Ch 2', pageIndex: 20, depth: 0),
      ]);
    });

    test('highlights the deepest section that has started', () {
      expect(OutlineNode.activeIdForPage(tree, 0), '0');
      expect(OutlineNode.activeIdForPage(tree, 2), '0.0');
      expect(OutlineNode.activeIdForPage(tree, 9), '0.0');
      expect(OutlineNode.activeIdForPage(tree, 10), '0.1');
      expect(OutlineNode.activeIdForPage(tree, 19), '0.1');
      expect(OutlineNode.activeIdForPage(tree, 20), '1');
    });
  });

  group('OutlineNode.pageSpan', () {
    test('covers until the next same-or-shallower entry', () {
      final tree = OutlineNode.nest(const [
        OutlineEntry(title: 'SECTION 1', pageIndex: 0, depth: 0),
        OutlineEntry(title: '1. Intro', pageIndex: 1, depth: 1),
        OutlineEntry(title: 'Viruses', pageIndex: 2, depth: 2),
        OutlineEntry(title: '2. Microbiome', pageIndex: 10, depth: 1),
        OutlineEntry(title: 'SECTION 2', pageIndex: 30, depth: 0),
      ]);
      const pageCount = 40;

      final section1 = OutlineNode.pageSpan(
        tree[0],
        roots: tree,
        pageCount: pageCount,
      );
      expect(section1, (0, 29));

      final intro = OutlineNode.pageSpan(
        tree[0].children[0],
        roots: tree,
        pageCount: pageCount,
      );
      expect(intro, (1, 9));

      final viruses = OutlineNode.pageSpan(
        tree[0].children[0].children[0],
        roots: tree,
        pageCount: pageCount,
      );
      expect(viruses, (2, 9));

      final section2 = OutlineNode.pageSpan(
        tree[1],
        roots: tree,
        pageCount: pageCount,
      );
      expect(section2, (30, 39));
    });

    test('pagesForIds unions parent and sibling spans without double-count issues',
        () {
      final tree = OutlineNode.nest(const [
        OutlineEntry(title: 'A', pageIndex: 0, depth: 0),
        OutlineEntry(title: 'A.1', pageIndex: 0, depth: 1),
        OutlineEntry(title: 'B', pageIndex: 5, depth: 0),
      ]);
      final pages = OutlineNode.pagesForIds(
        ['0.0', '1'],
        roots: tree,
        pageCount: 10,
      );
      expect(pages, {0, 1, 2, 3, 4, 5, 6, 7, 8, 9});
    });
  });

  group('OutlineHeadingDetector', () {
    test('keeps SECTION / numbered / topic bullets and drops body copy', () {
      const lines = [
        HeadingLine(text: 'SECTION 1 - Introduction', pageIndex: 0, fontSize: 18, bold: true),
        HeadingLine(text: '1. Introduction to Medical Microbiology', pageIndex: 1, fontSize: 14, bold: true),
        HeadingLine(text: '• Viruses', pageIndex: 2, fontSize: 12),
        HeadingLine(text: '• Bacteria', pageIndex: 2, fontSize: 12),
        HeadingLine(
          text: 'Medical microbiology is the study of microbes that cause disease in humans and is discussed at length in the following paragraphs.',
          pageIndex: 2,
          fontSize: 10,
        ),
        HeadingLine(text: '2. Human Microbiome in Health and Disease', pageIndex: 10, fontSize: 14, bold: true),
      ];
      final outline = OutlineHeadingDetector.detect(lines);
      expect(outline.length, greaterThanOrEqualTo(3));
      expect(outline.first.title, startsWith('SECTION 1'));
      expect(outline.first.depth, 0);
      expect(
        outline.any((e) => e.title.contains('Viruses') && e.depth == 2),
        isTrue,
      );
      expect(
        outline.any((e) => e.title.contains('discussed at length')),
        isFalse,
      );
    });

    test('returns empty when there is no real table of contents', () {
      const lines = [
        HeadingLine(text: 'The sample was incubated overnight.', pageIndex: 0, fontSize: 11),
        HeadingLine(text: 'Results are shown in table 1.', pageIndex: 1, fontSize: 11),
      ];
      expect(OutlineHeadingDetector.detect(lines), isEmpty);
    });
  });

  group('OutlineNode.ancestorIds', () {
    test('lists every parent path', () {
      expect(OutlineNode.ancestorIds('0.2.1'), {'0', '0.2'});
      expect(OutlineNode.ancestorIds('0'), isEmpty);
    });
  });

  group('OutlineNode section checkboxes', () {
    late List<OutlineNode> tree;

    setUp(() {
      tree = OutlineNode.nest(const [
        OutlineEntry(title: 'Chapter 3', pageIndex: 54, depth: 0),
        OutlineEntry(title: 'Short View Summary', pageIndex: 54, depth: 1),
        OutlineEntry(title: 'Clinical Studies', pageIndex: 55, depth: 1),
        OutlineEntry(title: 'Mechanisms', pageIndex: 56, depth: 1),
      ]);
    });

    test('checking a chapter selects every child', () {
      final next = OutlineNode.toggleSubtree({}, tree.first);
      expect(next, {'0', '0.0', '0.1', '0.2'});
    });

    test('unchecking a chapter clears every child', () {
      final all = tree.first.subtreeIds;
      final next = OutlineNode.toggleSubtree(all, tree.first);
      expect(next, isEmpty);
    });

    test('expandSelection fills in children of a checked parent', () {
      final next = OutlineNode.expandSelection({'0'}, roots: tree);
      expect(next, {'0', '0.0', '0.1', '0.2'});
    });
  });

  group('OutlineNode.chapterForPage', () {
    late List<OutlineNode> tree;

    setUp(() {
      tree = OutlineNode.nest(const [
        OutlineEntry(title: 'Ch 1', pageIndex: 0, depth: 0),
        OutlineEntry(title: '1.1', pageIndex: 2, depth: 1),
        OutlineEntry(title: 'Ch 2', pageIndex: 20, depth: 0),
      ]);
    });

    test('returns the top-level chapter that covers the page', () {
      expect(OutlineNode.chapterForPage(tree, 0, pageCount: 40)?.title, 'Ch 1');
      expect(OutlineNode.chapterForPage(tree, 10, pageCount: 40)?.title, 'Ch 1');
      expect(OutlineNode.chapterForPage(tree, 20, pageCount: 40)?.title, 'Ch 2');
      expect(
        OutlineNode.chapterOf(tree.first.children.first, tree).title,
        'Ch 1',
      );
    });
  });
}
