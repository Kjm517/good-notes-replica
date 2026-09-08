/// Turns a figure's own printed labels into identification questions.
///
/// A textbook diagram of the body already says "femur", "tibia", "patella",
/// each at a known place on the page — and [PdfTextLine] gives both the words
/// and their boxes. So the question, the answer and the marker can all be read
/// out of the PDF, with no model involved.
///
/// That matters for cost as much as accuracy: asking Gemini for the same items
/// means sending page images (up to [kMaxQuizImagePages] of them), which is
/// the single most expensive thing the quiz does. It also keeps working when
/// the API is rate-limited, which is when a student most wants a quiz.
library;

import 'dart:math' as math;

import '../search/pdf_text_line.dart';
import 'quiz_models.dart';
import 'quiz_quality.dart';

/// One label read off a figure: the word, and where it sits on the page.
class FigureLabel {
  const FigureLabel({required this.text, required this.box});

  final String text;

  /// 0–1 box of the label's own type — the thing to cover up before asking.
  final QuizHighlight box;

  @override
  String toString() => 'FigureLabel($text)';
}

/// Widest a line can be and still be a label rather than a sentence.
const double _maxLabelWidth = 0.32;

/// Fewer than this on a page and there is no figure worth quizzing.
const int _minLabelsPerFigure = 4;

/// Captions describe a figure; they are not parts of it.
final _caption = RegExp(
  r'^\s*(figure|fig\.?|table|plate|chart|graph|exhibit|box)\s*[\d.:()-]',
  caseSensitive: false,
);

/// Page furniture that happens to be short.
final _furniture = RegExp(
  r'^\s*(chapter|section|part|unit|page|copyright|source|adapted|reprinted|'
  r'continued|see also|note|key|legend)\b',
  caseSensitive: false,
);

final _hasLetter = RegExp(r'[A-Za-z]');
final _endsSentence = RegExp(r'[.!?;:,]\s*$');
final _mostlyDigits = RegExp(r'^[\d\s.,:%()+/-]+$');

/// True when [line] reads like a label pointing at part of a diagram.
///
/// Deliberately strict. A false positive becomes a question whose answer is a
/// page number or an axis title, which is worse than one fewer question.
bool isLabelLike(PdfTextLine line) {
  final text = line.text.trim();
  if (text.isEmpty) return false;
  if (text.length < 3 || text.length > 40) return false;
  if (!_hasLetter.hasMatch(text)) return false;
  if (_mostlyDigits.hasMatch(text)) return false;

  // Labels are named, not punctuated: "left ventricle", never "…the heart."
  if (_endsSentence.hasMatch(text)) return false;
  if (_caption.hasMatch(text) || _furniture.hasMatch(text)) return false;

  final words = text.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).length;
  if (words < 1 || words > 4) return false;

  // A line spanning the column is prose, whatever its punctuation.
  if (line.w > _maxLabelWidth) return false;
  if (line.w <= 0 || line.h <= 0) return false;

  // "the", "of" — a real answer, not a fragment.
  if (isGenericAnswer(text)) return false;
  return true;
}

/// Reads the labels off a figure page, or returns empty when there isn't one.
///
/// The test for "is this a figure" is spatial rather than semantic. Body type
/// stacks at a shared left margin; a diagram's labels sit at many different
/// x positions, because they follow the drawing. Counting distinct left edges
/// separates the two without reading a word.
List<FigureLabel> harvestFigureLabels(
  List<PdfTextLine> lines, {
  int maxLabels = 12,
  /// True when a picture has already been located in the page pixels.
  ///
  /// The scatter, stacking and density rules below exist to answer "is there a
  /// figure here?" from text alone. Once the pixels have answered that, they
  /// are not just redundant but wrong: a diagram's labels are being judged by
  /// heuristics designed to reject the slide it sits on.
  bool assumeFigure = false,
}) {
  final candidates = [for (final line in lines) if (isLabelLike(line)) line];
  if (candidates.length < (assumeFigure ? 2 : _minLabelsPerFigure)) {
    return const [];
  }
  if (assumeFigure) return _toLabels(candidates, maxLabels);

  // A vocabulary list or a table of contents is also short lines — but they
  // all begin at the same margin. A figure's do not.
  final buckets = <int>{
    for (final line in candidates) (line.x * 20).floor(),
  };
  if (buckets.length < 3) return const [];

  // Slides and bullet lists are also short lines at several x positions — a
  // title over two columns clears the bucket test above. What separates them
  // from a diagram is stacking: bullets sit in vertical runs at a shared left
  // edge, where a figure's labels follow the artwork and rarely line up more
  // than twice. Without this, a lecture deck produced questions whose answer
  // was a slide subtitle.
  final byBucket = <int, int>{};
  for (final line in candidates) {
    final bucket = (line.x * 20).floor();
    byBucket[bucket] = (byBucket[bucket] ?? 0) + 1;
  }
  final stacked = byBucket.values
      .where((n) => n >= 3)
      .fold<int>(0, (sum, n) => sum + n);
  // A strict majority, not half: a busy diagram can legitimately have a few
  // labels sharing a left edge, and rejecting on a tie threw those away too.
  if (stacked * 2 > candidates.length) return const [];

  // The labels of one figure occupy a region, not the whole sheet: a page of
  // short headings would otherwise qualify.
  var minX = 1.0, maxX = 0.0, minY = 1.0, maxY = 0.0;
  for (final line in candidates) {
    minX = math.min(minX, line.x);
    maxX = math.max(maxX, line.x + line.w);
    minY = math.min(minY, line.y);
    maxY = math.max(maxY, line.y + line.h);
  }
  final spread = (maxX - minX) * (maxY - minY);
  if (spread < 0.02) return const [];

  // How much of that region is type. A diagram is mostly drawing with a little
  // lettering; a slide is nearly all lettering. Measured over *every* line on
  // the page, not just the candidates, so body text counts against it.
  var textArea = 0.0;
  for (final line in lines) {
    final overlapW =
        math.min(line.x + line.w, maxX) - math.max(line.x, minX);
    final overlapH =
        math.min(line.y + line.h, maxY) - math.max(line.y, minY);
    if (overlapW > 0 && overlapH > 0) textArea += overlapW * overlapH;
  }
  final regionArea = (maxX - minX) * (maxY - minY);
  if (regionArea > 0 && textArea / regionArea > 0.18) return const [];

  return _toLabels(candidates, maxLabels);
}

