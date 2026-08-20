import 'dart:math' as math;

import '../search/pdf_text_line.dart';
import 'quiz_align.dart';
import 'quiz_models.dart';

/// Where the answer was found on one page, as highlighter strokes.
class AnswerMatch {
  const AnswerMatch({
    required this.marks,
    required this.score,
    required this.exact,
    this.context = 0,
    this.quoted = false,
  });

  static const none = AnswerMatch(marks: [], score: 0, exact: false);

  /// One stroke per line the marked passage runs across, in 0–1 page
  /// fractions.
  final List<QuizHighlight> marks;

  /// How strongly this page matched — used to choose between pages.
  final int score;

  /// True when the answer's own wording was on the page, not just its terms.
  final bool exact;

  /// How much of the question's own subject the page discusses.
  ///
  /// A textbook names a term in a dozen places; only one of them is teaching
  /// it. "Lipoteichoic acid" appears in a list of what H-ficolin binds to on a
  /// page about complement, and again where the book explains gram-positive
  /// cell walls — the same phrase, but only the second answers the question.
  final int context;

  /// The sentence the model quoted from the source was found on this page,
  /// word for word. Nothing beats that.
  final bool quoted;

  bool get isEmpty => marks.isEmpty;

  /// Worth stopping the search for: the sentence the source was quoted as
  /// stating, or the answer in the book's own words on a page that is talking
  /// about what the question asked.
  bool get conclusive => quoted || (exact && context >= 4);
}

/// Lowercased and single-spaced, keeping decimal points and sentence marks —
/// "37.2°C (99.0°F)" has to stay "37.2" and "99.0" to be findable, and the
/// full stops are what let a match grow out to the sentence around it.
String normalizeForMatch(String raw) => normalizeWithIndex(raw).$1;

final _keep = RegExp(r'[a-z0-9.?!;:()-]');

/// [normalizeForMatch], plus where each character of the result came from in
/// [raw] — so a match can be traced back to the glyphs that carry it.
(String, List<int>) normalizeWithIndex(String raw) {
  final buffer = StringBuffer();
  final sources = <int>[];
  var pendingSpace = false;
  for (var i = 0; i < raw.length; i++) {
    final char = raw[i].toLowerCase();
    if (!_keep.hasMatch(char)) {
      // Runs of anything unkeepable collapse to the single space that
      // separates the words either side of them.
      if (buffer.isNotEmpty) pendingSpace = true;
      continue;
    }
    if (pendingSpace) {
      buffer.write(' ');
      sources.add(i);
      pendingSpace = false;
    }
    buffer.write(char);
    sources.add(i);
  }
  return (buffer.toString(), sources);
}

String _trimEdges(String value) =>
    value.replaceAll(RegExp(r'^[\s.?!-]+'), '').replaceAll(RegExp(r'[\s.?!-]+$'), '');

/// Phrases worth hunting for, longest first: the answer as written, then
/// progressively looser cuts of it, so "7 to 14 days after the first dose"
/// still lands when the book phrases the tail differently.
List<String> answerPhrases(String answer) {
  final full = _trimEdges(normalizeForMatch(answer));
  if (full.isEmpty) return const [];
  final out = <String>[];
  void add(String phrase) {
    final value = _trimEdges(phrase);
    if (value.length >= 6 && !out.contains(value)) out.add(value);
  }

  add(full);
  // Books rarely repeat a whole clause verbatim; the head of it is the part
  // that names the thing. That only holds for an answer-sized phrase — the
  // opening words of a whole claim ("patients with", "the risk of") would
  // match half the book.
  final words = full.split(' ');
  if (words.length > 8) return out;
  if (words.length > 4) add(words.take(4).join(' '));
  if (words.length > 2) add(words.take(2).join(' '));
  final leading = RegExp(r'^(the|a|an|its|their|of)\s+');
  if (leading.hasMatch(full)) add(full.replaceFirst(leading, ''));
  return out;
}

/// Figures, doses and thresholds pin a line far harder than prose does:
/// "37.2" appears on one page of a textbook, "temperature" on hundreds.
/// Short identifiers matter for the same reason — CD28 and B7 are dropped by
/// the word-length rule the page search uses.
List<String> answerMarkers(String answer) {
  final text = normalizeForMatch(answer);
  final seen = <String>{};
  final out = <String>[];
  // An acronym is as distinctive as a figure and just as short: HIV, TDF,
  // CD28, qSOFA are all dropped by the word-length rule, and all of them name
  // exactly the thing the student is looking for.
  for (final match in RegExp(r'\b[A-Za-z]?[A-Z]{2,}[0-9]*\b').allMatches(answer)) {
    final token = match.group(0)!.toLowerCase();
    if (token.length < 2 || !seen.add(token)) continue;
    out.add(token);
  }
  for (final match in RegExp(r'[a-z]*\d+(?:\.\d+)?[a-z]*').allMatches(text)) {
    final token = match.group(0)!;
    if (token.length < 2 || !seen.add(token)) continue;
    out.add(token);
  }
  return out.take(4).toList();
}

