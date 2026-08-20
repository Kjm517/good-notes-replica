/// Config and records for quizzes generated from the opened file
/// (PDF, photos, scans, or slides imported as images).
library;

import 'dart:math' as math;

import '../../../core/models/outline_entry.dart';

enum QuizKind { multipleChoice, trueFalse, shortAnswer }

enum QuizDifficulty { easy, medium, hard }

enum QuizTimerMode { off, seconds30, seconds60, seconds90, full }

class QuizLength {
  const QuizLength({
    required this.count,
    required this.label,
    required this.hint,
  });

  final int count;
  final String label;
  final String hint;
}

const List<QuizLength> kQuizLengths = [
  QuizLength(count: 20, label: 'Quick', hint: '~10 min'),
  QuizLength(count: 25, label: 'Balanced', hint: '~13 min'),
  QuizLength(count: 50, label: 'Thorough', hint: '~26 min'),
  QuizLength(count: 100, label: 'Exam prep', hint: '~52 min'),
];

class QuizConfig {
  const QuizConfig({
    required this.count,
    required this.kinds,
    required this.difficulty,
    required this.timer,
    this.source = const QuizSource(),
  });

  final int count;
  final Set<QuizKind> kinds;
  final QuizDifficulty difficulty;
  final QuizTimerMode timer;
  final QuizSource source;

  static const defaults = QuizConfig(
    count: 25,
    kinds: {QuizKind.multipleChoice, QuizKind.trueFalse},
    difficulty: QuizDifficulty.medium,
    timer: QuizTimerMode.off,
  );

  QuizConfig copyWith({
    int? count,
    Set<QuizKind>? kinds,
    QuizDifficulty? difficulty,
    QuizTimerMode? timer,
    QuizSource? source,
  }) =>
      QuizConfig(
        count: count ?? this.count,
        kinds: kinds ?? this.kinds,
        difficulty: difficulty ?? this.difficulty,
        timer: timer ?? this.timer,
        source: source ?? this.source,
      );

  Duration? get perQuestionLimit => switch (timer) {
        QuizTimerMode.off || QuizTimerMode.full => null,
        QuizTimerMode.seconds30 => const Duration(seconds: 30),
        QuizTimerMode.seconds60 => const Duration(seconds: 60),
        QuizTimerMode.seconds90 => const Duration(seconds: 90),
      };

  /// Whole-quiz countdown used by [QuizTimerMode.full].
  Duration? fullLimitFor(int questionCount) {
    if (timer != QuizTimerMode.full) return null;
    return Duration(seconds: questionCount * 32);
  }

  Map<String, dynamic> toJson() => {
        'count': count,
        'kinds': [for (final kind in kinds) kind.name],
        'difficulty': difficulty.name,
        'timer': timer.name,
        'source': source.toJson(),
      };

  factory QuizConfig.fromJson(Map<String, dynamic> json) {
    final kindsRaw = json['kinds'];
    final kinds = <QuizKind>{
      if (kindsRaw is List)
        for (final item in kindsRaw)
          if (item is String)
            QuizKind.values.firstWhere(
              (k) => k.name == item,
              orElse: () => QuizKind.multipleChoice,
            ),
    };
    return QuizConfig(
      count: (json['count'] as num?)?.toInt() ?? defaults.count,
      kinds: kinds.isEmpty ? defaults.kinds : kinds,
      difficulty: QuizDifficulty.values.firstWhere(
        (d) => d.name == json['difficulty'],
        orElse: () => QuizDifficulty.medium,
      ),
      timer: QuizTimerMode.values.firstWhere(
        (t) => t.name == json['timer'],
        orElse: () => QuizTimerMode.off,
      ),
      source: json['source'] is Map
          ? QuizSource.fromJson(
              Map<String, dynamic>.from(json['source'] as Map),
            )
          : const QuizSource(),
    );
  }
}

/// Which pages feed quiz generation: the whole file, outline sections, or a
/// numeric range (notebooks / image decks with no TOC).
enum QuizSourceMode { all, sections, pageRange }

