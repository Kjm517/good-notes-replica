import 'dart:io';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:notably/features/editor/quiz/quiz_align.dart';
import 'package:notably/features/editor/quiz/quiz_generator.dart';
import 'package:notably/features/editor/quiz/quiz_models.dart';
import 'package:notably/features/editor/quiz/quiz_quality.dart';

/// A well-formed identification item, overridable per test.
QuizQuestion ident({
  String prompt = 'What is the marked structure?',
  List<String> choices = const [],
  String acceptedAnswer = 'Golgi apparatus',
  QuizHighlight? highlight =
      const QuizHighlight(x: 0.44, y: 0.31, w: 0.07, h: 0.06),
  String explanation =
      'The marked stack of flattened membrane sacs is the Golgi apparatus, '
      'which packages proteins into vesicles because they are bound for the '
      'cell surface. The rough ER beside it is studded with ribosomes '
      'instead. See page 14.',
}) =>
    QuizQuestion(
      kind: QuizKind.identification,
      prompt: prompt,
      choices: choices,
      correctIndex: 0,
      acceptedAnswer: acceptedAnswer,
      explanation: explanation,
      pageIndex: 13,
      highlight: highlight,
    );

void main() {
  setUpAll(() async {
    await loadQuizStopWords(
      contents: File(kQuizStopWordsAsset).readAsStringSync(),
    );
  });

  group('QuizKind', () {
    test('identification is answered by typing, like short answer', () {
      expect(QuizKind.identification.isWritten, isTrue);
      expect(QuizKind.shortAnswer.isWritten, isTrue);
      expect(QuizKind.multipleChoice.isWritten, isFalse);
      expect(QuizKind.trueFalse.isWritten, isFalse);
    });

    test('only identification needs the figure on screen', () {
      expect(QuizKind.identification.needsFigure, isTrue);
      for (final kind in QuizKind.values.where(
        (k) => k != QuizKind.identification,
      )) {
        expect(kind.needsFigure, isFalse, reason: '$kind');
      }
    });

    test('every kind has a label', () {
      for (final kind in QuizKind.values) {
        expect(kind.label, isNotEmpty, reason: '$kind');
      }
      expect(QuizKind.identification.label, 'Identification');
    });
  });

  group('identification quality gate', () {
    test('accepts a tight marker on a figure', () {
      expect(isExamStyleQuestion(ident()), isTrue);
    });

    test('is exempt from the unseen-figure rule that guards text kinds', () {
      // "the marked structure" is exactly the phrasing needsUnseenFigure
      // exists to reject — but here the student is looking at the figure, so
      // the rule must not apply.
      expect(needsUnseenFigure('What is the marked structure?'), isFalse);
      expect(
        isExamStyleQuestion(ident(prompt: 'Name the marked layer.')),
        isTrue,
      );
    });

    test('rejects an item with no marker — nothing to point at', () {
      expect(isExamStyleQuestion(ident(highlight: null)), isFalse);
    });

    test('rejects a marker covering most of the page', () {
      expect(
        isExamStyleQuestion(
          ident(
            highlight: const QuizHighlight(x: 0.1, y: 0.1, w: 0.8, h: 0.06),
          ),
        ),
        isFalse,
      );
      expect(
        isExamStyleQuestion(
          ident(
            highlight: const QuizHighlight(x: 0.1, y: 0.1, w: 0.06, h: 0.8),
          ),
        ),
        isFalse,
      );
    });

    test('rejects a prompt that gives the answer away', () {
      expect(
        isExamStyleQuestion(
          ident(prompt: 'Where is the Golgi apparatus marked?'),
        ),
        isFalse,
      );
    });

    test('rejects choices — identification is typed, not picked', () {
      expect(
        isExamStyleQuestion(ident(choices: const ['Golgi apparatus', 'Nucleus'])),
        isFalse,
      );
    });

    test('rejects an empty or generic answer', () {
      expect(isExamStyleQuestion(ident(acceptedAnswer: '')), isFalse);
      expect(isExamStyleQuestion(ident(acceptedAnswer: 'figure')), isFalse);
    });
  });

  group('serialisation', () {
    test('identification survives a JSON round trip', () {
      final restored = QuizQuestion.fromJson(ident().toJson());
      expect(restored.kind, QuizKind.identification);
      expect(restored.acceptedAnswer, 'Golgi apparatus');
      expect(restored.highlight, isNotNull);
      expect(restored.highlight!.w, closeTo(0.07, 1e-9));
    });

    test('an unknown kind still falls back rather than throwing', () {
      final json = ident().toJson()..['kind'] = 'somethingElse';
      expect(QuizQuestion.fromJson(json).kind, QuizKind.multipleChoice);
    });
  });

  group('offline generator', () {
    const passages = [
      SourcePassage(
        pageIndex: 13,
        sentence:
            'Ribosomes synthesise proteins from amino acids inside eukaryotic '
            'cells.',
      ),
      SourcePassage(
        pageIndex: 13,
        sentence:
            'The Golgi apparatus packages proteins for transport across the '
            'membrane.',
      ),
      SourcePassage(
        pageIndex: 14,
        sentence:
            'Mitochondria generate ATP through cellular respiration in animal '
            'cells.',
      ),
      SourcePassage(
        pageIndex: 15,
        sentence:
            'Lysosomes digest worn-out organelles using hydrolytic enzymes.',
      ),
      SourcePassage(
        pageIndex: 16,
        sentence:
            'The nucleus stores genetic material and directs cellular '
            'activity in eukaryotes.',
      ),
    ];

    test('never invents identification items without a figure to see', () {
      final questions = LocalQuizGenerator(random: Random(1)).generate(
        passages: passages,
        config: QuizConfig.defaults.copyWith(
          count: 6,
          kinds: {QuizKind.identification, QuizKind.multipleChoice},
        ),
      );
      expect(questions, isNotEmpty);
      expect(
        questions.every((q) => q.kind != QuizKind.identification),
        isTrue,
      );
    });

    test('asking for identification alone falls back instead of returning '
        'an empty quiz', () {
      final questions = LocalQuizGenerator(random: Random(1)).generate(
        passages: passages,
        config: QuizConfig.defaults.copyWith(
          count: 4,
          kinds: {QuizKind.identification},
        ),
      );
      expect(questions, isNotEmpty);
      expect(questions.first.kind, QuizKind.multipleChoice);
    });
  });
}
