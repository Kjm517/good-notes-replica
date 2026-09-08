@TestOn('browser')
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:notably/features/editor/quiz/quiz_models.dart';
import 'package:notably/features/editor/quiz/quiz_quality.dart';

/// The quiz rules, run in a browser.
///
/// Worth doing separately from the VM suite: JS has one number type, so an
/// `int` index and a `double` fraction behave differently than they do on the
/// VM. Identification carries both — a correctIndex and a 0–1 highlight box.
void main() {
  QuizQuestion ident({
    String prompt = 'What is the marked structure?',
    QuizHighlight? highlight =
        const QuizHighlight(x: 0.44, y: 0.31, w: 0.07, h: 0.06),
  }) =>
      QuizQuestion(
        kind: QuizKind.identification,
        prompt: prompt,
        choices: const [],
        correctIndex: 0,
        acceptedAnswer: 'Golgi apparatus',
        explanation:
            'The marked stack of flattened membrane sacs is the Golgi '
            'apparatus, which packages proteins into vesicles because they '
            'are bound for the cell surface. See page 14.',
        pageIndex: 13,
        highlight: highlight,
      );

  test('the identification gate holds up under JS number semantics', () {
    expect(isExamStyleQuestion(ident()), isTrue);
    expect(isExamStyleQuestion(ident(highlight: null)), isFalse);
    // 0.8 > 0.5 must still reject where int and double are the same type.
    expect(
      isExamStyleQuestion(
        ident(highlight: const QuizHighlight(x: 0.1, y: 0.1, w: 0.8, h: 0.06)),
      ),
      isFalse,
    );
  });

  test('highlight fractions survive a JSON round trip in JS', () {
    final restored = QuizQuestion.fromJson(ident().toJson());
    expect(restored.highlight!.x, closeTo(0.44, 1e-9));
    expect(restored.highlight!.w, closeTo(0.07, 1e-9));
    // correctIndex is an int in Dart and a double in JS underneath; it must
    // still come back as an int, or choice comparison silently stops matching.
    expect(restored.correctIndex, isA<int>());
    expect(restored.correctIndex, 0);
    expect(restored.pageIndex, isA<int>());
  });

  test('kind metadata is consistent on web', () {
    expect(QuizKind.identification.isWritten, isTrue);
    expect(QuizKind.identification.needsFigure, isTrue);
    expect(QuizKind.identification.label, 'Identification');
    for (final k in QuizKind.values) {
      expect(k.label, isNotEmpty, reason: '$k');
    }
  });

  test('asInkStroke keeps the box on the page in JS arithmetic', () {
    const wide = QuizHighlight(x: 0.08, y: 0.4, w: 0.85, h: 0.019);
    final snapped = wide.asInkStroke();
    expect(snapped.x, greaterThanOrEqualTo(0.0));
    expect(snapped.x + snapped.w, lessThanOrEqualTo(1.0001));
    expect(snapped.h, greaterThan(0.0));
  });
}