List<FigureLabel> _toLabels(List<PdfTextLine> candidates, int maxLabels) {
  final seen = <String>{};
  final out = <FigureLabel>[];
  for (final line in candidates) {
    final text = line.text.trim();
    // The same word labelled twice (a legend and the drawing) is one question.
    if (!seen.add(text.toLowerCase())) continue;
    out.add(
      FigureLabel(
        text: text,
        box: QuizHighlight(
          x: line.x,
          y: line.y,
          w: line.w,
          h: line.h,
          precise: true,
        ),
      ),
    );
    if (out.length >= maxLabels) break;
  }
  return out;
}

/// The part of the page the figure occupies.
///
/// Taken from the labels themselves rather than guessed: they sit on the
/// drawing, so their bounding box plus a margin is the figure. Padding is
/// generous enough to include the artwork the labels point at, and clamped so
/// a label near the edge cannot push the crop off the page.
QuizHighlight figureRegion(List<FigureLabel> labels, {double pad = 0.06}) {
  var left = 1.0, top = 1.0, right = 0.0, bottom = 0.0;
  for (final label in labels) {
    left = math.min(left, label.box.x);
    top = math.min(top, label.box.y);
    right = math.max(right, label.box.x + label.box.w);
    bottom = math.max(bottom, label.box.y + label.box.h);
  }
  if (right <= left || bottom <= top) {
    return const QuizHighlight(x: 0, y: 0, w: 1, h: 1);
  }
  final x = (left - pad).clamp(0.0, 1.0);
  final y = (top - pad).clamp(0.0, 1.0);
  return QuizHighlight(
    x: x,
    y: y,
    w: (right + pad).clamp(0.0, 1.0) - x,
    h: (bottom + pad).clamp(0.0, 1.0) - y,
    precise: true,
  );
}

/// The labels that sit inside [region], with a little tolerance.
///
/// A page can hold two plates. Pairing every label on the page with one
/// picture would blank words that belong to the other and ask about a
/// structure that is not on screen.
List<FigureLabel> labelsInside(
  QuizHighlight region,
  List<FigureLabel> labels, {
  double slack = 0.02,
}) {
  final left = region.x - slack;
  final top = region.y - slack;
  final right = region.x + region.w + slack;
  final bottom = region.y + region.h + slack;
  return [
    for (final label in labels)
      if (label.box.x >= left &&
          label.box.y >= top &&
          label.box.x + label.box.w <= right &&
          label.box.y + label.box.h <= bottom)
        label,
  ];
}

/// Builds identification questions from harvested [labels].
///
/// One question per label, all sharing one figure with every label blanked.
/// Covering only the asked-about word would leave the answer readable on a
/// neighbouring label, or on the same term printed twice.
///
/// These skip the exam-style filter the model's output goes through: that
/// filter exists to catch invented questions, and nothing here is invented —
/// the answer is the word the book printed.
List<QuizQuestion> identificationFromLabels(
  int pageIndex,
  List<FigureLabel> labels, {
  int max = 8,
  /// The picture the labels belong to, when it has been located in the page
  /// pixels. Without it the crop falls back to the labels' own bounding box,
  /// which on a plate whose labels run down one side shows the column of
  /// words instead of the drawing they point at.
  QuizHighlight? region,
}) {
  if (labels.isEmpty) return const [];
  final crop = region ?? figureRegion(labels);
  final erase = [for (final label in labels) label.box];

  final out = <QuizQuestion>[];
  for (var i = 0; i < labels.length && out.length < max; i++) {
    final label = labels[i];
    out.add(
      QuizQuestion(
        kind: QuizKind.identification,
        // The marker number is what the student is looking at, so the prompt
        // names it rather than saying "the marked part".
        prompt: 'What is labelled ${i + 1} on this figure?',
        choices: const [],
        correctIndex: 0,
        acceptedAnswer: label.text,
        explanation:
            'The figure on page ${pageIndex + 1} labels this part '
            '"${label.text}". Reading it against the parts around it is what '
            'makes the diagram usable rather than memorised.',
        pageIndex: pageIndex,
        highlight: label.box,
        figure: QuizFigure(region: crop, erase: erase, targetIndex: i),
      ),
    );
  }
  return out;
}
