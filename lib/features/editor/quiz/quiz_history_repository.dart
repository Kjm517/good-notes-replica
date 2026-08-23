import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../../core/db/database.dart';
import 'quiz_history.dart';
import 'quiz_models.dart';

class QuizHistoryRepository {
  QuizHistoryRepository(this._db, this._uuid);

  final AppDatabase _db;
  final Uuid _uuid;

  Stream<List<QuizHistoryRecord>> watchForDocument(String documentId) {
    final q = _db.select(_db.quizAttempts)
      ..where((t) => t.documentId.equals(documentId) & t.deletedAt.isNull())
      ..orderBy([(t) => OrderingTerm.desc(t.completedAt)]);
    return q.watch().map((rows) => [for (final row in rows) _fromRow(row)]);
  }

  /// All completed quiz attempts across every document, newest first.
  Stream<List<QuizHistoryRecord>> watchAllCompleted() {
    final q = _db.select(_db.quizAttempts)
      ..where((t) => t.deletedAt.isNull() & t.completed.equals(true))
      ..orderBy([(t) => OrderingTerm.desc(t.completedAt)]);
    return q.watch().map((rows) => [for (final row in rows) _fromRow(row)]);
  }

  Future<void> saveAttempt({
    required String documentId,
    required String familyId,
    required String title,
    required String sourceLabel,
    required List<QuizQuestion> questions,
    required Map<int, QuizAnswer> answers,
    required Duration duration,
  }) {
    final filled = [
      for (var i = 0; i < questions.length; i++)
        answers[i] ??
            const QuizAnswer(choiceIndex: null, written: null, correct: false),
    ];
    final correct = filled.where((a) => a.correct).length;
    return _db.into(_db.quizAttempts).insert(
          QuizAttemptsCompanion.insert(
            id: _uuid.v4(),
            documentId: documentId,
            familyId: familyId,
            title: title,
            sourceLabel: Value(sourceLabel),
            questionCount: questions.length,
            correctCount: correct,
            durationMs: Value(duration.inMilliseconds),
            questionsJson: jsonEncode([for (final q in questions) q.toJson()]),
            answersJson: jsonEncode([for (final a in filled) a.toJson()]),
            completedAt: Value(DateTime.now()),
            completed: const Value(true),
          ),
        );
  }

  /// Stores a generated question set before the user takes it.
  Future<String> saveGenerated({
    required String documentId,
    required String familyId,
    required String title,
    required String sourceLabel,
    required List<QuizQuestion> questions,
  }) async {
    final id = _uuid.v4();
    final unanswered = [
      for (var i = 0; i < questions.length; i++)
        const QuizAnswer(choiceIndex: null, written: null, correct: false),
    ];
    await _db.into(_db.quizAttempts).insert(
          QuizAttemptsCompanion.insert(
            id: id,
            documentId: documentId,
            familyId: familyId,
            title: title,
            sourceLabel: Value(sourceLabel),
            questionCount: questions.length,
            correctCount: 0,
            durationMs: const Value(0),
            questionsJson: jsonEncode([for (final q in questions) q.toJson()]),
            answersJson: jsonEncode([for (final a in unanswered) a.toJson()]),
            completedAt: Value(DateTime.now()),
            completed: const Value(false),
          ),
        );
    return id;
  }

  /// Marks a generated quiz as finished with the user's answers.
  Future<void> completeAttempt({
    required String id,
    required List<QuizQuestion> questions,
    required Map<int, QuizAnswer> answers,
    required Duration duration,
  }) {
    final filled = [
      for (var i = 0; i < questions.length; i++)
        answers[i] ??
            const QuizAnswer(choiceIndex: null, written: null, correct: false),
    ];
    final correct = filled.where((a) => a.correct).length;
    return (_db.update(_db.quizAttempts)..where((t) => t.id.equals(id))).write(
      QuizAttemptsCompanion(
        questionCount: Value(questions.length),
        correctCount: Value(correct),
        durationMs: Value(duration.inMilliseconds),
        questionsJson: Value(jsonEncode([for (final q in questions) q.toJson()])),
        answersJson: Value(jsonEncode([for (final a in filled) a.toJson()])),
        completed: const Value(true),
        completedAt: Value(DateTime.now()),
        // Without these the finished attempt stays on this device: it was
        // marked clean by whatever sync ran while the quiz was being taken.
        updatedAt: Value(DateTime.now()),
        dirty: const Value(true),
      ),
    );
  }

  /// Removes every attempt of one generated question set.
  ///
  /// A tombstone rather than a hard delete: sync would otherwise pull the row
  /// straight back from another device that had not heard about the deletion.
  Future<int> deleteFamily({
    required String documentId,
    required String familyId,
  }) {
    return (_db.update(_db.quizAttempts)
          ..where(
            (t) =>
                t.documentId.equals(documentId) &
                t.familyId.equals(familyId) &
                t.deletedAt.isNull(),
          ))
        .write(_tombstone());
  }

  /// Removes every saved quiz for [documentId].
  Future<int> deleteAllForDocument(String documentId) {
    return (_db.update(_db.quizAttempts)
          ..where((t) => t.documentId.equals(documentId) & t.deletedAt.isNull()))
        .write(_tombstone());
  }

  QuizAttemptsCompanion _tombstone() {
    final now = DateTime.now();
    return QuizAttemptsCompanion(
      deletedAt: Value(now),
      updatedAt: Value(now),
      dirty: const Value(true),
    );
  }

  QuizHistoryRecord _fromRow(QuizAttempt row) {
    final questionsRaw = jsonDecode(row.questionsJson);
    final answersRaw = jsonDecode(row.answersJson);
    final questions = <QuizQuestion>[
      if (questionsRaw is List)
        for (final item in questionsRaw)
          if (item is Map)
            QuizQuestion.fromJson(Map<String, dynamic>.from(item)),
    ];
    final answers = <QuizAnswer?>[
      if (answersRaw is List)
        for (final item in answersRaw)
          if (item is Map)
            QuizAnswer.fromJson(Map<String, dynamic>.from(item))
          else
            null,
    ];
    while (answers.length < questions.length) {
      answers.add(null);
    }
    return QuizHistoryRecord(
      id: row.id,
      documentId: row.documentId,
      familyId: row.familyId,
      title: row.title,
      sourceLabel: row.sourceLabel,
      questionCount: row.questionCount,
      correctCount: row.correctCount,
      durationMs: row.durationMs,
      completedAt: row.completedAt,
      questions: questions,
      answers: answers,
      completed: row.completed,
    );
  }
}
