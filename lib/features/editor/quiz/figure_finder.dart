/// Finds the illustrations on a rendered page.
///
/// The app has no way to ask a PDF for its embedded images — pdfrx exposes no
/// object-level API — so the picture is found the other way round: render the
/// page, then look for where the ink is. Artwork is a large contiguous run of
/// non-background pixels; body text is thin, evenly spaced, and already known
/// from the text layer, so it can be subtracted before looking.
///
/// This is what makes a diagram quiz about the diagram. Harvesting labels off
/// whatever text a page happens to carry produced questions whose answer was a
/// slide subtitle, because nothing checked there was a picture there at all.
///
/// Deliberately split in two: [findFigureRegions] is pure arithmetic over a
/// pixel buffer and can be tested without a device, and the caller converts a
/// rendered page into that buffer.
library;

import 'dart:math' as math;
import 'dart:typed_data';

import 'quiz_models.dart';

/// A picture found on the page.
class FigureRegion {
  const FigureRegion({required this.box, required this.inkRatio});

  /// Where it sits, in 0–1 page space.
  final QuizHighlight box;

  /// How much of the box is drawn on, 0–1. A photograph approaches 1; a line
  /// drawing sits far lower, which is why the threshold is generous.
  final double inkRatio;

  @override
  String toString() =>
      'FigureRegion(${box.x.toStringAsFixed(2)},${box.y.toStringAsFixed(2)} '
      '${box.w.toStringAsFixed(2)}x${box.h.toStringAsFixed(2)} '
      'ink ${(inkRatio * 100).round()}%)';
}

/// Tuning, gathered here because these are the numbers worth arguing about.
class FigureFinderOptions {
  const FigureFinderOptions({
    this.minAreaFraction = 0.03,
    this.minInkRatio = 0.02,
    this.inkThreshold = 28,
    this.textPadding = 0.004,
    this.maxRegions = 4,
    this.minDetail = 0.06,
  });

  /// Smaller than this share of the page and it is a bullet or a logo.
  final double minAreaFraction;

  /// A box that is almost empty is whitespace between paragraphs.
  final double minInkRatio;

  /// How far a channel must sit from the background to count as drawn on.
  /// Low enough to catch pale anatomical washes, high enough to ignore JPEG
  /// noise on a white page.
  final int inkThreshold;

  /// Text boxes are grown slightly before being subtracted: glyph geometry is
  /// tight, and antialiasing bleeds a pixel past it.
  final double textPadding;

  final int maxRegions;

  /// How much internal edge a region must have to be a drawing.
  ///
  /// A slide's coloured background is a large block of non-white pixels and
  /// passes every size and ink test, but it has almost no internal structure.
  /// A diagram is full of boundaries. Counting neighbour-to-neighbour changes
  /// separates the two without knowing what either depicts.
  final double minDetail;
}

/// Finds pictures in an RGBA buffer, largest first.
///
/// [textBoxes] are 0–1 page-space boxes from the PDF's text layer. They are
/// erased before the search so a paragraph is never mistaken for artwork.
List<FigureRegion> findFigureRegions({
  required Uint8List rgba,
  required int width,
  required int height,
  List<QuizHighlight> textBoxes = const [],
  FigureFinderOptions options = const FigureFinderOptions(),
}) {
  if (width <= 0 || height <= 0 || rgba.length < width * height * 4) {
    return const [];
  }

  final background = _backgroundColour(rgba, width, height);
  final ink = _inkMask(rgba, width, height, background, options.inkThreshold);
  _eraseText(ink, width, height, textBoxes, options.textPadding);

  final components = _components(ink, width, height);
  final pageArea = width * height;
  final out = <FigureRegion>[];
  for (final c in components) {
    final boxArea = (c.right - c.left + 1) * (c.bottom - c.top + 1);
    if (boxArea / pageArea < options.minAreaFraction) continue;
    final ratio = c.count / boxArea;
    if (ratio < options.minInkRatio) continue;
    final detail = _detailRatio(rgba, width, height, c, options.inkThreshold);
    if (detail < options.minDetail) continue;
    out.add(
      FigureRegion(
        box: QuizHighlight(
          x: c.left / width,
          y: c.top / height,
          w: (c.right - c.left + 1) / width,
          h: (c.bottom - c.top + 1) / height,
          precise: true,
        ),
        inkRatio: ratio,
      ),
    );
  }
  out.sort((a, b) => (b.box.w * b.box.h).compareTo(a.box.w * a.box.h));
  return out.take(options.maxRegions).toList();
}