/// Citation tells, counted over the *visual* lines a PDF gives us.
///
/// A reference wraps over three or four typeset lines and only the first
/// carries its number, so the whole-page rule in `isReferencePage` — written
/// for one logical reference per line — reads a bibliography as ordinary
/// prose and lets the highlighter mark an author's name as if it were the
/// answer.
final _citationTells = [
  RegExp(r'\bet al\.?'),
  RegExp(r'\b(19|20)\d\d[;:]\s*\d'),
  RegExp(r'\bdoi\s*:'),
  RegExp(r'https?://'),
  RegExp(r'\bjournal of\b'),
  RegExp(r'\b(n engl j med|lancet|jama|clin infect dis|proc natl acad sci)\b'),
  RegExp(r'\b(j|am|clin|proc|rev|ann|arch|int)\s+[a-z]+\.\s*(19|20)\d\d'),
  RegExp(r'\d+[–-]\d+\.\s*$'),
];

/// True when a page is a reference list rather than something worth marking.
bool isReferenceLines(List<PdfTextLine> lines) {
  if (lines.length < 8) return false;
  final heading = RegExp(r'^(references|bibliography|further reading)\b');
  if (lines.take(6).any((l) => heading.hasMatch(l.text.trim().toLowerCase()))) {
    return true;
  }
  // Numbering alone is not enough — a chapter's numbered key points look the
  // same. It counts only alongside the tells that mean a citation.
  var citations = 0;
  var numbered = 0;
  for (final line in lines) {
    final text = line.text.toLowerCase().trim();
    if (_citationTells.any((tell) => tell.hasMatch(text))) {
      citations++;
    } else if (_numberedEntry.hasMatch(text)) {
      numbered++;
    }
  }
  final cited = citations / lines.length;
  return cited >= 0.15 || (cited >= 0.08 && (citations + numbered) / lines.length >= 0.35);
}

final _numberedEntry = RegExp(r'^\d{1,3}[.)]\s');

/// Words a textbook abbreviates mid-sentence, so the full stop after them is
/// not the end of anything.
const _abbreviations = {
  'fig', 'figs', 'no', 'nos', 'vs', 'ref', 'refs', 'eq', 'ch', 'chap',
  'pp', 'cf', 'al', 'approx', 'ca', 'vol', 'e', 'g', 'i',
};

/// Substring hits over [terms], plus stem hits for long words scored lower.
///
/// Textbooks inflect what a quiz answer names: "pericoronal" in the answer
/// against "pericoronitis" on the page, "extremities" against "extremity".
/// Cutting a long word to its first seven characters catches those without
/// letting a short word match half the page.
int termScore(String text, List<String> terms) {
  var score = 0;
  for (final term in terms) {
    if (text.contains(term)) {
      score += term.length >= 8 ? 2 : 1;
    } else if (term.length >= 9 && text.contains(term.substring(0, 7))) {
      score += 1;
    }
  }
  return score;
}

/// What to actually hunt for on the page.
///
/// A true/false item's accepted answer is the word "True", which appears on
/// no page in any useful sense — the thing the student is being shown is the
/// *claim*, so that is what gets marked. The same applies to any answer with
/// nothing searchable in it ("Yes", "None of these").
({String answer, String prompt}) searchSubject(String answer, String prompt) {
  if (prompt.trim().isNotEmpty && _verdicts.contains(normalizeForMatch(answer))) {
    return (answer: prompt, prompt: '');
  }
  final usable =
      answerMarkers(answer).isNotEmpty || answerSearchTerms(answer).isNotEmpty;
  if (usable) return (answer: answer, prompt: prompt);
  return (answer: prompt, prompt: '');
}

/// Answers that are a verdict on the question rather than a thing to find.
///
/// "true" is four letters and falls out of the search on its own; "false" is
/// five and does not — it survives as a search term and sends the highlighter
/// hunting for the literal word on the page. They have to be named.
const _verdicts = {
  'true', 'false', 'yes', 'no', 'correct', 'incorrect', 'both', 'neither',
  'all of the above', 'none of the above', 'all of these', 'none of these',
};

