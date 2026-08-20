import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:notably/core/db/database.dart';
import 'package:notably/core/models/enums.dart';
import 'package:notably/core/models/outline_entry.dart';
import 'package:notably/features/editor/quiz/quiz_history.dart';
import 'package:notably/features/editor/quiz/quiz_history_repository.dart';
import 'package:notably/features/editor/quiz/quiz_models.dart';
import 'package:uuid/uuid.dart';

void main() {
  QuizHistoryRecord _record({
    required String id,
    required String familyId,
    required int percent,
    required DateTime at,
  }) {
    final count = 25;
    final correct = (percent * count / 100).round();
    return QuizHistoryRecord(
      id: id,
      documentId: 'doc',
      familyId: familyId,
      title: 'Cell Structure quiz',
      sourceLabel: 'All pages',
      questionCount: count,
      correctCount: correct,
      durationMs: 552000,
      completedAt: at,
      questions: const [],
      answers: const [],
    );
  }

  test('QuizQuestion round-trips through JSON including highlight', () {
    const q = QuizQuestion(
      kind: QuizKind.multipleChoice,
      prompt: 'Where is ATP generated in animal cells?',
      choices: ['Mitochondria', 'Lysosomes', 'Nucleus', 'Golgi'],
      correctIndex: 0,
      acceptedAnswer: 'Mitochondria',
      explanation: 'Mitochondria generate ATP. See page 15.',
      pageIndex: 14,
      highlight: QuizHighlight(x: 0.12, y: 0.4, w: 0.52, h: 0.022),
    );
    final restored = QuizQuestion.fromJson(q.toJson());
    expect(restored.prompt, q.prompt);
    expect(restored.highlight?.h, closeTo(0.022, 0.0001));
  });

  test('groupQuizHistory keeps families newest-first', () {
    final day = DateTime(2026, 8, 19);
    final records = [
      _record(id: 'c', familyId: 'a', percent: 96, at: day),
      _record(id: 'b', familyId: 'a', percent: 80, at: day.subtract(const Duration(days: 2))),
      _record(id: 'd', familyId: 'x', percent: 56, at: day.subtract(const Duration(days: 5))),
    ];
    final groups = groupQuizHistory(records);
    expect(groups, hasLength(2));
    expect(groups.first.latest.percent, 96);
    expect(groups.first.scoreTrail, [80, 96]);
    expect(groups.last.latest.percent, 56);
  });

  test('quizDayStreak counts consecutive local days', () {
    final now = DateTime(2026, 8, 19, 18);
    expect(
      quizDayStreak([
        DateTime(2026, 8, 19, 9),
        DateTime(2026, 8, 18, 21),
        DateTime(2026, 8, 17, 8),
      ], now: now),
      3,
    );
    expect(
      quizDayStreak([DateTime(2026, 8, 16)], now: now),
      0,
    );
    expect(
      quizDayStreak([DateTime(2026, 8, 18, 10)], now: now),
      1,
    );
  });

  test('formatQuizClock pads seconds', () {
    expect(formatQuizClock(const Duration(minutes: 9, seconds: 12)), '9:12');
    expect(formatQuizClock(const Duration(seconds: 8)), '0:08');
  });

  group('QuizHistoryRepository delete', () {
    late AppDatabase db;
    late QuizHistoryRepository repo;

    const questions = [
      QuizQuestion(
        kind: QuizKind.multipleChoice,
        prompt: 'Q?',
        choices: ['A', 'B'],
        correctIndex: 0,
        acceptedAnswer: 'A',
        explanation: '',
        pageIndex: 0,
      ),
    ];

    setUp(() async {
      db = AppDatabase(NativeDatabase.memory());
      repo = QuizHistoryRepository(db, const Uuid());
      await db.into(db.documents).insert(DocumentsCompanion.insert(
            id: 'doc',
            type: DocumentType.notebook,
          ));
      await db.into(db.documents).insert(DocumentsCompanion.insert(
            id: 'other',
            type: DocumentType.notebook,
          ));
    });

    tearDown(() async {
      await db.close();
    });

    Future<void> save({
      required String documentId,
      required String familyId,
    }) {
      return repo.saveAttempt(
        documentId: documentId,
        familyId: familyId,
        title: 'Cell quiz',
        sourceLabel: 'All pages',
        questions: questions,
        answers: const {0: QuizAnswer(choiceIndex: 0, written: null, correct: true)},
        duration: const Duration(seconds: 12),
      );
    }

    test('deleteFamily removes one generated quiz and keeps others', () async {
      await save(documentId: 'doc', familyId: 'a');
      await save(documentId: 'doc', familyId: 'a');
      await save(documentId: 'doc', familyId: 'b');
      await repo.deleteFamily(documentId: 'doc', familyId: 'a');
      final left = await repo.watchForDocument('doc').first;
      expect(left, hasLength(1));
      expect(left.single.familyId, 'b');
    });

    test('deleteAllForDocument only clears that document', () async {
      await save(documentId: 'doc', familyId: 'a');
      await save(documentId: 'other', familyId: 'z');
      await repo.deleteAllForDocument('doc');
      expect(await repo.watchForDocument('doc').first, isEmpty);
      expect(await repo.watchForDocument('other').first, hasLength(1));
    });

    test('saveGenerated lists the quiz before it is taken', () async {
      final id = await repo.saveGenerated(
        documentId: 'doc',
        familyId: 'g',
        title: 'Cell quiz',
        sourceLabel: 'All pages',
        questions: questions,
      );
      final rows = await repo.watchForDocument('doc').first;
      expect(rows, hasLength(1));
      expect(rows.single.id, id);
      expect(rows.single.completed, isFalse);
      expect(rows.single.correctCount, 0);

      await repo.completeAttempt(
        id: id,
        questions: questions,
        answers: const {
          0: QuizAnswer(choiceIndex: 0, written: null, correct: true),
        },
        duration: const Duration(seconds: 9),
      );
      final done = await repo.watchForDocument('doc').first;
      expect(done.single.completed, isTrue);
      expect(done.single.correctCount, 1);
    });
  });

  test('quizHistoryStats ignores quizzes that were never taken', () {
    final day = DateTime(2026, 8, 19);
    final stats = quizHistoryStats([
      _record(id: 'a', familyId: 'a', percent: 80, at: day),
      QuizHistoryRecord(
        id: 'b',
        documentId: 'doc',
        familyId: 'b',
        title: 'Untaken',
        sourceLabel: 'All pages',
        questionCount: 10,
        correctCount: 0,
        durationMs: 0,
        completedAt: day,
        questions: const [],
        answers: const [],
        completed: false,
      ),
    ]);
    expect(stats.taken, 1);
    expect(stats.averagePercent, 80);
  });

  test('quizHeadline prefers chapter over the book title', () {
    final outline = OutlineNode.nest(const [
      OutlineEntry(title: 'Ch 1 Cells', pageIndex: 0, depth: 0),
      OutlineEntry(title: 'Ch 2 Tissue', pageIndex: 20, depth: 0),
    ]);
    const q = QuizQuestion(
      kind: QuizKind.multipleChoice,
      prompt: 'Q?',
      choices: ['A', 'B'],
      correctIndex: 0,
      acceptedAnswer: 'A',
      explanation: '',
      pageIndex: 4,
    );
    final record = QuizHistoryRecord(
      id: '1',
      documentId: 'doc',
      familyId: 'f',
      title: 'textbook quiz',
      sourceLabel: 'All pages',
      questionCount: 1,
      correctCount: 0,
      durationMs: 0,
      completedAt: DateTime(2026, 8, 20),
      questions: const [q],
      answers: const [],
      completed: false,
    );
    expect(
      quizHeadline(record, bookTitle: 'textbook', outline: outline, pageCount: 40),
      'Ch 1 Cells',
    );
  });
}
