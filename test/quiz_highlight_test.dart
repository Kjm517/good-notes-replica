import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:notably/features/editor/quiz/quiz_align.dart';
import 'package:notably/features/editor/quiz/quiz_highlight_finder.dart';
import 'package:notably/features/editor/quiz/quiz_models.dart';
import 'package:notably/features/editor/search/pdf_text_line.dart';

/// A two-column textbook page: left column at x 0.08, right at x 0.53.
List<PdfTextLine> _page() {
  const left = 0.08;
  const right = 0.53;
  const width = 0.39;
  PdfTextLine line(String text, double x, int row) => PdfTextLine(
        text: text,
        x: x,
        y: 0.10 + row * 0.022,
        w: width,
        h: 0.016,
      );
  return [
    line('CHAPTER 44 Drug Eruptions', left, 0),
    line('Generalized maculopapular or morbilliform drug', left, 1),
    line('eruptions characteristically appear 7 to 14 days', left, 2),
    line('after initial administration of the offending agent.', left, 3),
    line('Urticarial reactions manifest within minutes to', right, 0),
    line('hours of drug exposure. Establishing this timeline', right, 1),
    line('is critical for identifying the culprit drug.', right, 2),
  ];
}

/// The reference list from the reported bug: a citation pointed here, and the
/// answer's own words ("virus", "antiviral") appear in the article titles.
List<PdfTextLine> _referenceList() {
  const rows = [
    '148. Crotty S, Cameron CE, Andino R. RNA virus error',
    'catastrophe: direct molecular test by using ribavirin. Proc',
    'Natl Acad Sci USA. 2001;98:6895-6900.',
    '149. Lanford RE, Guerra B, Lee H, et al. Antiviral effect and',
    'virus-host interactions in response to alpha interferon,',
    'gamma interferon, poly(i)-poly(c), tumor necrosis factor',
    'alpha, and ribavirin in hepatitis C virus subgenomic',
    'replicons. J Virol. 2003;77:1092-1104.',
    '150. Patterson JL, Fernandez-Larson R. Molecular',
    'mechanisms of action of ribavirin. Rev Infect Dis.',
    '1990;12:1139-1146.',
    '151. Pawlotsky JM, Dahari H, Neumann AU, et al. Antiviral',
    'action of ribavirin in chronic hepatitis C.',
    'Gastroenterology. 2004;126:703-714.',
  ];
  return [
    for (var i = 0; i < rows.length; i++)
      PdfTextLine(text: rows[i], x: 0.08, y: 0.10 + i * 0.022, w: 0.39, h: 0.016),
  ];
}

/// Lays [text] out as evenly spaced glyphs on one baseline, the way PDFium
/// reports them.
({String text, List<CharBox> boxes}) _glyphs(
  String text, {
  required double x,
  required double y,
  double charWidth = 0.006,
  double height = 0.016,
}) {
  return (
    text: text,
    boxes: [
      for (var i = 0; i < text.length; i++)
        CharBox(x: x + i * charWidth, y: y, w: charWidth, h: height),
    ],
  );
}