class QuizSource {
  const QuizSource({
    this.mode = QuizSourceMode.all,
    this.sectionIds = const {},
    this.startPage,
    this.endPage,
  });

  final QuizSourceMode mode;

  /// [OutlineNode.id]s when [mode] is [QuizSourceMode.sections].
  final Set<String> sectionIds;

  /// Inclusive 0-based indices when [mode] is [QuizSourceMode.pageRange].
  final int? startPage;
  final int? endPage;

  Set<int>? pageFilter({
    required List<OutlineNode> outline,
    required int pageCount,
  }) {
    switch (mode) {
      case QuizSourceMode.all:
        return null;
      case QuizSourceMode.sections:
        return OutlineNode.pagesForIds(
          sectionIds,
          roots: outline,
          pageCount: pageCount,
        );
      case QuizSourceMode.pageRange:
        final last = math.max(0, pageCount - 1);
        final start = (startPage ?? 0).clamp(0, last).toInt();
        final end = (endPage ?? last).clamp(start, last).toInt();
        return {for (var i = start; i <= end; i++) i};
    }
  }

  String label({
    required List<OutlineNode> outline,
    required int pageCount,
  }) {
    switch (mode) {
      case QuizSourceMode.all:
        return 'All pages · $pageCount in this document';
      case QuizSourceMode.sections:
        if (sectionIds.isEmpty) {
          return 'No sections selected';
        }
        final pages = pageFilter(outline: outline, pageCount: pageCount)!;
        if (sectionIds.length == 1) {
          final node = OutlineNode.find(outline, sectionIds.first);
          final title = node?.title ?? 'Section';
          return '$title · ${pages.length} pages';
        }
        return '${sectionIds.length} sections · ${pages.length} pages';
      case QuizSourceMode.pageRange:
        final start = (startPage ?? 0) + 1;
        final end = (endPage ?? pageCount - 1) + 1;
        return 'Pages $start–$end';
    }
  }

  Map<String, dynamic> toJson() => {
        'mode': mode.name,
        'sectionIds': sectionIds.toList(),
        'startPage': startPage,
        'endPage': endPage,
      };

  factory QuizSource.fromJson(Map<String, dynamic> json) {
    final idsRaw = json['sectionIds'];
    return QuizSource(
      mode: QuizSourceMode.values.firstWhere(
        (m) => m.name == json['mode'],
        orElse: () => QuizSourceMode.all,
      ),
      sectionIds: {
        if (idsRaw is List)
          for (final id in idsRaw)
            if (id is String) id,
      },
      startPage: (json['startPage'] as num?)?.toInt(),
      endPage: (json['endPage'] as num?)?.toInt(),
    );
  }
}

class SourcePassage {
  const SourcePassage({required this.pageIndex, required this.sentence});

  /// Zero-based page in the document.
  final int pageIndex;
  final String sentence;
}

class QuizQuestion {
  const QuizQuestion({
    required this.kind,
    required this.prompt,
    required this.choices,
    required this.correctIndex,
    required this.acceptedAnswer,
    required this.explanation,
    required this.pageIndex,
    this.sourceQuote = '',
    this.highlight,
    this.location,
  });

  final QuizKind kind;
  final String prompt;

  /// Empty for short-answer items.
  final List<String> choices;
  final int correctIndex;
  final String acceptedAnswer;
  final String explanation;
  final int pageIndex;

  /// The sentence from the page that states the answer, in the book's own
  /// words. Searched for verbatim, and ignored when it does not match — a
  /// quote that cannot be found in the file is treated as if it were absent.
  final String sourceQuote;

  /// Where on the page the answer lives, as 0–1 fractions of width/height.
  final QuizHighlight? highlight;

  /// Where the answer was actually found, once the source has been read.
  /// Kept on the question so the lookup runs once per answer and travels with
  /// the attempt into history.
  final QuizAnswerLocation? location;

  Map<String, dynamic> toJson() => {
        'kind': kind.name,
        'prompt': prompt,
        'choices': choices,
        'correctIndex': correctIndex,
        'acceptedAnswer': acceptedAnswer,
        'explanation': explanation,
        'pageIndex': pageIndex,
        if (sourceQuote.isNotEmpty) 'sourceQuote': sourceQuote,
        'highlight': highlight?.toJson(),
        if (location != null) 'location': location!.toJson(),
      };

