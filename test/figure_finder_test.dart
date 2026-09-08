import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:notably/features/editor/quiz/figure_finder.dart';
import 'package:notably/features/editor/quiz/quiz_models.dart';

/// A synthetic page: white paper, with whatever is drawn on it.
class Page {
  Page(this.width, this.height)
      : rgba = Uint8List(width * height * 4)
          ..fillRange(0, width * height * 4, 255);

  final int width;
  final int height;
  final Uint8List rgba;

  /// Draws something with internal structure — strokes, not a paint swatch.
  ///
  /// A solid block is deliberately *not* a figure: a slide's colour panel is
  /// exactly that, and treating it as artwork is what produced questions
  /// whose answer was a heading. Fixtures therefore have to look like line
  /// art for the finder to accept them, which is the point.
  void drawing(double x, double y, double w, double h,
      {int r = 40, int g = 40, int b = 40, int strokes = 14}) {
    fill(x, y, w, h, r: 250, g: 245, b: 245);
    for (var i = 0; i < strokes; i++) {
      final t = i / strokes;
      fill(x + t * w, y, w / (strokes * 2.2), h, r: r, g: g, b: b);
      fill(x, y + t * h, w, h / (strokes * 2.2), r: r, g: g, b: b);
    }
  }

  /// Fills a 0–1 rectangle with a colour.
  void fill(double x, double y, double w, double h,
      {int r = 40, int g = 40, int b = 40}) {
    final left = (x * width).round();
    final top = (y * height).round();
    final right = ((x + w) * width).round();
    final bottom = ((y + h) * height).round();
    for (var py = top; py < bottom && py < height; py++) {
      for (var px = left; px < right && px < width; px++) {
        final i = (py * width + px) * 4;
        rgba[i] = r;
        rgba[i + 1] = g;
        rgba[i + 2] = b;
        rgba[i + 3] = 255;
      }
    }
  }
}

