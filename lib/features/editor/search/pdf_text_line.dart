import 'dart:math' as math;

/// One line of text on a PDF page, with its box in 0–1 page fractions
/// (origin top-left, the same space the rendered page image uses).
class PdfTextLine {
  const PdfTextLine({
    required this.text,
    required this.x,
    required this.y,
    required this.w,
    required this.h,
    this.chars = const [],
  });

  final String text;
  final double x;
  final double y;
  final double w;
  final double h;

  /// One box per character of [text], where the reader could measure them.
  /// Empty when the geometry only came at line granularity.
  final List<CharBox> chars;
}

/// One character's box on the page, in the same 0–1 top-left space.
class CharBox {
  const CharBox({
    required this.x,
    required this.y,
    required this.w,
    required this.h,
  });

  final double x;
  final double y;
  final double w;
  final double h;

  double get right => x + w;
  double get centerY => y + h / 2;
}

/// Groups per-character boxes into lines.
///
/// PDFium reports a box per character rather than per line, which is the
/// accurate way round: a line is then whatever the glyphs say it is. A line
/// ends at a newline, at a drop to a new baseline, at a carriage return to the
/// left, or at a horizontal jump too wide to be a word space — the last of
/// which is what separates the two columns of a textbook page, and what a
/// baseline-only rule gets wrong by inking straight across the gutter.
List<PdfTextLine> linesFromCharBoxes({
  required String text,
  required List<CharBox> boxes,
  int maxLines = 400,
}) {
  final count = math.min(text.length, boxes.length);
  final lines = <PdfTextLine>[];

  final buffer = StringBuffer();
  var glyphs = <CharBox>[];
  double? left, top, right, bottom;

  void flush() {
    // Text and glyphs have to stay index-aligned, so trimming drops both.
    var value = buffer.toString();
    var boxes = glyphs;
    buffer.clear();
    glyphs = <CharBox>[];
    var lead = 0;
    while (lead < value.length && value[lead].trim().isEmpty) {
      lead++;
    }
    var tail = value.length;
    while (tail > lead && value[tail - 1].trim().isEmpty) {
      tail--;
    }
    if (lead > 0 || tail < value.length) {
      value = value.substring(lead, tail);
      boxes = boxes.sublist(
        math.min(lead, boxes.length),
        math.min(tail, boxes.length),
      );
    }
    final l = left, t = top, r = right, b = bottom;
    left = top = right = bottom = null;
    if (value.isEmpty || l == null || t == null || r == null || b == null) {
      return;
    }
    if (r <= l || b <= t) return;
    lines.add(
      PdfTextLine(
        text: value,
        x: l.clamp(0.0, 1.0),
        y: t.clamp(0.0, 1.0),
        w: (r - l).clamp(0.0, 1.0),
        h: (b - t).clamp(0.0, 1.0),
        chars: boxes,
      ),
    );
  }

  for (var i = 0; i < count && lines.length < maxLines; i++) {
    final char = text[i];
    if (char == '\n' || char == '\r') {
      flush();
      continue;
    }
    final box = boxes[i];
    if (!box.x.isFinite || !box.y.isFinite || !box.w.isFinite || !box.h.isFinite) {
      continue;
    }

    if (right != null && top != null && bottom != null) {
      final height = math.max(bottom! - top!, box.h);
      final movedDown = (box.centerY - (top! + (bottom! - top!) / 2)).abs() >
          math.max(height, 0.004) * 0.6;
      final wentBack = box.x < right! - math.max(box.w, 0.002);
      final jumped = box.x - right! > math.max(height * 1.2, 0.02);
      if (movedDown || wentBack || jumped) flush();
    }

    buffer.write(char);
    glyphs.add(box);
    left = left == null ? box.x : math.min(left!, box.x);
    right = right == null ? box.right : math.max(right!, box.right);
    top = top == null ? box.y : math.min(top!, box.y);
    bottom = bottom == null ? box.y + box.h : math.max(bottom!, box.y + box.h);
  }
  flush();
  return lines;
}