  factory QuizQuestion.fromJson(Map<String, dynamic> json) {
    final kindName = json['kind'] as String? ?? 'multipleChoice';
    return QuizQuestion(
      kind: QuizKind.values.firstWhere(
        (k) => k.name == kindName,
        orElse: () => QuizKind.multipleChoice,
      ),
      prompt: json['prompt'] as String? ?? '',
      choices: (json['choices'] as List?)?.map((e) => e.toString()).toList() ??
          const [],
      correctIndex: (json['correctIndex'] as num?)?.toInt() ?? 0,
      acceptedAnswer: json['acceptedAnswer'] as String? ?? '',
      explanation: json['explanation'] as String? ?? '',
      pageIndex: (json['pageIndex'] as num?)?.toInt() ?? 0,
      sourceQuote: json['sourceQuote'] as String? ?? '',
      highlight: QuizHighlight.tryParse(json['highlight']),
      location: QuizAnswerLocation.tryParse(json['location']),
    );
  }

  /// What the source preview should hunt for on the cited page.
  QuizSourceTarget get sourceTarget => QuizSourceTarget(
        // A true/false item's accepted answer is "True" or "False", which no
        // page states in any useful sense. What the student is being shown is
        // the claim, so that is what the highlighter should go and find —
        // whether the book confirms it or contradicts it.
        answer: kind == QuizKind.trueFalse ? prompt : acceptedAnswer,
        prompt: prompt,
        quote: sourceQuote,
        hint: highlight,
        sourcePageIndex: pageIndex,
        location: location,
      );

  /// Puts the key in a random slot so Gemini's habit of always using A is undone.
  QuizQuestion withShuffledChoices(math.Random random) {
    if (choices.length < 2) return this;
    final key = (correctIndex >= 0 && correctIndex < choices.length)
        ? choices[correctIndex]
        : acceptedAnswer;
    final next = [...choices]..shuffle(random);
    final index = next.indexOf(key);
    return QuizQuestion(
      kind: kind,
      prompt: prompt,
      choices: next,
      correctIndex: index < 0 ? 0 : index,
      acceptedAnswer: acceptedAnswer.isEmpty ? key : acceptedAnswer,
      explanation: explanation,
      pageIndex: pageIndex,
      sourceQuote: sourceQuote,
      highlight: highlight,
      location: location,
    );
  }

  QuizQuestion copyWith({
    List<String>? choices,
    int? correctIndex,
    String? acceptedAnswer,
    String? explanation,
    int? pageIndex,
    QuizHighlight? highlight,
    bool clearHighlight = false,
    QuizAnswerLocation? location,
  }) =>
      QuizQuestion(
        kind: kind,
        prompt: prompt,
        choices: choices ?? this.choices,
        correctIndex: correctIndex ?? this.correctIndex,
        acceptedAnswer: acceptedAnswer ?? this.acceptedAnswer,
        explanation: explanation ?? this.explanation,
        pageIndex: pageIndex ?? this.pageIndex,
        sourceQuote: sourceQuote,
        highlight: clearHighlight ? null : (highlight ?? this.highlight),
        location: location ?? this.location,
      );
}

/// Shuffles item order and each question's choices for a retake.
List<QuizQuestion> reshuffleQuiz(
  List<QuizQuestion> questions, {
  math.Random? random,
}) {
  final rng = random ?? math.Random();
  final next = [
    for (final question in questions) question.withShuffledChoices(rng),
  ]..shuffle(rng);
  return next;
}

/// What the source preview should hunt for on the page.
class QuizSourceTarget {
  const QuizSourceTarget({
    required this.answer,
    this.prompt = '',
    this.hint,
    this.quote = '',
    this.sourcePageIndex,
    this.location,
  });

  final String answer;
  final String prompt;

  /// The sentence the source is said to state, to be found verbatim.
  final String quote;

