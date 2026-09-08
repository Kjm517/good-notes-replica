import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:notably/features/editor/quiz/figure_labels.dart';
import 'package:notably/features/editor/quiz/quiz_align.dart';
import 'package:notably/features/editor/quiz/quiz_models.dart';
import 'package:notably/features/editor/search/pdf_text_line.dart';

PdfTextLine line(String text, double x, double y, {double w = 0.12}) =>
    PdfTextLine(text: text, x: x, y: y, w: w, h: 0.014);

/// Labels scattered around a drawing, as a real anatomy plate has them.
List<PdfTextLine> anatomyFigure() => [
      line('Frontal lobe', 0.12, 0.20),
      line('Parietal lobe', 0.62, 0.24),
      line('Occipital lobe', 0.71, 0.48),
      line('Cerebellum', 0.55, 0.68),
      line('Brain stem', 0.28, 0.74),
      line('Temporal lobe', 0.10, 0.55),
    ];

void main() {
  setUpAll(() async {
    await loadQuizStopWords(
      contents: File(kQuizStopWordsAsset).readAsStringSync(),
    );
  });

  group('isLabelLike', () {
    test('accepts a short named part', () {
      expect(isLabelLike(line('Left ventricle', 0.3, 0.3)), isTrue);
    });

    test('rejects prose — punctuated, and too wide for a column', () {
      expect(
        isLabelLike(line(
          'The left ventricle pumps oxygenated blood into the aorta.',
          0.1,
          0.3,
          w: 0.62,
        )),
        isFalse,
      );
    });

    test('rejects a caption, which describes the figure rather than labels it',
        () {
      expect(isLabelLike(line('Figure 3.1 The human brain', 0.1, 0.9)), isFalse);
      expect(isLabelLike(line('Table 2 Results', 0.1, 0.9)), isFalse);
    });

    test('rejects page furniture and bare numbers', () {
      expect(isLabelLike(line('Chapter 4', 0.1, 0.05)), isFalse);
      expect(isLabelLike(line('page 128', 0.45, 0.96)), isFalse);
      expect(isLabelLike(line('128', 0.48, 0.96)), isFalse);
      expect(isLabelLike(line('12.5 %', 0.48, 0.5)), isFalse);
    });

    test('rejects a generic word that would be a worthless answer', () {
      expect(isLabelLike(line('figure', 0.4, 0.4)), isFalse);
      expect(isLabelLike(line('results', 0.4, 0.4)), isFalse);
    });

    test('rejects a line with no letters at all', () {
      expect(isLabelLike(line('---', 0.4, 0.4)), isFalse);
    });
  });

  group('harvestFigureLabels', () {
    test('reads the labels off a diagram', () {
      final labels = harvestFigureLabels(anatomyFigure());
      expect(labels, hasLength(6));
      expect(
        labels.map((l) => l.text),
        containsAll(['Frontal lobe', 'Cerebellum', 'Brain stem']),
      );
      // Each carries the box of its own type, so it can be covered up.
      expect(labels.first.box.precise, isTrue);
      expect(labels.first.box.w, closeTo(0.12, 1e-9));
    });

    test('ignores a page of body text', () {
      final prose = [
        for (var i = 0; i < 12; i++)
          line(
            'The circulatory system moves blood through vessels to the tissues',
            0.1,
            0.1 + i * 0.05,
            w: 0.62,
          ),
      ];
      expect(harvestFigureLabels(prose), isEmpty);
    });

    test('ignores a vocabulary list — short, but all on one margin', () {
      final list = [
        for (var i = 0; i < 8; i++) line('Term number $i', 0.10, 0.2 + i * 0.04),
      ];
      // Same left edge for every line: a list, not a drawing.
      expect(harvestFigureLabels(list), isEmpty);
    });

    test('rejects a lecture slide, which is text at several x positions', () {
      // The exact shape that produced "What is the covered label pointing to?"
      // with the answer "A Surgical Overview": a title, then two bullet
      // columns. Every line is short and unpunctuated, and they occupy three
      // distinct left edges, so the earlier rules all passed.
      final slide = [
        line('Acquired Heart Diseases', 0.14, 0.10, w: 0.28),
        line('A Surgical Overview', 0.17, 0.14, w: 0.22),
        line('Coronary artery disease', 0.10, 0.30, w: 0.24),
        line('Valvular diseases', 0.10, 0.34, w: 0.20),
        line('Heart failure', 0.10, 0.38, w: 0.16),
        line('Cardiac tumors', 0.10, 0.42, w: 0.18),
        line('Pericardial disease', 0.55, 0.30, w: 0.22),
        line('Cardiac neoplasms', 0.55, 0.34, w: 0.22),
        line('Benign cardiac tumors', 0.55, 0.38, w: 0.24),
      ];
      expect(harvestFigureLabels(slide), isEmpty);
    });

    test('rejects a page whose region is nearly all type', () {
      // Scattered, unstacked, but dense: a table of terms, not a drawing.
      final dense = [
        for (var i = 0; i < 8; i++)
          line('Term $i', 0.10 + (i % 4) * 0.20, 0.30 + (i ~/ 4) * 0.04,
              w: 0.18),
      ];
      expect(harvestFigureLabels(dense), isEmpty);
    });

    test('a diagram inside a slide is kept once the pixels confirm a picture',
        () {
      // The exact case that returned nothing: a lecture slide whose bullets
      // trigger every "this is not a figure" rule, with a labelled plate on
      // it. Judged as a page it is a slide; judged as the region the picture
      // occupies, it is a diagram.
      final plateLabels = [
        line('Tricuspid valve', 0.12, 0.22),
        line('Aortic valve', 0.16, 0.46),
        line('Pulmonary valve', 0.30, 0.50),
        line('Bicuspid valve', 0.34, 0.20),
      ];
      // As a whole page, with the slide's bullets, it is rejected.
      final wholeSlide = [
        ...plateLabels,
        line('Types of Valve Damage', 0.55, 0.10, w: 0.25),
        line('Stenosis', 0.56, 0.20, w: 0.18),
        line('Leaflet thickening', 0.58, 0.24, w: 0.22),
        line('Regurgitation', 0.56, 0.28, w: 0.20),
        line('Annular Dilation', 0.58, 0.32, w: 0.20),
        line('Prolapse', 0.56, 0.36, w: 0.16),
      ];
      expect(harvestFigureLabels(wholeSlide), isEmpty);

      // Restricted to the plate, with the pixels having confirmed a picture,
      // the labels are exactly the four on the diagram.
      final found = harvestFigureLabels(plateLabels, assumeFigure: true);
      expect(found.map((l) => l.text), containsAll(['Tricuspid valve']));
      expect(found, hasLength(4));
    });

    test('assumeFigure still needs at least two labels to ask about', () {
      final one = [line('Aorta', 0.2, 0.3)];
      expect(harvestFigureLabels(one, assumeFigure: true), isEmpty);
    });

    test('assumeFigure does not lower the bar for what counts as a label', () {
      // Page furniture is still page furniture, picture or no picture.
      final junk = [
        line('Chapter 4', 0.2, 0.3),
        line('page 128', 0.4, 0.3),
        line('Figure 3.1 The heart', 0.6, 0.3, w: 0.24),
        line('128', 0.8, 0.3),
      ];
      expect(harvestFigureLabels(junk, assumeFigure: true), isEmpty);
    });

    test('still accepts a real diagram after those rules', () {
      expect(harvestFigureLabels(anatomyFigure()), hasLength(6));
    });

    test('needs more than a couple of labels to count as a figure', () {
      final sparse = [
        line('Aorta', 0.2, 0.3),
        line('Atrium', 0.6, 0.5),
      ];
      expect(harvestFigureLabels(sparse), isEmpty);
    });

    test('the same word labelled twice becomes one question', () {
      final withLegend = [
        ...anatomyFigure(),
        line('Cerebellum', 0.85, 0.90),
      ];
      final labels = harvestFigureLabels(withLegend);
      final texts = labels.map((l) => l.text.toLowerCase()).toList();
      expect(texts.where((t) => t == 'cerebellum'), hasLength(1));
    });

    test('caps how many it returns', () {
      // Real-ish names: "Part 3" is rejected on purpose, because a lone
      // "Part" line is page furniture far more often than a label.
      const names = [
        'Aorta', 'Vena cava', 'Left atrium', 'Right atrium', 'Left ventricle',
        'Right ventricle', 'Pulmonary vein', 'Pulmonary artery', 'Mitral valve',
        'Tricuspid valve', 'Septum', 'Apex',
      ];
      final many = [
        for (var i = 0; i < names.length; i++)
          line(names[i], (i % 5) * 0.18, 0.1 + (i % 6) * 0.12),
      ];
      expect(harvestFigureLabels(many, maxLabels: 5), hasLength(5));
      // Without a cap it finds them all.
      expect(harvestFigureLabels(many), hasLength(names.length));
    });

    test('rejects "Part 3" as furniture rather than an anatomical label', () {
      expect(isLabelLike(line('Part 3', 0.2, 0.2)), isFalse);
      expect(isLabelLike(line('Partial pressure', 0.2, 0.2)), isTrue);
    });
  });

  group('figureRegion', () {
    test('covers the labels with room for the artwork they point at', () {
      final region = figureRegion(harvestFigureLabels(anatomyFigure()));
      expect(region.x, lessThan(0.10));
      expect(region.y, lessThan(0.20));
      expect(region.x + region.w, greaterThan(0.80));
      expect(region.y + region.h, greaterThan(0.74));
    });

    test('stays on the page when a label sits near the edge', () {
      final edge = [
        FigureLabel(
          text: 'Edge',
          box: const QuizHighlight(x: 0.0, y: 0.0, w: 0.05, h: 0.01),
        ),
        FigureLabel(
          text: 'Far',
          box: const QuizHighlight(x: 0.96, y: 0.98, w: 0.04, h: 0.01),
        ),
      ];
      final region = figureRegion(edge);
      expect(region.x, greaterThanOrEqualTo(0.0));
      expect(region.y, greaterThanOrEqualTo(0.0));
      expect(region.x + region.w, lessThanOrEqualTo(1.0001));
      expect(region.y + region.h, lessThanOrEqualTo(1.0001));
    });

    test('falls back to the whole page rather than an empty crop', () {
      final region = figureRegion(const []);
      expect(region.w, 1);
      expect(region.h, 1);
    });
  });

  group('pairing labels with the picture they belong to', () {
    test('keeps only the labels inside the region', () {
      // Two plates on one page — the heart-valve slide. Blanking the other
      // plate's words would ask about a structure that is not on screen.
      final left = [
        line('Tricuspid valve', 0.10, 0.20),
        line('Aortic valve', 0.14, 0.40),
        line('Pulmonary valve', 0.22, 0.44),
      ];
      final right = [
        line('Anterior leaflet', 0.62, 0.18),
        line('Chordae tendineae', 0.70, 0.46),
      ];
      final labels = harvestFigureLabels([...left, ...right]);
      const leftPlate = QuizHighlight(x: 0.05, y: 0.10, w: 0.40, h: 0.45);

      final mine = labelsInside(leftPlate, labels);
      expect(mine.map((l) => l.text), containsAll(['Tricuspid valve']));
      expect(mine.map((l) => l.text), isNot(contains('Chordae tendineae')));
    });

    test('crops to the picture, not to the column of words', () {
      // The leg-vein plate: labels run down the right-hand side, so the
      // labels' own bounding box is a strip of text, not the leg.
      final labels = [
        FigureLabel(
          text: 'Femoral Vein',
          box: const QuizHighlight(x: 0.72, y: 0.30, w: 0.16, h: 0.02),
        ),
        FigureLabel(
          text: 'Great Saphenous Vein',
          box: const QuizHighlight(x: 0.72, y: 0.44, w: 0.20, h: 0.02),
        ),
      ];
      const picture = QuizHighlight(x: 0.08, y: 0.10, w: 0.85, h: 0.80);
      final questions =
          identificationFromLabels(0, labels, region: picture);

      expect(questions, hasLength(2));
      final crop = questions.first.figure!.region;
      // The drawing on the left is included, which the labels alone would miss.
      expect(crop.x, closeTo(0.08, 1e-9));
      expect(crop.w, closeTo(0.85, 1e-9));
    });

    test('falls back to the labels when no picture was located', () {
      final labels = harvestFigureLabels(anatomyFigure());
      final questions = identificationFromLabels(0, labels);
      expect(questions.first.figure!.region.x, lessThan(0.12));
    });
  });

  group('identificationFromLabels', () {
    test('builds answerable questions with the marker on the label', () {
      final labels = harvestFigureLabels(anatomyFigure());
      final questions = identificationFromLabels(13, labels);
      expect(questions, isNotEmpty);

      for (final q in questions) {
        expect(q.kind, QuizKind.identification);
        expect(q.choices, isEmpty);
        expect(q.highlight, isNotNull, reason: 'nothing to point at');
        expect(q.pageIndex, 13);
        // The prompt must never contain the answer.
        expect(
          q.prompt.toLowerCase().contains(q.acceptedAnswer.toLowerCase()),
          isFalse,
          reason: 'prompt gives away "${q.acceptedAnswer}"',
        );
      }
      expect(
        questions.map((q) => q.acceptedAnswer),
        containsAll(['Frontal lobe', 'Cerebellum']),
      );
    });

    test('cites the page a student can turn to', () {
      final questions =
          identificationFromLabels(13, harvestFigureLabels(anatomyFigure()));
      expect(questions.first.explanation, contains('page 14'));
    });

    test('respects the maximum', () {
      final questions = identificationFromLabels(
        0,
        harvestFigureLabels(anatomyFigure()),
        max: 2,
      );
      expect(questions, hasLength(2));
    });

    test('no labels means no questions, not an empty-shell quiz', () {
      expect(identificationFromLabels(0, const []), isEmpty);
    });

    test('every label is blanked, not just the one being asked about', () {
      final questions =
          identificationFromLabels(3, harvestFigureLabels(anatomyFigure()));
      expect(questions, isNotEmpty);
      for (final q in questions) {
        final figure = q.figure;
        expect(figure, isNotNull, reason: q.acceptedAnswer);
        // Covering only the target would leave the answer readable on a
        // neighbouring label, or on the same word printed twice.
        expect(figure!.erase, hasLength(6));
      }
    });

    test('each question points at a different marker on the same figure', () {
      final questions =
          identificationFromLabels(3, harvestFigureLabels(anatomyFigure()));
      final targets = questions.map((q) => q.figure!.targetIndex).toList();
      expect(targets, targets.toSet().toList());
      // One render, many questions: the region is shared.
      final regions = questions.map((q) => q.figure!.region.x).toSet();
      expect(regions, hasLength(1));
    });

    test('the marker number in the prompt matches the target index', () {
      final questions =
          identificationFromLabels(0, harvestFigureLabels(anatomyFigure()));
      for (final q in questions) {
        expect(q.prompt, contains('labelled ${q.figure!.targetIndex + 1}'));
      }
    });

    test('the target box is the label whose word is the answer', () {
      final labels = harvestFigureLabels(anatomyFigure());
      final questions = identificationFromLabels(0, labels);
      for (final q in questions) {
        final target = q.figure!.target!;
        final matching = labels.firstWhere((l) => l.text == q.acceptedAnswer);
        expect(target.x, closeTo(matching.box.x, 1e-9));
        expect(target.y, closeTo(matching.box.y, 1e-9));
      }
    });

    test('the figure survives a round trip through history', () {
      final q = identificationFromLabels(
        3,
        harvestFigureLabels(anatomyFigure()),
      )[2];
      final restored = QuizQuestion.fromJson(q.toJson());
      expect(restored.figure, isNotNull);
      expect(restored.figure!.erase, hasLength(q.figure!.erase.length));
      expect(restored.figure!.targetIndex, q.figure!.targetIndex);
      expect(restored.acceptedAnswer, q.acceptedAnswer);
    });

    test('a target index beyond the boxes is clamped, not left dangling', () {
      final figure = QuizFigure.tryParse({
        'region': {'x': 0.0, 'y': 0.0, 'w': 1.0, 'h': 1.0},
        'erase': [
          {'x': 0.1, 'y': 0.1, 'w': 0.1, 'h': 0.02},
        ],
        'targetIndex': 99,
      });
      expect(figure, isNotNull);
      expect(figure!.targetIndex, 0);
      expect(figure.target, isNotNull);
    });

    test('a figure with no boxes to erase is not a figure', () {
      expect(
        QuizFigure.tryParse({
          'region': {'x': 0.0, 'y': 0.0, 'w': 1.0, 'h': 1.0},
          'erase': [],
        }),
        isNull,
      );
      expect(QuizFigure.tryParse(null), isNull);
    });

    test('model-written items have no figure — the marker is the structure',
        () {
      const fromModel = QuizQuestion(
        kind: QuizKind.identification,
        prompt: 'What is the marked structure?',
        choices: [],
        correctIndex: 0,
        acceptedAnswer: 'Cerebellum',
        explanation: 'The marked structure coordinates movement. See page 4.',
        pageIndex: 3,
        highlight: QuizHighlight(x: 0.4, y: 0.3, w: 0.06, h: 0.05),
      );
      // No figure means nothing is blanked — the marker is the structure.
      expect(fromModel.figure, isNull);
      expect(QuizQuestion.fromJson(fromModel.toJson()).figure, isNull);
    });
  });
}
