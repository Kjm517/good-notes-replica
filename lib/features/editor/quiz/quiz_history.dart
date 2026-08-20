import '../../../core/models/outline_entry.dart';
import 'quiz_models.dart';

/// One saved quiz run, with questions so it can be reviewed or retaken.
class QuizHistoryRecord {
  const QuizHistoryRecord({
    required this.id,
    required this.documentId,
    required this.familyId,
    required this.title,
    required this.sourceLabel,
    required this.questionCount,
    required this.correctCount,
    required this.durationMs,
    required this.completedAt,
    required this.questions,
    required this.answers,
    this.completed = true,
  });

  final String id;
  final String documentId;
  final String familyId;
  final String title;
  final String sourceLabel;
  final int questionCount;
  final int correctCount;
  final int durationMs;
  final DateTime completedAt;
  final List<QuizQuestion> questions;
  final List<QuizAnswer?> answers;

  /// False when the quiz was generated but never finished.
  final bool completed;

  int get percent =>
      !completed || questionCount == 0
          ? 0
          : (correctCount * 100 / questionCount).round();

  int get missedCount => questionCount - correctCount;

  Duration get duration => Duration(milliseconds: durationMs);

  List<QuizQuestion> get missedQuestions => [
        for (var i = 0; i < questions.length; i++)
          if (answers.elementAtOrNull(i)?.correct != true) questions[i],
      ];
}

/// Retakes of the same generated set, newest first.
class QuizHistoryGroup {
  const QuizHistoryGroup({required this.attempts});

  final List<QuizHistoryRecord> attempts;

  QuizHistoryRecord get latest => attempts.first;

  /// Oldest → newest percents for the "Attempts 62% → 80%" strip.
  List<int> get scoreTrail => [
        for (final a in attempts.reversed)
          if (a.completed) a.percent,
      ];
}

class QuizHistoryStats {
  const QuizHistoryStats({
    required this.taken,
    required this.averagePercent,
    required this.dayStreak,
  });

  final int taken;
  final int averagePercent;
  final int dayStreak;

  static const empty = QuizHistoryStats(
    taken: 0,
    averagePercent: 0,
    dayStreak: 0,
  );
}

/// Groups [records] (newest first) by [QuizHistoryRecord.familyId].
List<QuizHistoryGroup> groupQuizHistory(List<QuizHistoryRecord> records) {
  final order = <String>[];
  final buckets = <String, List<QuizHistoryRecord>>{};
  for (final record in records) {
    final bucket = buckets.putIfAbsent(record.familyId, () {
      order.add(record.familyId);
      return <QuizHistoryRecord>[];
    });
    bucket.add(record);
  }
  return [
    for (final id in order) QuizHistoryGroup(attempts: buckets[id]!),
  ];
}

QuizHistoryStats quizHistoryStats(
  List<QuizHistoryRecord> records, {
  DateTime? now,
}) {
  final done = [for (final r in records) if (r.completed) r];
  if (done.isEmpty) return QuizHistoryStats.empty;
  final sum = done.fold<int>(0, (n, r) => n + r.percent);
  return QuizHistoryStats(
    taken: done.length,
    averagePercent: (sum / done.length).round(),
    dayStreak: quizDayStreak(
      done.map((r) => r.completedAt),
      now: now,
    ),
  );
}

/// Consecutive local-calendar days with at least one quiz, ending today
/// (or yesterday if nothing has been taken yet today).
int quizDayStreak(Iterable<DateTime> stamps, {DateTime? now}) {
  final today = now ?? DateTime.now();
  final dates = {
    for (final s in stamps) DateTime(s.year, s.month, s.day),
  };
  if (dates.isEmpty) return 0;
  var cursor = DateTime(today.year, today.month, today.day);
  if (!dates.contains(cursor)) {
    cursor = cursor.subtract(const Duration(days: 1));
    if (!dates.contains(cursor)) return 0;
  }
  var streak = 0;
  while (dates.contains(cursor)) {
    streak++;
    cursor = cursor.subtract(const Duration(days: 1));
  }
  return streak;
}