  /// The page the question itself claims the answer is on. Gemini's prose
  /// citation and this field disagree often enough that both are checked.
  final int? sourcePageIndex;

  /// The box Gemini guessed (or the coarse text-offset estimate), used only
  /// when the page's own text cannot be read.
  final QuizHighlight? hint;

  /// A resolution already made for this answer — the preview paints it
  /// straight away instead of reading the PDF again.
  final QuizAnswerLocation? location;

  bool get isEmpty => answer.trim().isEmpty && prompt.trim().isEmpty;
}

/// The outcome of reading the source: which page states the answer, and the
/// strokes over it. Stored on the question so it is computed once.
class QuizAnswerLocation {
  const QuizAnswerLocation({
    required this.pageIndex,
    required this.marks,
    this.exact = false,
  });

  final int pageIndex;
  final List<QuizHighlight> marks;

  /// The answer's own wording was on the page, not just its key terms.
  final bool exact;

  Map<String, dynamic> toJson() => {
        'pageIndex': pageIndex,
        'marks': [for (final mark in marks) mark.toJson()],
        if (exact) 'exact': true,
      };

  static QuizAnswerLocation? tryParse(Object? raw) {
    if (raw is! Map) return null;
    final map = Map<dynamic, dynamic>.from(raw);
    final page = (map['pageIndex'] as num?)?.toInt();
    if (page == null || page < 0) return null;
    final marks = <QuizHighlight>[];
    final rawMarks = map['marks'];
    if (rawMarks is List) {
      for (final item in rawMarks) {
        final mark = QuizHighlight.tryParse(item);
        if (mark != null) marks.add(mark);
      }
    }
    if (marks.isEmpty) return null;
    return QuizAnswerLocation(
      pageIndex: page,
      marks: marks,
      exact: map['exact'] == true,
    );
  }
}

/// A rectangle on a page image, in 0–1 coordinates (left, top, width, height).
class QuizHighlight {
  const QuizHighlight({
    required this.x,
    required this.y,
    required this.w,
    required this.h,
    this.precise = false,
  });

  final double x;
  final double y;
  final double w;
  final double h;

  /// True when the box came from the PDF's own text geometry, so it already
  /// sits on one line in one column and must not be re-guessed.
  final bool precise;

  Map<String, dynamic> toJson() => {
        'x': x,
        'y': y,
        'w': w,
        'h': h,
        if (precise) 'precise': true,
      };

  /// One highlighter stroke on a single column of body type.
  ///
  /// Gemini often returns a paragraph box that spans both columns of a
  /// textbook page. This snaps that to one line in one column so the overlay
  /// does not paint across the gutter or sit under the baseline.
  QuizHighlight asInkStroke() {
    if (precise) return this;
    var x = this.x;
    var y = this.y;
    var w = this.w;
    var h = this.h;

    const gutter = 0.50;
    const colGap = 0.028;
    final right = x + w;
    final crossesGutter = x < gutter - 0.03 && right > gutter + 0.03;
    if (crossesGutter && w > 0.55) {
      if (x + w / 2 >= gutter && x > 0.18) {
        x = gutter + colGap;
        w = math.min(right, 0.96) - x;
      } else {
        w = (gutter - colGap) - x;
      }
    }
    w = w.clamp(0.10, 0.46);
    if (x + w > 0.98) w = 0.98 - x;

    const line = 0.019;
    if (h > line * 1.35) {
      y = y + (h - line) * 0.08;
      h = line;
    } else {
      y -= line * 0.18;
      h = math.max(h, line);
    }
    y = y.clamp(0.0, 0.97);
    h = h.clamp(0.016, 1.0 - y);
    return QuizHighlight(x: x, y: y, w: w, h: h);
  }