/// A cheap gate over text already extracted for Find: laying a page out to
/// get its geometry costs a PDF parse, and there is no point paying it for a
/// page that does not mention the answer at all.
///
/// Returns true when the page cannot be ruled out — including when there is
/// nothing distinctive to test with.
bool pageMightHoldAnswer(
  String pageText, {
  required String answer,
  String prompt = '',
}) {
  if (pageText.trim().isEmpty) return true;
  final subject = searchSubject(answer, prompt);
  final markers = answerMarkers(subject.answer);
  final terms = answerSearchTerms(subject.answer);
  if (markers.isEmpty && terms.isEmpty) return true;
  final text = normalizeForMatch(pageText);
  return markers.any(text.contains) || termScore(text, terms) > 0;
}

/// Finds the answer on a page and returns the strokes to paint over it.
///
/// Tries the answer's own wording first (that is what the student is looking
/// for), then its figures and identifiers, then the distinctive words shared
/// by the answer and the question. Whatever hits, the stroke is grown out to
/// the sentence around it, so the student sees the statement that explains the
/// answer and not a clipped fragment of it.
AnswerMatch findAnswerOnPage({
  required List<PdfTextLine> lines,
  required String answer,
  String prompt = '',
  String quote = '',
}) {
  if (lines.isEmpty || isReferenceLines(lines)) return AnswerMatch.none;
  final subject = searchSubject(answer, prompt);
  answer = subject.answer;
  prompt = subject.prompt;
  final page = _JoinedPage(lines);

  // The model was asked to copy the sentence that states the answer. It is
  // only trusted if the file actually contains it: an invented quote finds
  // nothing and costs nothing, while a real one is the best evidence there is.
  final quoted = _findQuote(page, quote);
  if (quoted != null) {
    return AnswerMatch(
      marks: quoted,
      score: 40,
      exact: true,
      quoted: true,
      context: _contextScore(page, prompt, answer),
    );
  }

  for (final phrase in answerPhrases(answer)) {
    final at = page.text.indexOf(phrase);
    if (at < 0) continue;
    final marks = page.marksForSentenceAround(at, at + phrase.length);
    if (marks.isNotEmpty) {
      final context = _contextScore(page, prompt, answer);
      return AnswerMatch(
        marks: marks,
        score: 8 + phrase.split(' ').length + context,
        exact: true,
        context: context,
      );
    }
  }

  final markers = answerMarkers(answer);
  final answerTerms = answerSearchTerms(answer);
  final promptTerms = [
    for (final term in answerSearchTerms(prompt))
      if (!answerTerms.contains(term)) term,
  ];
  if (markers.isEmpty && answerTerms.isEmpty) return AnswerMatch.none;

  var bestLine = -1;
  var bestScore = 0;
  for (var i = 0; i < page.lines.length; i++) {
    final text = page.lineTexts[i];
    final figures = markers.where(text.contains).length;
    final answered = termScore(text, answerTerms);
    // The question's words are everywhere in a textbook — "clinical" and
    // "studies" sit on most pages of one. They may break a tie between lines,
    // but a line with nothing from the *answer* on it is not a match at all.
    if (figures == 0 && answered == 0) continue;
    final score =
        figures * 3 + answered * 2 + math.min<int>(termScore(text, promptTerms), 2);
    if (score > bestScore) {
      bestScore = score;
      bestLine = i;
    }
  }
  // One short word in common is a coincidence, not a citation.
  if (bestLine < 0 || bestScore < 4) return AnswerMatch.none;

  final context = _contextScore(page, prompt, answer);
  return AnswerMatch(
    marks: page.marksForSentenceAround(
      page.startOf(bestLine),
      page.endOf(bestLine),
    ),
    score: bestScore + context,
    exact: false,
    context: context,
  );
}

/// Looks for the sentence the model quoted from the source.
///
/// Extraction and the model's copy can differ in their tails — a line break,
/// a hyphen, a footnote marker — so a long head of the quote counts too. What
/// is never allowed is a loose match: this is evidence precisely because it is
/// the book's own wording.
List<QuizHighlight>? _findQuote(_JoinedPage page, String quote) {
  final normalized = _trimEdges(normalizeForMatch(quote));
  if (normalized.length < 24) return null;

  final candidates = <String>[normalized];
  final words = normalized.split(' ');
  if (words.length > 8) candidates.add(words.take(words.length * 2 ~/ 3).join(' '));
  if (words.length > 12) candidates.add(words.take(8).join(' '));

  for (final candidate in candidates) {
    if (candidate.length < 24) continue;
    final at = page.text.indexOf(candidate);
    if (at < 0) continue;
    final marks = page.marksForSentenceAround(at, at + candidate.length);
    if (marks.isNotEmpty) return marks;
  }
  return null;
}