void main() {
  setUpAll(() async {
    await loadQuizStopWords(
      contents: File(kQuizStopWordsAsset).readAsStringSync(),
    );
  });

  test('normalizeForMatch drops case and stray punctuation', () {
    expect(
      normalizeForMatch('  7 to 14 DAYS, after  the first dose. '),
      '7 to 14 days after the first dose.',
    );
  });

  test('normalizeForMatch keeps decimals whole', () {
    expect(normalizeForMatch('>=37.2 C (99.0 F)'), '37.2 c (99.0 f)');
  });

  test('answerMarkers picks out figures and short identifiers', () {
    expect(answerMarkers('37.2 C (99.0 F)'), containsAll(['37.2', '99.0']));
    expect(answerMarkers('B7 family (CD80 or CD86)'), containsAll(['cd80', 'cd86']));
    expect(answerMarkers('the golgi apparatus'), isEmpty);
  });

  test('answerPhrases offers the whole answer before looser cuts', () {
    final phrases = answerPhrases('7 to 14 days after the first dose');
    expect(phrases.first, '7 to 14 days after the first dose');
    expect(phrases, contains('7 to 14 days'));
  });

  test('marks the whole sentence that states the answer', () {
    final match = findAnswerOnPage(
      lines: _page(),
      answer: 'characteristically appear',
      prompt: 'When does a maculopapular drug eruption appear?',
    );
    expect(match.exact, isTrue);
    expect(match.marks.first.precise, isTrue);
    // The sentence opens on the second line and closes on the fourth, so the
    // student sees the statement, not the two matched words.
    expect(match.marks, hasLength(3));
    expect(match.marks.first.y, closeTo(0.10 + 0.022, 0.01));
    expect(match.marks.last.y, closeTo(0.10 + 3 * 0.022, 0.01));
  });

  test('a mark starts where its sentence starts, not at the margin', () {
    final match = findAnswerOnPage(
      lines: _page(),
      answer: 'critical for identifying the culprit drug',
      prompt: '',
    );
    expect(match.exact, isTrue);
    // "Establishing this timeline" opens mid-line, so the ink does too.
    expect(match.marks.first.x, greaterThan(0.55));
  });

  test('finds an answer written as a figure, not as words', () {
    final match = findAnswerOnPage(
      lines: _page(),
      answer: '7 to 14 days',
      prompt: 'How soon does the eruption appear?',
    );
    expect(match.marks, isNotEmpty);
    expect(match.marks.first.y, greaterThan(0.10));
  });

  test('stays inside one column instead of spanning the gutter', () {
    final match = findAnswerOnPage(
      lines: _page(),
      answer: 'Urticarial reactions manifest within minutes',
      prompt: '',
    );
    expect(match.marks, isNotEmpty);
    expect(match.marks, isNotEmpty);
    for (final mark in match.marks) {
      expect(mark.x, greaterThan(0.5));
      expect(mark.x + mark.w, lessThanOrEqualTo(1.0));
    }
  });

  test('falls back to the line richest in the answer\'s own words', () {
    final match = findAnswerOnPage(
      lines: _page(),
      answer: 'morbilliform eruption of the offending agent',
      prompt: 'How soon does it appear?',
    );
    expect(match.exact, isFalse);
    expect(match.marks, isNotEmpty);
    expect(match.marks.first.y, greaterThan(0.10));
  });

  test('will not mark a page on the question\'s words alone', () {
    // The page says "7 to 14 days" and never "about two weeks". Marking it
    // would mean matching on "eruptions"/"appear" from the stem.
    final match = findAnswerOnPage(
      lines: _page(),
      answer: 'about two weeks',
      prompt: 'How soon do morbilliform eruptions appear after the agent?',
    );
    expect(match.isEmpty, isTrue);
  });

  test('a question word shared with an unrelated page is not a match', () {
    // The reported bug: a bradycardia question highlighted a page about
    // telbivudine, because both contain "clinical".
    const rows = [
      'Interactions',
      'Telbivudine does not seem to be metabolized by the CYP450',
      'isoenzymes, and the likelihood for interactions with drugs',
      'that use that pathway is low. Drugs that inhibit renal',
      'function may cause inhibition of excretion of telbivudine.',
      'Clinical Studies',
      'In large-scale trials telbivudine, at a dose of 600 mg/day',
      'for 52 weeks, reduced HBV DNA by a median of 6.4 log10 in',
      'HBeAg-positive and 5.2 log10 in HBeAg-negative patients.',
    ];
    final lines = [
      for (var i = 0; i < rows.length; i++)
        PdfTextLine(text: rows[i], x: 0.08, y: 0.1 + i * 0.022, w: 0.39, h: 0.016),
    ];
    final match = findAnswerOnPage(
      lines: lines,
      answer: 'Relative bradycardia',
      prompt: 'Name the clinical phenomenon demonstrated in Figure 56.2B '
          'where the pulse rate remains disproportionately low despite fever.',
    );
    expect(match.isEmpty, isTrue);
  });

  test('matches a word the book inflected differently', () {
    const rows = [
      'Pericoronitis is an inflammatory infection of the gingival',
      'tissue overlying the crown of a partially erupted tooth,',
      'most commonly an impacted third molar. Trapped food',
      'debris and oral bacteria proliferate beneath the operculum.',
    ];
    final lines = [
      for (var i = 0; i < rows.length; i++)
        PdfTextLine(text: rows[i], x: 0.08, y: 0.1 + i * 0.022, w: 0.39, h: 0.016),
    ];
    final match = findAnswerOnPage(
      lines: lines,
      answer: 'Pericoronal infection',
      prompt: 'Identify the anatomical infection labeled C in Figure 64.7.',
    );
    expect(match.marks, isNotEmpty);
  });

  test('a stem match still needs the stem to be a long word', () {
    expect(termScore('the operculum overlies the crown', ['pericoronal']), 0);
    expect(termScore('pericoronitis of the molar', ['pericoronal']), 1);
    expect(termScore('pericoronal infection', ['pericoronal']), 2);
  });

  test('leaves a parenthetical aside unmarked', () {
    // From the reported page: the answer is the quoted phrase, not the
    // cross-reference that follows it.
    const rows = [
      'or provide benefits from this association and are thus called',
      'commensals, which literally means those that eat at the same',
      'table (for definitions of classes of host-associated microbes,',
      'see Table 1.1). When they both give and receive benefits, the',
    ];
    final lines = [
      for (var i = 0; i < rows.length; i++)
        PdfTextLine(text: rows[i], x: 0.08, y: 0.1 + i * 0.022, w: 0.39, h: 0.016),
    ];
    final match = findAnswerOnPage(
      lines: lines,
      answer: 'Those that eat at the same table',
      prompt: 'What does the term commensal literally mean?',
    );
    expect(match.marks, isNotEmpty);
    // Nothing on the "see Table 1.1)" line, and the line holding "table (for"
    // is inked only up to the bracket.
    final lowest = match.marks.map((m) => m.y).reduce((a, b) => a > b ? a : b);
    expect(lowest, lessThan(0.1 + 3 * 0.022));
    expect(match.marks.last.x + match.marks.last.w, lessThan(0.08 + 0.39 * 0.3));
  });

  test('stops at the clause break, not the end of a long sentence', () {
    // From the reported page: the sentence carries on past the semicolon into
    // confluent ulcers and pseudomembranes, which are not the answer.
    const rows = [
      'Typical lesions of HSV esophagitis appear endoscopically as',
      'multiple, small, superficial ulcers in the distal third of the',
      'esophagus; larger confluent ulcers, pseudomembranes, or',
      'diffusely denuded epithelium may be seen as the infection',
      'progresses (Fig. 97.3). Volcano ulcers may have raised',
      'margins around the central crater. Vesicles are rarely seen.',
    ];
    final lines = [
      for (var i = 0; i < rows.length; i++)
        PdfTextLine(text: rows[i], x: 0.08, y: 0.1 + i * 0.022, w: 0.39, h: 0.016),
    ];
    final match = findAnswerOnPage(
      lines: lines,
      answer: 'As multiple, small, superficial ulcers with raised margins '
          'around a central crater',
      prompt: 'How do the classic endoscopic lesions of HSV esophagitis appear?',
    );
    expect(match.marks, isNotEmpty);
    // Nothing past the third line, where the semicolon is.
    expect(match.marks.length, lessThanOrEqualTo(3));
    final lowest = match.marks.map((m) => m.y).reduce((a, b) => a > b ? a : b);
    expect(lowest, lessThan(0.1 + 3 * 0.022));
    // And the semicolon line is only inked as far as the semicolon.
    final onSemicolonLine = match.marks.last;
    expect(onSemicolonLine.w, lessThan(0.39 * 0.6));
  });

  test('a true/false item is matched on its claim, not the word True', () {
    // The reported bug: the accepted answer is "True", which yields no terms
    // and no markers, so every true/false question went unmarked.
    const rows = [
      'hypothermia (temperature >38C or <36C); and leukocytosis (white',
      'blood cells >12000/mm3), leukopenia (white blood cells <4000/mm3),',
      'or bandemia. Sepsis-1 was defined as documented infection leading',
      'to the onset of SIRS as reflected by the presence of two or more',
      'SIRS criteria. Severe sepsis was defined as sepsis complicated by',
      'organ dysfunction, which could progress to septic shock.',
    ];
    final lines = [
      for (var i = 0; i < rows.length; i++)
        PdfTextLine(text: rows[i], x: 0.08, y: 0.1 + i * 0.022, w: 0.39, h: 0.016),
    ];
    final match = findAnswerOnPage(
      lines: lines,
      answer: 'True',
      prompt: 'Hypothermia in patients with sepsis is associated with an '
          'increased risk of adverse outcomes.',
    );
    expect(match.marks, isNotEmpty);
    expect(match.marks.first.y, lessThan(0.15));
  });

  test('a False verdict is matched on the claim it denies', () {
    // The reported page: the claim is wrong, and the passage that refutes it
    // is the one the student needs to see.
    const rows = [
      'Sepsis is a life-threatening condition with organ failure caused by a',
      'dysregulated host response to an infection. Septic shock is sepsis',
      'accompanied by persistent hypotension. The most common infections',
      'causing sepsis and septic shock are pneumonia and peritonitis. Any',
      'infection that overrides the protective innate immune response',
      'initiated in response to a potential pathogen can result in sepsis.',
      'Sepsis is most often caused by bacteria, but fungal and viral',
      'infections can also instigate sepsis.',
    ];
    final lines = [
      for (var i = 0; i < rows.length; i++)
        PdfTextLine(text: rows[i], x: 0.08, y: 0.1 + i * 0.022, w: 0.39, h: 0.016),
    ];
    final match = findAnswerOnPage(
      lines: lines,
      answer: 'False',
      prompt: 'Sepsis is most frequently caused by fungal and viral '
          'infections rather than bacterial pathogens.',
    );
    expect(match.marks, isNotEmpty);
    // The refuting sentence is the last two lines of the passage.
    expect(match.marks.first.y, greaterThan(0.1 + 5 * 0.022));
  });

  test('a verdict answer never searches for its own word', () {
    expect(searchSubject('False', 'Sepsis is caused by bacteria.').answer,
        'Sepsis is caused by bacteria.');
    expect(searchSubject('No', 'Sepsis is rare.').answer, 'Sepsis is rare.');
    expect(searchSubject('None of the above', 'Which organism?').answer,
        'Which organism?');
    // With no claim to fall back on, the answer is all there is.
    expect(searchSubject('False', '').answer, 'False');
  });

  test('searchSubject swaps in the claim only when the answer is useless', () {
    expect(searchSubject('True', 'Hypothermia is bad.').answer, 'Hypothermia is bad.');
    expect(searchSubject('Yes', 'Sepsis is dangerous.').answer, 'Sepsis is dangerous.');
    // A real answer is left alone, with the stem still available for tie-breaks.
    final kept = searchSubject('Relative bradycardia', 'Name the phenomenon.');
    expect(kept.answer, 'Relative bradycardia');
    expect(kept.prompt, 'Name the phenomenon.');
  });

  test('answerMarkers picks up acronyms as well as figures', () {
    expect(answerMarkers('Tenofovir disoproxil fumarate (TDF)'), contains('tdf'));
    expect(answerMarkers('HIV infection'), contains('hiv'));
    expect(answerMarkers('the qSOFA score'), contains('qsofa'));
    // Ordinary capitalised words are not acronyms.
    expect(answerMarkers('Relative bradycardia'), isEmpty);
  });

  test('a long claim does not offer its opening words as a phrase', () {
    final phrases = answerPhrases(
      'Patients with severe sepsis should receive intravenous antimicrobials '
      'within one hour of recognition',
    );
    expect(phrases.any((p) => p.split(' ').length <= 4), isFalse);
  });

  test('a passing mention loses to the page that teaches the term', () {
    // The reported bug: "lipoteichoic acid" appears in a list of what
    // H-ficolin binds to, on a page about complement. The same phrase appears
    // where the book explains gram-positive cell walls. Only the second
    // answers the question.
    List<PdfTextLine> page(List<String> rows) => [
          for (var i = 0; i < rows.length; i++)
            PdfTextLine(
              text: rows[i],
              x: 0.08,
              y: 0.1 + i * 0.022,
              w: 0.39,
              h: 0.016,
            ),
        ];
    final mention = page(const [
      'N-acetylneuraminic acid, lipoteichoic acid, CRP, fibrinogen, DNA,',
      'and certain corticosteroids, whereas H-ficolin binds to fucose.',
      'These sugars frequently decorate microbial surfaces but rarely',
      'appear as the terminal unit on oligosaccharides on human cells.',
    ]);
    final teaching = page(const [
      'Gram-positive bacteria carry lipoteichoic acid, a fundamental',
      'structural component of the cell wall and a well-characterised',
      'pathogen-associated molecular pattern recognised by host',
      'pattern-recognition receptors of the innate immune system.',
    ]);

    const prompt = 'Identify the pathogen-associated molecular pattern (PAMP) '
        'that forms a fundamental structural component of the cell wall in '
        'gram-positive bacteria.';
    const answer = 'Lipoteichoic acid';

    final weak = findAnswerOnPage(lines: mention, answer: answer, prompt: prompt);
    final strong =
        findAnswerOnPage(lines: teaching, answer: answer, prompt: prompt);

    expect(weak.marks, isNotEmpty, reason: 'the phrase is on both pages');
    expect(strong.marks, isNotEmpty);
    expect(strong.score, greaterThan(weak.score));
    // Only the teaching page is worth ending the search on.
    expect(strong.conclusive, isTrue);
    expect(weak.conclusive, isFalse);
  });

  test('a quoted sentence found in the file wins outright', () {
    final lines = [
      for (var i = 0; i < 4; i++)
        PdfTextLine(
          text: const [
            'N-acetylneuraminic acid, lipoteichoic acid, CRP, fibrinogen,',
            'and certain corticosteroids, whereas H-ficolin binds to fucose.',
            'Lipoteichoic acid is a fundamental structural component of the',
            'cell wall of gram-positive bacteria and acts as a PAMP.',
          ][i],
          x: 0.08,
          y: 0.1 + i * 0.022,
          w: 0.39,
          h: 0.016,
        ),
    ];
    final match = findAnswerOnPage(
      lines: lines,
      answer: 'Lipoteichoic acid',
      prompt: 'Identify the PAMP in the gram-positive cell wall.',
      quote: 'Lipoteichoic acid is a fundamental structural component of the '
          'cell wall of gram-positive bacteria',
    );
    expect(match.quoted, isTrue);
    expect(match.conclusive, isTrue);
    // The quoted sentence, not the passing mention two lines above it.
    expect(match.marks.first.y, greaterThan(0.1 + 1.5 * 0.022));
  });

  test('an invented quote is ignored, not trusted', () {
    final lines = [
      for (var i = 0; i < 3; i++)
        PdfTextLine(
          text: const [
            'Lipoteichoic acid is a component of the gram-positive cell wall',
            'and is recognised by host pattern-recognition receptors as a',
            'pathogen-associated molecular pattern.',
          ][i],
          x: 0.08,
          y: 0.1 + i * 0.022,
          w: 0.39,
          h: 0.016,
        ),
    ];
    final match = findAnswerOnPage(
      lines: lines,
      answer: 'Lipoteichoic acid',
      prompt: 'Identify the PAMP in the gram-positive cell wall.',
      quote: 'Mycolic acid forms the waxy coat of mycobacterial cell walls.',
    );
    // The quote is nowhere in the text, so it is discarded and the ordinary
    // search still finds the answer.
    expect(match.quoted, isFalse);
    expect(match.marks, isNotEmpty);
  });

  test('a quote too short to be evidence is ignored', () {
    final lines = [
      for (var i = 0; i < 3; i++)
        PdfTextLine(
          text: const [
            'Lipoteichoic acid is a component of the gram-positive cell wall',
            'and is recognised by host pattern-recognition receptors as a',
            'pathogen-associated molecular pattern.',
          ][i],
          x: 0.08,
          y: 0.1 + i * 0.022,
          w: 0.39,
          h: 0.016,
        ),
    ];
    final match = findAnswerOnPage(
      lines: lines,
      answer: 'Lipoteichoic acid',
      prompt: 'Identify the PAMP.',
      quote: 'acid is a',
    );
    expect(match.quoted, isFalse);
  });

  test('a superscript citation still ends the sentence', () {
    // The reported page. This book glues reference numbers onto the full stop
    // ("membranes.25 Microorganisms"), which read as mid-sentence and let the
    // ink run on into the next sentence and the one after it.
    const rows = [
      'An exanthem is a cutaneous eruption due to the systemic effects of',
      'a microorganism infecting the skin. An enanthem is an eruption caused',
      'in similar fashion but involving the mucous membranes.25 Microorganisms',
      'may produce eruptions through (1) multiplication in the skin (e.g.,',
    ];
    final lines = [
      for (var i = 0; i < rows.length; i++)
        PdfTextLine(text: rows[i], x: 0.08, y: 0.1 + i * 0.022, w: 0.39, h: 0.016),
    ];
    final match = findAnswerOnPage(
      lines: lines,
      answer: 'Enanthem',
      prompt: 'What medical term describes a mucosal eruption caused by '
          'systemic effects of a microorganism or toxin?',
    );
    expect(match.marks, hasLength(2));
    // Opens at "An enanthem", not at the margin.
    expect(match.marks.first.x, greaterThan(0.2));
    // Closes at "membranes." — short of the reference number and of the
    // sentence that follows it.
    expect(match.marks.last.w, lessThan(0.39 * 0.85));
  });

  test('finds nothing rather than marking an unrelated line', () {
    final match = findAnswerOnPage(
      lines: _page(),
      answer: 'mitral valve leaflet',
      prompt: 'Which structure prevents backflow into the left atrium?',
    );
    expect(match.isEmpty, isTrue);
  });

  test('an empty page yields no marks', () {
    final match = findAnswerOnPage(lines: const [], answer: 'anything');
    expect(match.isEmpty, isTrue);
  });

  test('a precise box is painted as measured, not re-guessed', () {
    const measured = QuizHighlight(
      x: 0.53,
      y: 0.40,
      w: 0.41,
      h: 0.02,
      precise: true,
    );
    expect(identical(measured.asInkStroke(), measured), isTrue);
    expect(measured.toJson()['precise'], isTrue);
    expect(QuizHighlight.tryParse(measured.toJson())?.precise, isTrue);
  });

  test('a guessed box is still snapped to one column on one line', () {
    const guess = QuizHighlight(x: 0.06, y: 0.62, w: 0.88, h: 0.14);
    expect(guess.asInkStroke().w, lessThanOrEqualTo(0.46));
  });

  test('a bibliography is never marked, however well its words score', () {
    final lines = _referenceList();
    expect(isReferenceLines(lines), isTrue);
    final match = findAnswerOnPage(
      lines: lines,
      answer: 'ribavirin',
      prompt: 'Which antiviral acts against hepatitis C virus replicons?',
    );
    expect(match.isEmpty, isTrue);
  });

  test('ordinary prose is not mistaken for a bibliography', () {
    expect(isReferenceLines(_page()), isFalse);
  });

  test('a numbered list of key points is not a bibliography', () {
    final rows = [
      for (var i = 1; i <= 12; i++) '$i. Key point number $i about the topic.',
    ];
    final lines = [
      for (var i = 0; i < rows.length; i++)
        PdfTextLine(text: rows[i], x: 0.08, y: 0.1 + i * 0.022, w: 0.39, h: 0.016),
    ];
    expect(isReferenceLines(lines), isFalse);
  });

  test('reads the folio printed in the running head', () {
    const head = PdfTextLine(text: '552 Part I  Basic Problems', x: 0.08, y: 0.04, w: 0.5, h: 0.014);
    const body = PdfTextLine(text: 'Vidarabine is an adenine analogue.', x: 0.08, y: 0.4, w: 0.39, h: 0.016);
    expect(printedFolio([head, body]), 552);
    expect(printedFolio([body]), isNull);
  });

  test('reads the folio printed in the footer', () {
    const foot = PdfTextLine(text: 'Chapter 44  777', x: 0.4, y: 0.95, w: 0.3, h: 0.014);
    expect(printedFolio([foot]), 777);
  });

  test('a resolved location survives the trip through history JSON', () {
    const question = QuizQuestion(
      kind: QuizKind.multipleChoice,
      prompt: 'Where do variola lesions predominate?',
      choices: ['On the extremities and face', 'On the trunk'],
      correctIndex: 0,
      acceptedAnswer: 'On the extremities and face',
      explanation: 'Variola produces a centrifugal rash. See page 812.',
      pageIndex: 811,
      location: QuizAnswerLocation(
        pageIndex: 811,
        marks: [QuizHighlight(x: 0.53, y: 0.4, w: 0.39, h: 0.02, precise: true)],
        exact: true,
      ),
    );
    final restored = QuizQuestion.fromJson(question.toJson());
    expect(restored.location, isNotNull);
    expect(restored.location!.pageIndex, 811);
    expect(restored.location!.exact, isTrue);
    expect(restored.location!.marks.single.precise, isTrue);
    expect(restored.location!.marks.single.x, closeTo(0.53, 0.001));
  });

  test('a location without marks is not worth storing', () {
    expect(QuizAnswerLocation.tryParse({'pageIndex': 4, 'marks': []}), isNull);
    expect(QuizAnswerLocation.tryParse(null), isNull);
  });

  test('firstCitedPageIndex reads the citation the student sees', () {
    expect(firstCitedPageIndex('Trapped debris. See page 865.'), 864);
    expect(firstCitedPageIndex('No citation here.'), isNull);
  });

  test('the indexed-text gate skips pages that cannot hold the answer', () {
    const page = 'telbivudine does not seem to be metabolized by the cyp450 '
        'isoenzymes. clinical studies in patients with hepatitis b.';
    expect(pageMightHoldAnswer(page, answer: 'Relative bradycardia'), isFalse);
    expect(pageMightHoldAnswer(page, answer: 'telbivudine dosing'), isTrue);
    // A page with no extracted text can never be ruled out on it.
    expect(pageMightHoldAnswer('', answer: 'Relative bradycardia'), isTrue);
  });

  test('the gate keeps pages that carry the figures in the answer', () {
    const page = 'an early-morning core temperature of 37.2 c (99.0 f) or '
        'greater defines fever.';
    expect(pageMightHoldAnswer(page, answer: '>=37.2 C (99.0 F)'), isTrue);
  });

  test('two columns sharing a baseline become two lines, not one', () {
    // PDFium reports glyphs in reading order; the left and right columns of a
    // textbook page sit at the same height. Treating them as one line is what
    // painted a highlight straight across the gutter.
    final left = _glyphs('The commensal microbes', x: 0.08, y: 0.30);
    final right = _glyphs('regulate metabolism', x: 0.53, y: 0.30);
    final lines = linesFromCharBoxes(
      text: left.text + right.text,
      boxes: [...left.boxes, ...right.boxes],
    );
    expect(lines, hasLength(2));
    expect(lines[0].text, 'The commensal microbes');
    expect(lines[0].x + lines[0].w, lessThan(0.5));
    expect(lines[1].text, 'regulate metabolism');
    expect(lines[1].x, greaterThan(0.5));
  });

  test('a newline and a new baseline both end a line', () {
    final first = _glyphs('first line', x: 0.08, y: 0.30);
    final second = _glyphs('second line', x: 0.08, y: 0.32);
    final third = _glyphs('third line', x: 0.08, y: 0.34);
    final lines = linesFromCharBoxes(
      text: '${first.text}\n${second.text}${third.text}',
      boxes: [
        ...first.boxes,
        const CharBox(x: 0, y: 0, w: 0, h: 0),
        ...second.boxes,
        ...third.boxes,
      ],
    );
    expect(lines.map((l) => l.text), ['first line', 'second line', 'third line']);
  });

  test('a mark is measured from the matched glyphs, not estimated', () {
    // Proportional type: a "W" here is three times the width of anything
    // else. Estimating the match position from the fraction of the line it
    // covers assumes they are equal, and lands the ink in the wrong place.
    const text = 'WWWW; illness; WWWW';
    final boxes = <CharBox>[];
    var x = 0.10;
    for (final char in text.split('')) {
      final w = char == 'W' ? 0.012 : 0.004;
      boxes.add(CharBox(x: x, y: 0.20, w: w, h: 0.016));
      x += w;
    }
    final lines = linesFromCharBoxes(text: text, boxes: boxes);
    expect(lines.single.chars, hasLength(text.length));

    final match = findAnswerOnPage(lines: lines, answer: 'illness');
    expect(match.marks, hasLength(1));
    final mark = match.marks.single;
    // The clause is "illness;" — four Ws, a semicolon and a space in front of
    // it, so it opens at 0.10 + 4*0.012 + 0.004 + 0.004, less the padding.
    expect(mark.x, closeTo(0.156 - 0.004, 0.003));
    // Eight characters of it, at 0.004 each, plus the padding.
    expect(mark.x + mark.w, closeTo(0.156 + 8 * 0.004 + 0.004, 0.003));
  });

  test('a line box is the union of its glyph boxes', () {
    final run = _glyphs('measured', x: 0.10, y: 0.20);
    final lines = linesFromCharBoxes(text: run.text, boxes: run.boxes);
    expect(lines, hasLength(1));
    expect(lines.single.x, closeTo(0.10, 0.0001));
    expect(lines.single.y, closeTo(0.20, 0.0001));
    expect(lines.single.w, closeTo(0.006 * 'measured'.length, 0.0001));
    expect(lines.single.h, closeTo(0.016, 0.0001));
  });
}