  /// Parses Gemini `{x,y,w,h}`, `{left,top,width,height}`, or `[x,y,w,h]`.
  /// Values above 1.5 are treated as percents. Whole-page boxes are dropped.
  static QuizHighlight? tryParse(Object? raw) {
    if (raw is List && raw.length >= 4) {
      final nums = [
        for (final item in raw.take(4))
          if (item is num) item.toDouble(),
      ];
      if (nums.length == 4) {
        return tryParse({'x': nums[0], 'y': nums[1], 'w': nums[2], 'h': nums[3]});
      }
      return null;
    }
    if (raw is! Map) return null;
    final map = Map<dynamic, dynamic>.from(raw);
    double? numAt(List<String> keys) {
      for (final key in keys) {
        final v = map[key];
        if (v is num) return v.toDouble();
      }
      return null;
    }

    final precise = map['precise'] == true;
    var x = numAt(['x', 'left']);
    var y = numAt(['y', 'top']);
    var w = numAt(['w', 'width']);
    var h = numAt(['h', 'height']);
    if (x == null || y == null || w == null || h == null) return null;
    if (x > 1.5 || y > 1.5 || w > 1.5 || h > 1.5) {
      x /= 100;
      y /= 100;
      w /= 100;
      h /= 100;
    }
    x = x.clamp(0.0, 0.98);
    y = y.clamp(0.0, 0.98);
    w = w.clamp(0.03, 1.0 - x);
    h = h.clamp(0.012, 1.0 - y);
    if (w * h > 0.88) return null;
    return QuizHighlight(x: x, y: y, w: w, h: h, precise: precise);
  }
}

class QuizAnswer {
  const QuizAnswer({
    required this.choiceIndex,
    required this.written,
    required this.correct,
  });

  final int? choiceIndex;
  final String? written;
  final bool correct;

  Map<String, dynamic> toJson() => {
        'choiceIndex': choiceIndex,
        'written': written,
        'correct': correct,
      };

  factory QuizAnswer.fromJson(Map<String, dynamic> json) => QuizAnswer(
        choiceIndex: (json['choiceIndex'] as num?)?.toInt(),
        written: json['written'] as String?,
        correct: json['correct'] as bool? ?? false,
      );
}

/// A run of explanation text, optionally a 1-based page citation to tap.
class ExplanationSegment {
  const ExplanationSegment({required this.text, this.pageNumber});

  final String text;

  /// 1-based page number when this span is a "See page N" link.
  final int? pageNumber;
}

final _seePageRe = RegExp(r'See\s+pages?\s+(\d+)\.?', caseSensitive: false);

/// Splits an explanation so "See page 12" can be rendered as a link.
/// The page number the explanation cites first, as a zero-based index.
int? firstCitedPageIndex(String explanation) {
  for (final part in parseExplanationPageLinks(explanation)) {
    final number = part.pageNumber;
    if (number != null && number > 0) return number - 1;
  }
  return null;
}

List<ExplanationSegment> parseExplanationPageLinks(String explanation) {
  final text = explanation;
  if (text.isEmpty) return const [];
  final out = <ExplanationSegment>[];
  var start = 0;
  for (final match in _seePageRe.allMatches(text)) {
    if (match.start > start) {
      out.add(ExplanationSegment(text: text.substring(start, match.start)));
    }
    final n = int.tryParse(match.group(1) ?? '');
    out.add(ExplanationSegment(text: match.group(0)!, pageNumber: n));
    start = match.end;
  }
  if (start < text.length) {
    out.add(ExplanationSegment(text: text.substring(start)));
  }
  if (out.isEmpty) {
    out.add(ExplanationSegment(text: text));
  }
  return out;
}

/// Cap on pages sent to Gemini as images (payload + cost).
const int kMaxQuizImagePages = 12;

/// Evenly picks up to [max] page indices so a 25-question quiz doesn't wait
/// on a 900-page extract. First and last pages of the selection are kept so
/// chapter coverage stays spread across the range.
Set<int> samplePageIndices(Iterable<int> pages, int max) {
  final sorted = pages.toSet().toList()..sort();
  if (sorted.length <= max) return sorted.toSet();
  if (max <= 0) return {};
  if (max == 1) return {sorted.first};
  final out = <int>{};
  for (var i = 0; i < max; i++) {
    final idx = ((i * (sorted.length - 1)) / (max - 1)).round();
    out.add(sorted[idx]);
  }
  return out;
}