/// Share of pixels inside [c] that differ from the neighbour to their right or
/// below — a cheap stand-in for "how much is drawn here".
///
/// A flat fill scores near zero however large or saturated it is. Line art and
/// photographs score far higher, and the threshold sits well below both.
double _detailRatio(
  Uint8List rgba,
  int width,
  int height,
  _Component c,
  int threshold,
) {
  var edges = 0;
  var counted = 0;
  final edgeDelta = math.max(8, threshold ~/ 2);
  for (var y = c.top; y < c.bottom; y++) {
    for (var x = c.left; x < c.right; x++) {
      final i = (y * width + x) * 4;
      final right = (y * width + x + 1) * 4;
      final below = ((y + 1) * width + x) * 4;
      counted++;
      final dRight = math.max(
        (rgba[i] - rgba[right]).abs(),
        math.max(
          (rgba[i + 1] - rgba[right + 1]).abs(),
          (rgba[i + 2] - rgba[right + 2]).abs(),
        ),
      );
      final dBelow = math.max(
        (rgba[i] - rgba[below]).abs(),
        math.max(
          (rgba[i + 1] - rgba[below + 1]).abs(),
          (rgba[i + 2] - rgba[below + 2]).abs(),
        ),
      );
      if (dRight >= edgeDelta || dBelow >= edgeDelta) edges++;
    }
  }
  return counted == 0 ? 0 : edges / counted;
}

/// The page's paper colour, taken from the border.
///
/// Sampling the whole page would be swayed by a full-bleed illustration; the
/// outer ring is margin on almost every page that has one.
_Rgb _backgroundColour(Uint8List rgba, int width, int height) {
  var r = 0, g = 0, b = 0, n = 0;
  void sample(int x, int y) {
    final i = (y * width + x) * 4;
    r += rgba[i];
    g += rgba[i + 1];
    b += rgba[i + 2];
    n++;
  }

  for (var x = 0; x < width; x++) {
    sample(x, 0);
    sample(x, height - 1);
  }
  for (var y = 0; y < height; y++) {
    sample(0, y);
    sample(width - 1, y);
  }
  if (n == 0) return const _Rgb(255, 255, 255);
  return _Rgb(r ~/ n, g ~/ n, b ~/ n);
}

Uint8List _inkMask(
  Uint8List rgba,
  int width,
  int height,
  _Rgb background,
  int threshold,
) {
  final mask = Uint8List(width * height);
  for (var i = 0, p = 0; p < mask.length; p++, i += 4) {
    final dr = (rgba[i] - background.r).abs();
    final dg = (rgba[i + 1] - background.g).abs();
    final db = (rgba[i + 2] - background.b).abs();
    // Max channel distance, not average: a strong shift in one channel is a
    // coloured mark, and averaging would dilute it below the threshold.
    final delta = math.max(dr, math.max(dg, db));
    if (delta >= threshold) mask[p] = 1;
  }
  return mask;
}

void _eraseText(
  Uint8List mask,
  int width,
  int height,
  List<QuizHighlight> boxes,
  double padding,
) {
  for (final box in boxes) {
    final left = ((box.x - padding) * width).floor().clamp(0, width - 1);
    final right =
        ((box.x + box.w + padding) * width).ceil().clamp(0, width - 1);
    final top = ((box.y - padding) * height).floor().clamp(0, height - 1);
    final bottom =
        ((box.y + box.h + padding) * height).ceil().clamp(0, height - 1);
    for (var y = top; y <= bottom; y++) {
      final row = y * width;
      for (var x = left; x <= right; x++) {
        mask[row + x] = 0;
      }
    }
  }
}

class _Component {
  _Component(this.left, this.top)
      : right = left,
        bottom = top,
        count = 0;

  int left;
  int top;
  int right;
  int bottom;
  int count;
}

class _Rgb {
  const _Rgb(this.r, this.g, this.b);
  final int r;
  final int g;
  final int b;
}

/// Connected runs of ink, 4-neighbour, flood filled iteratively.
///
/// Recursion would overflow the stack on a full-page illustration, which is
/// exactly the case that matters here.
List<_Component> _components(Uint8List mask, int width, int height) {
  final seen = Uint8List(width * height);
  final out = <_Component>[];
  final stack = <int>[];

  for (var start = 0; start < mask.length; start++) {
    if (mask[start] == 0 || seen[start] == 1) continue;
    final component = _Component(start % width, start ~/ width);
    stack.add(start);
    seen[start] = 1;
    while (stack.isNotEmpty) {
      final index = stack.removeLast();
      final x = index % width;
      final y = index ~/ width;
      component.count++;
      if (x < component.left) component.left = x;
      if (x > component.right) component.right = x;
      if (y < component.top) component.top = y;
      if (y > component.bottom) component.bottom = y;

      void visit(int nx, int ny) {
        if (nx < 0 || ny < 0 || nx >= width || ny >= height) return;
        final n = ny * width + nx;
        if (mask[n] == 0 || seen[n] == 1) return;
        seen[n] = 1;
        stack.add(n);
      }

      visit(x - 1, y);
      visit(x + 1, y);
      visit(x, y - 1);
      visit(x, y + 1);
    }
    out.add(component);
  }
  return out;
}