String formatQuizClock(Duration duration) {
  final total = duration.inSeconds.clamp(0, 99 * 60 + 59);
  final m = total ~/ 60;
  final s = total % 60;
  return '$m:${s.toString().padLeft(2, '0')}';
}

/// Chapter-style name for a saved quiz. Falls back to [bookTitle] when the
/// document has no outline (notebooks, scans).
String quizHeadline(
  QuizHistoryRecord record, {
  required String bookTitle,
  List<OutlineNode> outline = const [],
  int pageCount = 0,
}) {
  return quizHeadlineFrom(
    storedTitle: record.title,
    questions: record.questions,
    bookTitle: bookTitle,
    outline: outline,
    pageCount: pageCount,
  );
}

String quizHeadlineFrom({
  required String storedTitle,
  required List<QuizQuestion> questions,
  required String bookTitle,
  required List<OutlineNode> outline,
  required int pageCount,
  QuizSource? source,
}) {
  if (source != null) {
    final fromSource = headlineFromSource(source, outline);
    if (fromSource != null) return fromSource;
  }
  final stored = stripQuizSuffix(storedTitle.trim());
  if (stored.isNotEmpty && !isGenericQuizTitle(stored, bookTitle)) {
    return stored;
  }
  return headlineFromQuestions(
        questions,
        outline: outline,
        pageCount: pageCount,
      ) ??
      (stored.isNotEmpty ? stored : bookTitle);
}

String? headlineFromSource(QuizSource source, List<OutlineNode> outline) {
  if (source.mode != QuizSourceMode.sections || source.sectionIds.isEmpty) {
    return null;
  }
  final nodes = [
    for (final id in source.sectionIds) OutlineNode.find(outline, id),
  ].whereType<OutlineNode>().toList();
  if (nodes.isEmpty) return null;
  if (nodes.length == 1) {
    final title = nodes.first.title.trim();
    return title.isEmpty ? null : title;
  }
  return joinChapterTitles([
    for (final node in nodes)
      OutlineNode.chapterOf(node, outline).title.trim(),
  ]);
}

String? headlineFromQuestions(
  List<QuizQuestion> questions, {
  required List<OutlineNode> outline,
  required int pageCount,
}) {
  if (outline.isEmpty || questions.isEmpty) return null;
  var pages = pageCount;
  if (pages <= 0) {
    pages = 1;
    for (final q in questions) {
      if (q.pageIndex + 1 > pages) pages = q.pageIndex + 1;
    }
  }
  return joinChapterTitles([
    for (final q in questions)
      OutlineNode.chapterForPage(
            outline,
            q.pageIndex,
            pageCount: pages,
          )?.title.trim() ??
          '',
  ]);
}

String? joinChapterTitles(Iterable<String> raw) {
  final seen = <String>{};
  final titles = <String>[];
  for (final title in raw) {
    final t = title.trim();
    if (t.isEmpty || !seen.add(t.toLowerCase())) continue;
    titles.add(t);
  }
  if (titles.isEmpty) return null;
  if (titles.length == 1) return titles.first;
  if (titles.length == 2) return '${titles[0]} · ${titles[1]}';
  return '${titles.first} +${titles.length - 1} more';
}

bool isGenericQuizTitle(String title, String bookTitle) {
  final t = title.trim().toLowerCase();
  final b = bookTitle.trim().toLowerCase();
  if (t.isEmpty || t == 'quiz') return true;
  if (b.isEmpty) return false;
  return t == b || t == '$b quiz';
}

String stripQuizSuffix(String title) {
  const suffix = ' quiz';
  if (title.length > suffix.length &&
      title.toLowerCase().endsWith(suffix)) {
    return title.substring(0, title.length - suffix.length).trim();
  }
  return title;
}