void main() {
  group('finding the picture on a page', () {
    test('finds a single illustration', () {
      final page = Page(120, 160)..drawing(0.15, 0.20, 0.60, 0.45);
      final found = findFigureRegions(
        rgba: page.rgba,
        width: page.width,
        height: page.height,
      );
      expect(found, hasLength(1));
      final box = found.first.box;
      expect(box.x, closeTo(0.15, 0.03));
      expect(box.y, closeTo(0.20, 0.03));
      expect(box.w, closeTo(0.60, 0.05));
      expect(box.h, closeTo(0.45, 0.05));
      // Line art, not a solid block: much of the box is paper between strokes,
      // which is exactly why the ink threshold is generous.
      expect(found.first.inkRatio, greaterThan(0.4));
    });

    test('a flat slide background is not a diagram', () {
      // The bug this catches: a pink PowerPoint slide is a large block of
      // non-white pixels, so every size and ink test passes. It has no
      // internal structure, and asking "what is labelled 1" about it produced
      // the answer "Outline".
      final page = Page(160, 120)
        ..fill(0.05, 0.10, 0.90, 0.75, r: 250, g: 220, b: 225);
      expect(
        findFigureRegions(
          rgba: page.rgba,
          width: page.width,
          height: page.height,
        ),
        isEmpty,
      );
    });

    test('line art on that same slide still counts', () {
      // Same pink panel, now with a drawing on it: stripes stand in for the
      // boundaries any diagram has.
      final page = Page(160, 120)
        ..fill(0.05, 0.10, 0.90, 0.75, r: 250, g: 220, b: 225);
      for (var i = 0; i < 24; i++) {
        page.fill(0.10 + i * 0.03, 0.20, 0.012, 0.50, r: 30, g: 30, b: 90);
      }
      final found = findFigureRegions(
        rgba: page.rgba,
        width: page.width,
        height: page.height,
      );
      expect(found, isNotEmpty);
    });

    test('a blank page has no figures', () {
      final page = Page(80, 100);
      expect(
        findFigureRegions(
          rgba: page.rgba,
          width: page.width,
          height: page.height,
        ),
        isEmpty,
      );
    });

    test('returns the diagram and not the caption beneath it', () {
      // A plate with a block of type under it, as a textbook page has.
      final page = Page(160, 200)..drawing(0.15, 0.10, 0.60, 0.40);
      final textBoxes = <QuizHighlight>[];
      for (var i = 0; i < 8; i++) {
        final y = 0.60 + i * 0.04;
        page.fill(0.10, y, 0.75, 0.02);
        textBoxes.add(QuizHighlight(x: 0.10, y: y, w: 0.75, h: 0.02));
      }
      final found = findFigureRegions(
        rgba: page.rgba,
        width: page.width,
        height: page.height,
        textBoxes: textBoxes,
      );
      expect(found, hasLength(1));
      // The picture, stopping before the prose starts.
      expect(found.first.box.y, closeTo(0.10, 0.03));
      expect(found.first.box.y + found.first.box.h, lessThan(0.55));
    });

    test('keeps the leader lines after the label words are erased', () {
      // What a labelled plate is: a drawing, a thin line out to the edge, and
      // a word at the end of it. Erasing the word must leave the line, or the
      // student is asked to name a structure with nothing pointing at it.
      final page = Page(200, 160)
        ..drawing(0.10, 0.30, 0.35, 0.35) // the organ
        ..fill(0.40, 0.46, 0.35, 0.008) // leader line, touching the organ
        ..fill(0.76, 0.44, 0.18, 0.04); // the word itself
      const label = QuizHighlight(x: 0.76, y: 0.44, w: 0.18, h: 0.04);

      final found = findFigureRegions(
        rgba: page.rgba,
        width: page.width,
        height: page.height,
        textBoxes: const [label],
      );
      expect(found, hasLength(1));
      final box = found.first.box;
      // The region still reaches past the drawing, because the leader line
      // survived the erase and is part of the same connected figure.
      expect(box.x + box.w, greaterThan(0.70),
          reason: 'leader line was erased along with the label');
      expect(box.x + box.w, lessThan(0.80),
          reason: 'the label word itself should be gone');
    });

    test('separates two diagrams side by side', () {
      // The heart-valve slide shape: two plates on one page.
      final page = Page(160, 120)
        ..drawing(0.05, 0.15, 0.38, 0.60)
        ..drawing(0.55, 0.15, 0.38, 0.60);
      final found = findFigureRegions(
        rgba: page.rgba,
        width: page.width,
        height: page.height,
      );
      expect(found, hasLength(2));
      final lefts = found.map((f) => f.box.x).toList()..sort();
      expect(lefts.first, closeTo(0.05, 0.03));
      expect(lefts.last, closeTo(0.55, 0.03));
    });

    test('skips something too small to be an illustration', () {
      final page = Page(200, 200)..drawing(0.45, 0.45, 0.05, 0.05);
      expect(
        findFigureRegions(
          rgba: page.rgba,
          width: page.width,
          height: page.height,
        ),
        isEmpty,
      );
    });

    test('finds a pale wash, not just strong ink', () {
      // Anatomical plates are largely soft pinks; a threshold tuned for black
      // type would miss the drawing entirely.
      final page = Page(120, 120)
        ..drawing(0.20, 0.20, 0.50, 0.50, r: 240, g: 205, b: 205);
      final found = findFigureRegions(
        rgba: page.rgba,
        width: page.width,
        height: page.height,
      );
      expect(found, hasLength(1));
      expect(found.first.box.w, closeTo(0.50, 0.05));
    });

    test('reads the paper colour from the margin, not the artwork', () {
      // A full-bleed pink slide with a white figure on it: sampling the whole
      // page would call pink "background" and find nothing.
      final page = Page(120, 120)
        ..fill(0.0, 0.0, 1.0, 1.0, r: 250, g: 220, b: 225)
        ..drawing(0.25, 0.25, 0.45, 0.45, r: 90, g: 60, b: 60);
      final found = findFigureRegions(
        rgba: page.rgba,
        width: page.width,
        height: page.height,
      );
      expect(found, hasLength(1));
      expect(found.first.box.x, closeTo(0.25, 0.04));
    });

    test('returns the largest first and caps how many', () {
      final page = Page(200, 200);
      for (var i = 0; i < 6; i++) {
        page.drawing(0.02 + i * 0.16, 0.30, 0.13, 0.10 + i * 0.05);
      }
      final found = findFigureRegions(
        rgba: page.rgba,
        width: page.width,
        height: page.height,
        options: const FigureFinderOptions(maxRegions: 3),
      );
      expect(found, hasLength(3));
      final areas = [for (final f in found) f.box.w * f.box.h];
      expect(areas.first, greaterThanOrEqualTo(areas.last));
    });

    test('does not fall over on a garbage buffer', () {
      expect(
        findFigureRegions(rgba: Uint8List(0), width: 0, height: 0),
        isEmpty,
      );
      expect(
        findFigureRegions(rgba: Uint8List(10), width: 100, height: 100),
        isEmpty,
      );
    });

    test('survives a page that is entirely one illustration', () {
      // Flood filling this recursively would overflow the stack.
      final page = Page(220, 220)..fill(0.0, 0.0, 1.0, 1.0, r: 10, g: 10, b: 10);
      // Border sampling makes the artwork itself the background here, so the
      // honest answer is "no distinguishable figure" rather than a crash.
      expect(
        () => findFigureRegions(
          rgba: page.rgba,
          width: page.width,
          height: page.height,
        ),
        returnsNormally,
      );
    });
  });
}
