import 'dart:io';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:notably/core/ai/gemini_service.dart';
import 'package:notably/features/editor/quiz/quiz_align.dart';
import 'package:notably/features/editor/quiz/quiz_generator.dart';
import 'package:notably/features/editor/quiz/quiz_models.dart';
import 'package:notably/features/editor/quiz/quiz_quality.dart';

void main() {
  setUpAll(() async {
    await loadQuizStopWords(
      contents: File(kQuizStopWordsAsset).readAsStringSync(),
    );
  });
  const passages = [
    SourcePassage(
      pageIndex: 13,
      sentence:
          'Ribosomes synthesise proteins from amino acids inside eukaryotic cells.',
    ),
    SourcePassage(
      pageIndex: 13,
      sentence:
          'The Golgi apparatus packages proteins for transport across the membrane.',
    ),
    SourcePassage(
      pageIndex: 14,
      sentence:
          'Mitochondria generate ATP through cellular respiration in animal cells.',
    ),
    SourcePassage(
      pageIndex: 15,
      sentence:
          'Lysosomes digest worn-out organelles using hydrolytic enzymes.',
    ),
    SourcePassage(
      pageIndex: 16,
      sentence:
          'The nucleus stores genetic material and controls gene expression.',
    ),
  ];

  test('writes multiple-choice items from source sentences', () {
    final quiz = LocalQuizGenerator(random: Random(1)).generate(
      passages: passages,
      config: const QuizConfig(
        count: 4,
        kinds: {QuizKind.multipleChoice},
        difficulty: QuizDifficulty.medium,
        timer: QuizTimerMode.off,
      ),
    );
    expect(quiz, isNotEmpty);
    expect(quiz.first.choices, hasLength(4));
    expect(quiz.first.choices.toSet(), hasLength(4));
    expect(
      quiz.first.correctIndex,
      inInclusiveRange(0, quiz.first.choices.length - 1),
    );
  });

  test('short answers match ignoring case and extra words', () {
    expect(answersMatch('Ribosomes', 'ribosomes'), isTrue);
    expect(answersMatch('the ribosomes', 'Ribosomes'), isTrue);
    expect(answersMatch('Golgi', 'Ribosomes'), isFalse);
  });

  test('samplePageIndices keeps ends and stays within cap', () {
    expect(samplePageIndices({0, 1, 2}, 10), {0, 1, 2});
    expect(samplePageIndices(List.generate(900, (i) => i), 5), {0, 225, 450, 674, 899});
    expect(samplePageIndices(const [], 10), isEmpty);
  });

  test('skips bibliographic citations and does not write cloze items', () {
    final quiz = LocalQuizGenerator(random: Random(2)).generate(
      passages: [
        const SourcePassage(
          pageIndex: 3559,
          sentence: 'kirimanjeswara gs, golden jm, bakshi cs, et al.',
        ),
        const SourcePassage(
          pageIndex: 445,
          sentence:
              'concentrations of doxycycline patterns of enterococci: results from the sentry 6.',
        ),
        ...passages,
      ],
      config: const QuizConfig(
        count: 4,
        kinds: {QuizKind.multipleChoice, QuizKind.trueFalse},
        difficulty: QuizDifficulty.medium,
        timer: QuizTimerMode.off,
      ),
    );
    expect(quiz, isNotEmpty);
    for (final q in quiz) {
      expect(q.prompt.toLowerCase(), isNot(contains('et al')));
      expect(q.prompt.toLowerCase(), isNot(contains('completes this sentence')));
      expect(q.prompt, isNot(contains('______')));
      expect(q.explanation.toLowerCase(), contains('see page'));
      expect(q.explanation.length, greaterThan(40));
    }
  });

  test('rejects questions that need a figure the student never sees', () {
    // The student is shown words, never the page — so these are unanswerable.
    expect(needsUnseenFigure('Identify the type of assay shown in diagram B of Figure 5.4.'), isTrue);
    expect(needsUnseenFigure('Identify the anatomical infection labeled C in Figure 64.7.'), isTrue);
    expect(needsUnseenFigure('What process does this diagram depict?'), isTrue);
    expect(needsUnseenFigure('What is the structure indicated on this page?'), isTrue);
    expect(needsUnseenFigure('Which organism is shown in the micrograph?'), isTrue);
    expect(needsUnseenFigure('What is listed in Table 3?'), isTrue);
  });

  test('keeps self-contained questions about the same subject matter', () {
    expect(
      needsUnseenFigure(
        'What do you call the inflammatory infection of the gingival tissue '
        'overlying a partially erupted tooth?',
      ),
      isFalse,
    );
    expect(
      needsUnseenFigure('What prevents backflow into the left atrium?'),
      isFalse,
    );
    expect(
      needsUnseenFigure('Where does the enzyme-linked immunosorbent assay bind?'),
      isFalse,
    );
  });

  test('isExamStyleQuestion rejects pasted stems and generic choices', () {
    const bad = QuizQuestion(
      kind: QuizKind.multipleChoice,
      prompt:
          'Which of the following is often injected, especially near the '
          'limbus (ciliary flush), and slit-lamp examination shows cells '
          'in the anterior chamber?',
      choices: [
        'The Eye',
        'Panuveitis',
        'Patients',
        'Suspected Viral Etiology',
      ],
      correctIndex: 0,
      acceptedAnswer: 'The Eye',
      explanation:
          'The Eye is often injected, especially near the limbus '
          '(ciliary flush), and slit-lamp examination shows cells in the '
          'anterior chamber. See page 1932 of the material.',
      pageIndex: 1931,
    );
    expect(isExamStyleQuestion(bad), isFalse);
    expect(isGenericAnswer('The Eye'), isTrue);
    expect(isGenericAnswer('Patients'), isTrue);
  });

  test('rejects Which of the following even with parallel options', () {
    const q = QuizQuestion(
      kind: QuizKind.multipleChoice,
      prompt: 'Which of the following statements is correct?',
      choices: [
        'Ribosomes synthesise proteins from amino acids inside cells',
        'Mitochondria generate ATP through cellular respiration',
        'Lysosomes digest worn-out organelles using enzymes',
        'The nucleus stores genetic material and controls genes',
      ],
      correctIndex: 1,
      acceptedAnswer: 'Mitochondria generate ATP through cellular respiration',
      explanation:
          'This statement is true because mitochondria generate ATP through '
          'cellular respiration. See page 15.',
      pageIndex: 14,
    );
    expect(isExamStyleQuestion(q), isFalse);
  });

  test('rejects explanations that only validate the answer', () {
    const q = QuizQuestion(
      kind: QuizKind.multipleChoice,
      prompt: 'Where is ATP generated in animal cells?',
      choices: [
        'Mitochondria during cellular respiration',
        'Lysosomes during hydrolysis of organelles',
        'The nucleus during gene transcription',
        'The Golgi during protein packaging',
      ],
      correctIndex: 0,
      acceptedAnswer: 'Mitochondria during cellular respiration',
      explanation:
          'The correct statement is: mitochondria generate ATP. '
          'The other options change a key term. See page 15.',
      pageIndex: 14,
    );
    expect(isExamStyleQuestion(q), isFalse);
  });

  test('multiple-choice items use complete statement options', () {
    final quiz = LocalQuizGenerator(random: Random(1)).generate(
      passages: passages,
      config: const QuizConfig(
        count: 4,
        kinds: {QuizKind.multipleChoice},
        difficulty: QuizDifficulty.medium,
        timer: QuizTimerMode.off,
      ),
    );
    expect(quiz, isNotEmpty);
    for (final q in quiz) {
      expect(q.prompt.toLowerCase(), isNot(contains('which of the following')));
      expect(q.explanation.toLowerCase(), isNot(contains('the correct statement is')));
      expect(q.explanation.toLowerCase(), contains('fact'));
      expect(
        q.prompt.toLowerCase(),
        anyOf(
          contains('what'),
          contains('when'),
          contains('where'),
          contains('why'),
        ),
      );
      expect(q.prompt.toLowerCase(), isNot(contains('is often injected')));
      for (final choice in q.choices) {
        expect(choice.trim().split(RegExp(r'\s+')).length, greaterThanOrEqualTo(8));
        expect(isGenericAnswer(choice), isFalse);
      }
      expect(isExamStyleQuestion(q), isTrue);
    }
  });

  test('shouldUsePageImages prefers vision when text is thin', () {
    expect(
      shouldUsePageImages(
        compactText: compactQuizPages(const []),
        hasPageImages: true,
      ),
      isTrue,
    );
    expect(
      shouldUsePageImages(
        compactText: compactQuizPages(const []),
        hasPageImages: false,
      ),
      isFalse,
    );
    final rich = [
      for (var i = 0; i < 8; i++)
        SourcePassage(
          pageIndex: i,
          sentence:
              'Ribosomes synthesise proteins from amino acids inside eukaryotic cells. '
              'The Golgi apparatus packages proteins for transport across the membrane.',
        ),
    ];
    expect(
      shouldUsePageImages(
        compactText: compactQuizPages(rich),
        hasPageImages: true,
      ),
      isFalse,
    );
  });

  test('isQuizWorthyText rejects author lists', () {
    expect(
      isQuizWorthyText('kirimanjeswara gs, golden jm, bakshi cs, et al.'),
      isFalse,
    );
    expect(
      isQuizWorthyText(
        'Ribosomes synthesise proteins from amino acids inside eukaryotic cells.',
      ),
      isTrue,
    );
    expect(
      isQuizWorthyText(
        'Figure 3. Results from the sentry 6 concentrations of doxycycline.',
      ),
      isFalse,
    );
  });

  test('accepts naming questions but not ones that point at a figure', () {
    const naming = QuizQuestion(
      kind: QuizKind.shortAnswer,
      prompt:
          'What do you call the organelle that packages proteins for transport?',
      choices: [],
      correctIndex: 0,
      acceptedAnswer: 'Golgi apparatus',
      explanation:
          'It is called the Golgi apparatus because it packages proteins '
          'for transport, unlike the rough ER. See page 14.',
      pageIndex: 13,
    );
    const illustration = QuizQuestion(
      kind: QuizKind.multipleChoice,
      prompt: 'Where is the nucleus shown in Figure 3 on this page?',
      choices: [
        'Upper left of the diagram',
        'Along the cell membrane',
        'Inside the mitochondrion',
        'At the Golgi stack',
      ],
      correctIndex: 0,
      acceptedAnswer: 'Upper left of the diagram',
      explanation:
          'The illustration labels the nucleus in the upper left because that '
          'is where genetic material is stored. See page 8.',
      pageIndex: 7,
    );
    expect(isExamStyleQuestion(naming), isTrue);
    // Reversed deliberately: the quiz shows the student words, never the page,
    // so an item that points at Figure 3 cannot be answered.
    expect(isExamStyleQuestion(illustration), isFalse);
  });

  test('parseExplanationPageLinks turns See page N into a citation', () {
    final parts = parseExplanationPageLinks(
      'Injection clustered at the limbus points to uveitis. See page 12.',
    );
    expect(parts, hasLength(2));
    expect(parts.first.pageNumber, isNull);
    expect(parts.last.pageNumber, 12);
    expect(parts.last.text, 'See page 12.');
    expect(parseExplanationPageLinks('No citation here.').single.pageNumber, isNull);
  });

  test('QuizHighlight.tryParse accepts fractions and rejects full-page boxes', () {
    final box = QuizHighlight.tryParse({'x': 0.1, 'y': 0.2, 'w': 0.5, 'h': 0.15});
    expect(box, isNotNull);
    expect(box!.x, 0.1);
    expect(box.w, 0.5);
    final percent = QuizHighlight.tryParse(
      {'left': 10, 'top': 20, 'width': 40, 'height': 15},
    );
    expect(percent, isNotNull);
    expect(percent!.x, closeTo(0.10, 0.001));
    expect(QuizHighlight.tryParse({'x': 0, 'y': 0, 'w': 1, 'h': 1}), isNull);
    expect(QuizHighlight.tryParse(null), isNull);
    final fromList = QuizHighlight.tryParse([0.2, 0.3, 0.4, 0.1]);
    expect(fromList, isNotNull);
    final line = QuizHighlight.tryParse(
      {'x': 0.12, 'y': 0.40, 'w': 0.52, 'h': 0.022},
    );
    expect(line, isNotNull);
    expect(line!.h, closeTo(0.022, 0.0001));
    expect(fromList!.y, 0.3);
  });

  test('asInkStroke keeps a two-column box in one column on one line', () {
    const wide = QuizHighlight(x: 0.06, y: 0.62, w: 0.88, h: 0.14);
    final ink = wide.asInkStroke();
    expect(ink.x + ink.w, lessThan(0.50));
    expect(ink.w, lessThan(0.47));
    expect(ink.h, lessThan(0.03));
    expect(ink.y, greaterThan(wide.y));
    expect(ink.y + ink.h, lessThan(wide.y + wide.h));
  });

  test('asInkStroke pins y near top of tall box instead of pushing into blank', () {
    const tall = QuizHighlight(x: 0.05, y: 0.55, w: 0.90, h: 0.20);
    final ink = tall.asInkStroke();
    final yDelta = ink.y - tall.y;
    expect(yDelta, lessThan(0.025));
    expect(ink.h, closeTo(0.019, 0.002));
  });

  test('asInkStroke leaves a single-column line in that column', () {
    const right = QuizHighlight(x: 0.53, y: 0.40, w: 0.38, h: 0.019);
    final ink = right.asInkStroke();
    expect(ink.x, closeTo(0.53, 0.02));
    expect(ink.x, greaterThan(0.50));
  });

  test('withShuffledChoices moves the key off A but keeps it correct', () {
    const original = QuizQuestion(
      kind: QuizKind.multipleChoice,
      prompt: 'Why are first-generation antihistamines used at night?',
      choices: [
        'Sedating effects relieve rhinorrhea and aid sleep',
        'They neutralize rhinovirus capsid proteins',
        'They prevent otitis media in adults',
        'They constrict nasal mucosal capillaries',
      ],
      correctIndex: 0,
      acceptedAnswer: 'Sedating effects relieve rhinorrhea and aid sleep',
      explanation: 'They cross the blood-brain barrier. See page 822.',
      pageIndex: 821,
    );
    final shuffled = original.withShuffledChoices(Random(7));
    expect(shuffled.choices[shuffled.correctIndex], original.choices[0]);
    expect(shuffled.choices.toSet(), original.choices.toSet());
    expect(shuffled.correctIndex, isNot(0));
  });

  test('reshuffleQuiz reorders items and keeps every answer correct', () {
    const original = [
      QuizQuestion(
        kind: QuizKind.multipleChoice,
        prompt: 'Q1',
        choices: ['A1', 'B1', 'C1', 'D1'],
        correctIndex: 0,
        acceptedAnswer: 'A1',
        explanation: '',
        pageIndex: 0,
      ),
      QuizQuestion(
        kind: QuizKind.trueFalse,
        prompt: 'Q2',
        choices: ['True', 'False'],
        correctIndex: 0,
        acceptedAnswer: 'True',
        explanation: '',
        pageIndex: 1,
      ),
      QuizQuestion(
        kind: QuizKind.multipleChoice,
        prompt: 'Q3',
        choices: ['A3', 'B3', 'C3', 'D3'],
        correctIndex: 2,
        acceptedAnswer: 'C3',
        explanation: '',
        pageIndex: 2,
      ),
      QuizQuestion(
        kind: QuizKind.shortAnswer,
        prompt: 'Q4',
        choices: [],
        correctIndex: 0,
        acceptedAnswer: 'ribosome',
        explanation: '',
        pageIndex: 3,
      ),
    ];
    final shuffled = reshuffleQuiz(original, random: Random(3));
    expect(
      shuffled.map((q) => q.prompt).toSet(),
      original.map((q) => q.prompt).toSet(),
    );
    expect(
      shuffled.map((q) => q.prompt).toList(),
      isNot(original.map((q) => q.prompt).toList()),
    );
    for (final question in shuffled) {
      if (question.choices.isEmpty) {
        expect(question.acceptedAnswer, 'ribosome');
        continue;
      }
      expect(
        question.choices[question.correctIndex],
        question.acceptedAnswer,
      );
    }
    final q1 = shuffled.firstWhere((q) => q.prompt == 'Q1');
    expect(q1.choices.toSet(), {'A1', 'B1', 'C1', 'D1'});
  });

  test('alignQuestionToSource highlights the page that states the answer', () {
    const question = QuizQuestion(
      kind: QuizKind.multipleChoice,
      prompt:
          'Where do specialized genes that encode bacterial virulence '
          'determinants typically reside?',
      choices: [
        'On mobile DNA such as plasmids, transposons, or bacteriophages',
        'Within the ribosomal RNA gene clusters only',
        'Exclusively on the host nuclear chromosome',
        'In host-derived extracellular vesicles',
      ],
      correctIndex: 0,
      acceptedAnswer:
          'On mobile DNA such as plasmids, transposons, or bacteriophages',
      explanation: 'Virulence genes often travel on mobile DNA. See page 4.',
      pageIndex: 3,
      highlight: QuizHighlight(x: 0.1, y: 0.4, w: 0.8, h: 0.2),
    );
    const pages = [
      QuizSourcePage(
        pageIndex: 3,
        text:
            'Cesar A. Arias, MD, MSc, PhD Enterococcus Species, Streptococcus '
            'gallolyticus Group, and Leuconostoc Species. David M. Aronoff, MD.',
      ),
      QuizSourcePage(
        pageIndex: 41,
        text:
            'Specialized genes that encode bacterial virulence determinants such '
            'as toxins and adhesins typically reside on mobile DNA including '
            'plasmids, transposons, or bacteriophages rather than the core '
            'ribosomal RNA clusters.',
      ),
    ];
    final aligned = alignQuestionToSource(question, pages);
    expect(aligned.pageIndex, 41);
    expect(aligned.explanation.toLowerCase(), contains('see page 42'));
    expect(aligned.highlight, isNotNull);
    expect(aligned.highlight!.w, lessThan(0.5));
    expect(aligned.highlight!.h, lessThan(0.03));
  });

  test('isFrontMatterPage catches contributor lists', () {
    expect(
      isFrontMatterPage(
        'Cesar A. Arias, MD, MSc, PhD. David M. Aronoff, MD. '
        'Naomi E. Aronson, MD. Michael H. Augenbraun, MD, MPH.',
      ),
      isTrue,
    );
    expect(
      isFrontMatterPage(
        'Specialized genes that encode bacterial virulence determinants '
        'reside on plasmids and transposons.',
      ),
      isFalse,
    );
  });

  test('isReferencePage catches bibliography pages', () {
    expect(
      isReferencePage(
        'References\n'
        '1. Smith J, Doe A, et al. Journal of Biology. 2020;vol. 12: pp. 1-10.\n'
        '2. Brown K, Lee M, et al. doi:10.1234/example. 2019.\n'
        '3. Chen X, Wang Y, et al. https://example.com/paper. 2021.\n'
        '4. Davis P, Miller R, et al. Journal of Medicine. 2018.\n'
        '5. Evans T, White S, et al. doi:10.5678/test. 2020.\n',
      ),
      isTrue,
    );
    expect(
      isReferencePage(
        'Specialized genes that encode bacterial virulence determinants '
        'such as toxins and adhesins typically reside on mobile DNA '
        'including plasmids, transposons, or bacteriophages.',
      ),
      isFalse,
    );
  });

  test('alignQuestionToSource skips reference and bibliography pages', () {
    const question = QuizQuestion(
      kind: QuizKind.multipleChoice,
      prompt: 'Where do virulence genes reside?',
      choices: [
        'On mobile DNA such as plasmids',
        'Within ribosomal RNA gene clusters',
        'Exclusively on the host nuclear chromosome',
        'In host-derived extracellular vesicles',
      ],
      correctIndex: 0,
      acceptedAnswer: 'On mobile DNA such as plasmids',
      explanation: 'Virulence genes travel on mobile DNA. See page 4.',
      pageIndex: 3,
      highlight: QuizHighlight(x: 0.1, y: 0.4, w: 0.8, h: 0.2),
    );
    const pages = [
      QuizSourcePage(
        pageIndex: 3,
        text: 'References\n'
            '1. Smith J, Doe A, et al. Journal of Biology. 2020.\n'
            '2. Brown K, Lee M, et al. doi:10.1234/example. 2019.\n'
            '3. Chen X, Wang Y, et al. https://example.com. 2021.\n'
            '4. Davis P, Miller R, et al. Journal of Medicine. 2018.\n'
            '5. Evans T, White S, et al. doi:10.5678/test. 2020.\n',
      ),
      QuizSourcePage(
        pageIndex: 41,
        text:
            'Specialized genes that encode bacterial virulence determinants such '
            'as toxins and adhesins typically reside on mobile DNA including '
            'plasmids, transposons, or bacteriophages rather than the core '
            'ribosomal RNA clusters.',
      ),
    ];
    final aligned = alignQuestionToSource(question, pages);
    expect(aligned.pageIndex, 41);
    expect(aligned.highlight, isNotNull);
  });
}
