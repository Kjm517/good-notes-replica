import 'package:flutter_test/flutter_test.dart';
import 'package:notably/core/ai/single_question_prompt.dart';

void main() {
  const pageOne = 'The mitral valve separates the left atrium from the left '
      'ventricle and prevents backflow during systole.';
  const pageTwo = 'The sciatic nerve is the largest nerve in the human body.';

  group('regenerating one question', () {
    test('sends only the page it needs, not the whole document', () {
      final prompt = buildSingleQuestionPrompt(
        pageText: pageOne,
        pageIndex: 11,
        kind: 'multipleChoice',
        difficulty: 'medium',
      );
      expect(prompt, contains('mitral valve'));
      // The rest of the book must not be in here — that is the entire cost
      // argument for regenerating one item.
      expect(prompt, isNot(contains('sciatic')));
      expect(prompt.length, lessThan(kSingleQuestionContextChars + 2000));
    });

    test('asks for exactly one question', () {
      final prompt = buildSingleQuestionPrompt(
        pageText: pageOne,
        pageIndex: 0,
        kind: 'shortAnswer',
        difficulty: 'easy',
      );
      expect(prompt, contains('exactly ONE'));
      expect(prompt, contains('single JSON object, not an array'));
    });

    test('carries the kind and difficulty it was asked for', () {
      final prompt = buildSingleQuestionPrompt(
        pageText: pageOne,
        pageIndex: 0,
        kind: 'trueFalse',
        difficulty: 'hard',
      );
      expect(prompt, contains('trueFalse'));
      expect(prompt, contains('hard'));
    });

    test('names the rejected answer so it is not offered again', () {
      final prompt = buildSingleQuestionPrompt(
        pageText: pageOne,
        pageIndex: 0,
        kind: 'shortAnswer',
        difficulty: 'medium',
        rejectedAnswer: 'Mitral valve',
      );
      expect(prompt, contains('Do NOT ask about "Mitral valve"'));
    });

    test('lists the existing questions so the replacement is not a duplicate',
        () {
      final prompt = buildSingleQuestionPrompt(
        pageText: pageOne,
        pageIndex: 0,
        kind: 'multipleChoice',
        difficulty: 'medium',
        avoidPrompts: const ['What does the mitral valve prevent?'],
      );
      expect(prompt, contains('Do not repeat'));
      expect(prompt, contains('What does the mitral valve prevent?'));
    });

    test('caps how many existing questions it repeats back', () {
      final many = [for (var i = 0; i < 40; i++) 'Question number $i?'];
      final prompt = buildSingleQuestionPrompt(
        pageText: pageOne,
        pageIndex: 0,
        kind: 'multipleChoice',
        difficulty: 'medium',
        avoidPrompts: many,
      );
      // Every previous question would defeat the point: the prompt would grow
      // with the quiz and cost more each time.
      expect(prompt, contains('Question number 0?'));
      expect(prompt, isNot(contains('Question number 39?')));
    });

    test('truncates a long page instead of sending all of it', () {
      final long = 'x' * (kSingleQuestionContextChars * 3);
      final prompt = buildSingleQuestionPrompt(
        pageText: long,
        pageIndex: 0,
        kind: 'shortAnswer',
        difficulty: 'medium',
      );
      expect(prompt.length, lessThan(kSingleQuestionContextChars + 2000));
      expect(prompt, contains('…'));
    });

    test('cites the page a student can check, one-based', () {
      final prompt = buildSingleQuestionPrompt(
        pageText: pageOne,
        pageIndex: 11,
        kind: 'shortAnswer',
        difficulty: 'medium',
      );
      expect(prompt, contains('See page 12'));
      expect(prompt, contains('PAGE 12'));
      expect(prompt, contains('"pageIndex":11'));
    });

    test('omits the avoid section entirely when there is nothing to avoid', () {
      final prompt = buildSingleQuestionPrompt(
        pageText: pageOne,
        pageIndex: 0,
        kind: 'shortAnswer',
        difficulty: 'medium',
        avoidPrompts: const ['', '   '],
      );
      expect(prompt, isNot(contains('Do not repeat')));
      expect(prompt, isNot(contains('Do NOT ask about')));
    });
  });
}