/// How much of the question's subject the whole page talks about.
///
/// Deliberately a page-level, tie-breaking signal only: question words can
/// never make a match on their own — that is what put a highlight on a
/// telbivudine page — but among pages that all state the answer, the one
/// discussing the topic is the one the student wants.
int _contextScore(_JoinedPage page, String prompt, String answer) {
  if (prompt.trim().isEmpty) return 0;
  final answerTerms = answerSearchTerms(answer);
  final promptTerms = [
    for (final term in answerSearchTerms(prompt))
      if (!answerTerms.contains(term)) term,
  ];
  if (promptTerms.isEmpty) return 0;
  return math.min(termScore(page.text, promptTerms), 8);
}

/// The page's lines laid end to end, so a passage can be matched and marked
/// across the line breaks the typesetter happened to use.
class _JoinedPage {
  _JoinedPage(this.lines) {
    final buffer = StringBuffer();
    for (var i = 0; i < lines.length; i++) {
      if (i > 0) buffer.write(' ');
      _starts.add(buffer.length);
      final normalized = normalizeWithIndex(lines[i].text);
      lineTexts.add(normalized.$1);
      _sources.add(normalized.$2);
      buffer.write(normalized.$1);
      _ends.add(buffer.length);
    }
    text = buffer.toString();
  }

  final List<PdfTextLine> lines;
  final List<String> lineTexts = [];

  /// For each line, where each normalized character came from in the line's
  /// own text — which is what turns a match back into the glyphs that carry
  /// it, and so into an exact box.
  final List<List<int>> _sources = [];
  final List<int> _starts = [];
  final List<int> _ends = [];
  late final String text;

  int startOf(int line) => _starts[line];
  int endOf(int line) => _ends[line];

  /// Grows the match out to the clause holding it, so the student reads the
  /// statement rather than a fragment — and stops there.
  ///
  /// Textbook sentences run long: the one naming HSV "volcano ulcers" carries
  /// on past a semicolon into confluent ulcers and pseudomembranes, which are
  /// not the answer. Growth therefore ends at the first clause break, not the
  /// first full stop. Headings and captions carry no punctuation at all, so
  /// backwards growth is additionally capped at one line.
  List<QuizHighlight> marksForSentenceAround(int start, int stop) {
    final first = _lineAt(start);
    final last = _lineAt(math.max(start, stop - 1));
    final floor = _starts[math.max(0, first - 1)];
    final ceiling = _ends[math.min(lines.length - 1, last + 2)];
    final clause = _clauseSpan(start, stop);
    final grown = _marks(
      math.max(clause.$1, floor),
      math.min(clause.$2, ceiling),
    );
    if (grown.length <= 4) return grown;
    return _marks(start, stop);
  }

  int _lineAt(int offset) {
    for (var i = 0; i < lines.length; i++) {
      if (offset < _ends[i]) return i;
    }
    return lines.length - 1;
  }

  (int, int) _clauseSpan(int start, int stop) {
    const reach = 240;
    var from = math.max(0, start - reach);
    for (var i = start - 1; i > from; i--) {
      if (_endsClause(i)) {
        from = i + 1;
        break;
      }
    }
    // Forward, an unfound break means the ink would run on into text that has
    // nothing to do with the answer, so it stops at the match instead.
    var to = stop;
    final limit = math.min(text.length, stop + reach);
    for (var i = stop; i < limit; i++) {
      // "(for definitions of classes of host-associated microbes, see Table
      // 1.1)" is an aside, not part of the statement being marked.
      if (text[i] == '(') {
        to = i;
        break;
      }
      if (_endsClause(i)) {
        to = i + 1;
        break;
      }
    }
    while (to > stop && text[to - 1] == ' ') {
      to--;
    }
    final leading = _citationMarker.firstMatch(
      text.substring(from, math.min(from + 13, text.length)),
    );
    if (leading != null) from += leading.group(0)!.length;
    while (from < text.length && text[from] == ' ') {
      from++;
    }
    return (from, math.max(to, stop));
  }

  /// A full stop between digits is a decimal point, not the end of anything.
  /// Semicolons and colons count: they are where a long textbook sentence
  /// stops being about the thing it started with.
  /// A superscript reference number, extracted as ordinary digits glued to
  /// the full stop it follows: "…the mucous membranes.25 Microorganisms…".
  static final _citationMarker = RegExp(r'^\d[\d,–-]{0,11}(?=\s|$)');

  bool _endsClause(int i) {
    final char = text[i];
    if (!'.?!;:'.contains(char)) return false;
    if (i + 1 < text.length && text[i + 1] != ' ') {
      // A citation marker sits between the stop and the next sentence, so the
      // stop is still the end of one. Without this the growth reads straight
      // through into the following sentence.
      final after = text.substring(i + 1, math.min(i + 14, text.length));
      if (!_citationMarker.hasMatch(after)) return false;
    }
    if (char == '.') {
      if (i > 0 && RegExp(r'\d').hasMatch(text[i - 1])) return false;
      // "(Fig. 97.3)" sits in the middle of a sentence, not at the end of one.
      final word = RegExp(r'([a-z]+)$').firstMatch(text.substring(0, i));
      if (word != null && _abbreviations.contains(word.group(1))) return false;
    }
    return true;
  }

  List<QuizHighlight> _marks(int start, int stop) {
    final marks = <QuizHighlight>[];
    for (var i = 0; i < lines.length && marks.length < 8; i++) {
      final length = _ends[i] - _starts[i];
      if (length <= 0) continue;
      final from = math.max(start, _starts[i]);
      final to = math.min(stop, _ends[i]);
      if (to <= from) continue;
      final measured = _measure(i, from - _starts[i], to - _starts[i]);
      marks.add(
        measured ??
            _clip(
              lines[i],
              (from - _starts[i]) / length,
              (to - _starts[i]) / length,
            ),
      );
    }
    return marks;
  }

  /// The exact box of the matched glyphs on line [i].
  ///
  /// Estimating it from the fraction of the line the match covers assumes
  /// every character is the same width, which no book sets type in — the mark
  /// then starts a word or two off. Where the glyph boxes are known, this
  /// measures instead of guessing.
  QuizHighlight? _measure(int i, int from, int to) {
    final chars = lines[i].chars;
    final sources = _sources[i];
    if (chars.isEmpty || sources.isEmpty) return null;
    if (from < 0 || to > sources.length || to <= from) return null;

    double? left, right, top, bottom;
    for (var at = from; at < to; at++) {
      final source = sources[at];
      if (source < 0 || source >= chars.length) continue;
      final box = chars[source];
      left = left == null ? box.x : math.min(left, box.x);
      right = right == null ? box.right : math.max(right, box.right);
      top = top == null ? box.y : math.min(top, box.y);
      bottom = bottom == null ? box.y + box.h : math.max(bottom, box.y + box.h);
    }
    if (left == null || right == null || top == null || bottom == null) {
      return null;
    }
    if (right <= left || bottom <= top) return null;

    const pad = 0.004;
    final x = (left - pad).clamp(0.0, 1.0);
    final height = bottom - top;
    final y = (top - height * 0.12).clamp(0.0, 1.0);
    return QuizHighlight(
      x: x,
      y: y,
      w: math.max((right + pad).clamp(0.0, 1.0) - x, 0.01),
      h: math.max(math.min(height * 1.24, 1.0 - y), 0.008),
      precise: true,
    );
  }
}

/// A stroke over the [from]–[to] slice of one line, padded a little so the
/// ink covers the type rather than sitting flush against it.
QuizHighlight _clip(PdfTextLine line, double from, double to) {
  const pad = 0.004;
  final left = (line.x + from.clamp(0.0, 1.0) * line.w - pad).clamp(0.0, 1.0);
  final right = (line.x + to.clamp(0.0, 1.0) * line.w + pad).clamp(0.0, 1.0);
  final top = (line.y - line.h * 0.12).clamp(0.0, 1.0);
  final height = math.min(line.h * 1.24, 1.0 - top);
  return QuizHighlight(
    x: left,
    y: top,
    w: math.max(right - left, 0.01),
    h: math.max(height, 0.008),
    precise: true,
  );
}

/// The page number printed on the page itself, read from the running head or
/// foot — a textbook's folio and its position in the file are rarely the same
/// number, and a citation can mean either.
int? printedFolio(List<PdfTextLine> lines) {
  for (final line in lines) {
    if (line.y > 0.10 && line.y < 0.90) continue;
    final text = line.text.trim();
    if (text.length > 60) continue;
    final match = RegExp(r'^(\d{1,4})\b').firstMatch(text) ??
        RegExp(r'\b(\d{1,4})$').firstMatch(text);
    if (match == null) continue;
    final folio = int.tryParse(match.group(1)!);
    if (folio != null && folio > 0 && folio < 5000) return folio;
  }
  return null;
}
