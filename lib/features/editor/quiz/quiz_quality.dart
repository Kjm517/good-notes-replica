import 'quiz_models.dart';

/// Bibliography, running heads, and author lists make nonsense quiz items.
final _sourceJunk = RegExp(
  r'\bet al\.?\b|\bdoi\s*:|\bpmid\b|\bisbn\b|\bcopyright\b|'
  r'\bvol\.\s*\d|\bpp\.\s*\d|\bsuppl\b|\bhttps?://|\bwww\.|'
  r'\bfigure\s+\d|\bfig\.\s*\d|\btable\s+\d|'
  r'results from the sentry|\bj bacteriol\b|\bjournal of\b|'
  r'\breferences\b|\backnowledg(e)?ments\b',
  caseSensitive: false,
);

/// Same as source junk, but figure/table mentions are allowed in questions
/// about illustrations.
final _questionJunk = RegExp(
  r'\bet al\.?\b|\bdoi\s*:|\bpmid\b|\bisbn\b|\bcopyright\b|'
  r'\bvol\.\s*\d|\bpp\.\s*\d|\bsuppl\b|\bhttps?://|\bwww\.|'
  r'results from the sentry|\bj bacteriol\b|\bjournal of\b|'
  r'\breferences\b|\backnowledg(e)?ments\b',
  caseSensitive: false,
);

/// "kirimanjeswara gs, golden jm, bakshi cs"
final _authorList = RegExp(
  r'[a-z][a-z\-]+ [a-z]{1,3},\s+[a-z][a-z\-]+ [a-z]{1,3},\s+[a-z]',
  caseSensitive: false,
);

final _verb = RegExp(
  r'\b(is|are|was|were|be|been|being|has|have|had|does|do|did|'
  r'can|may|might|should|must|will|would|'
  r'cause[sd]?|include[sd]?|contain[sd]?|consist[s]?|'
  r'produce[sd]?|prevent[sd]?|inhibit[sd]?|bind[s]?|bound|'
  r'encode[sd]?|occur[s]?|lead[s]?|allow[s]?|require[sd]?|'
  r'involve[sd]?|mean[s]?|called|used|found|located|'
  r'composed|responsible|generate[sd]?|synthesi[sz]e[sd]?|'
  r'package[sd]?|digest[s]?|store[sd]?|control[s]?|'
  r'transport[s]?|function[s]?|act[s]?)\b',
  caseSensitive: false,
);

/// Questions that cannot be answered without looking at the page.
///
/// The quiz shows the student words, never the page, so "the assay in diagram
/// B of Figure 5.4" is unanswerable however good the question is. Gemini is
/// told to write self-contained items; this is the backstop for the ones that
/// still come back pointing at a picture.
final _needsTheFigure = RegExp(
  r'\bfig(ure|\.)\s*\d|\bdiagram\b|\bflowchart\b|\billustration\b|'
  r'\bmicrograph\b|\bphotograph\b|\bthe (image|picture|drawing|photo)\b|'
  r'\btable\s*\d|\bpanel\s*[a-d0-9]\b|\blabell?ed\s+[a-d0-9]\b|'
  r'\bshown (in|above|below|here)\b|\bdepicted\b|\bthis page\b|'
  r'\babove\b\s*[.?]?$',
  caseSensitive: false,
);

/// True when the question leans on a figure the student never sees.
bool needsUnseenFigure(String prompt) => _needsTheFigure.hasMatch(prompt);

final _cloze = RegExp(
  r'completes this sentence|fill in the blank|______|from the document',
  caseSensitive: false,
);

/// Stems that paste a source clause after "which of the following".
final _pastedPredicateStem = RegExp(
  r'^which of the following (is|are|was|were|has|have|does|do) \w.{40,}',
  caseSensitive: false,
);

final _whichOfTheFollowing = RegExp(
  r'^which of the following\b',
  caseSensitive: false,
);

final _teaching = RegExp(
  r'\b(because|therefore|indicates|means|characteristic|consistent|'
  r'defined as|caused by|unlike|however|'
  r'illustration|diagram|labeled|depicts?|shown|called|located|'
  r'typically|occurs?|produces?|functions?|consists?|known as|fact)\b',
  caseSensitive: false,
);

final _metaExplain = RegExp(
  r'the correct statement is|this statement is true|this statement is false|'
  r'this is the correct|the right answer|the answer is\b|'
  r'the other options (change|are wrong)|not what the material says',
  caseSensitive: false,
);

const _genericAnswers = {
  'eye', 'eyes', 'patient', 'patients', 'people', 'person', 'persons',
  'study', 'studies', 'result', 'results', 'chapter', 'section',
  'figure', 'table', 'author', 'authors', 'disease', 'treatment',
  'case', 'cases', 'data', 'method', 'methods', 'introduction',
  'others', 'none', 'both', 'all',
};

/// True when [text] looks like a teachable fact, not a citation or heading.
bool isQuizWorthyText(String raw) {
  final text = raw.trim();
  if (text.length < 40) return false;
  final lower = text.toLowerCase();
  if (_sourceJunk.hasMatch(lower) || _authorList.hasMatch(lower)) return false;
  final words = lower.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
  if (words.length < 8 || words.length > 42) return false;
  final initials =
      words.where((w) => RegExp(r'^[a-z]{1,2},?$').hasMatch(w)).length;
  if (initials >= 3) return false;
  if (!_verb.hasMatch(lower)) return false;
  return true;
}

/// Contributor lists, TOCs, and title-page credits are not quiz source.
bool isFrontMatterPage(String raw) {
  final text = raw.toLowerCase();
  if (RegExp(r'\b(contributors?|table of contents|associate editors?|'
          r'consulting editors?|section editors?)\b')
      .hasMatch(text)) {
    return true;
  }
  final credentials =
      RegExp(r'\b(md|phd|mph|msc|dsc)\b').allMatches(text).length;
  return credentials >= 4;
}

/// Bibliography / reference pages where text concentrates at the top and the
/// rest is blank — highlight strokes would sit in empty whitespace.
bool isReferencePage(String raw) {
  final text = raw.toLowerCase();
  if (RegExp(r'\b(references|bibliography)\s*\n').hasMatch(text)) return true;
  final lines = raw.split(RegExp(r'\r?\n')).where((l) => l.trim().isNotEmpty);
  var refLines = 0;
  var total = 0;
  for (final line in lines) {
    total++;
    final l = line.toLowerCase();
    if (RegExp(r'\bet al\.?\b').hasMatch(l) ||
        RegExp(r'\bdoi\s*:').hasMatch(l) ||
        RegExp(r'\bhttps?://').hasMatch(l) ||
        RegExp(r'\bvol\.\s*\d').hasMatch(l) ||
        RegExp(r'\bpp\.\s*\d').hasMatch(l) ||
        RegExp(r'\[\d+\]').hasMatch(l) ||
        RegExp(r'^\d{1,3}\.\s').hasMatch(l.trim()) ||
        RegExp(r'\bjournal of\b').hasMatch(l)) {
      refLines++;
    }
  }
  if (total >= 5 && refLines / total >= 0.55) return true;
  return false;
}

/// Drops cloze, citation, generic-choice, and circular-explanation items.
bool isExamStyleQuestion(QuizQuestion question) {
  final blob =
      '${question.prompt}\n${question.choices.join('\n')}\n${question.acceptedAnswer}';
  if (_cloze.hasMatch(blob)) return false;
  if (_questionJunk.hasMatch(blob) || _authorList.hasMatch(blob)) return false;
  final prompt = question.prompt.trim();

  final identification = question.kind == QuizKind.identification;
  // Identification is the one kind that legitimately points at a figure — the
  // student is looking at it — so the "unseen figure" and stem rules that
  // protect the text kinds would reject every valid item. Its prompts are also
  // short by design ("What is the marked structure?").
  if (!identification) {
    if (prompt.length < 20) return false;
    if (needsUnseenFigure(prompt)) return false;
  }
  if (!identification && _whichOfTheFollowing.hasMatch(prompt)) return false;
  if (!identification && _pastedPredicateStem.hasMatch(prompt)) return false;
  if (question.explanation.trim().length < 40) return false;
  if (_metaExplain.hasMatch(question.explanation)) return false;
  // Long factual explanations don't always use "because" / "fact". Only
  // reject short ones that also lack a teaching cue — that filter was
  // dropping most of a 25-question set.
  if (question.explanation.trim().length < 80 &&
      !_teaching.hasMatch(question.explanation)) {
    return false;
  }

  // The marker is what makes the item answerable, so it is mandatory here.
  if (identification) {
    final hl = question.highlight;
    if (hl == null) return false;
    // A box over half the page points at nothing.
    if (hl.w > 0.5 || hl.h > 0.5) return false;
    if (question.choices.isNotEmpty) return false;
    final answer = question.acceptedAnswer.trim();
    if (answer.isEmpty || isGenericAnswer(answer)) return false;
    // A prompt naming the answer gives the whole thing away.
    if (prompt.toLowerCase().contains(answer.toLowerCase())) return false;
  }

  if (question.kind == QuizKind.multipleChoice) {
    if (question.choices.length != 4) return false;
    if (question.choices.toSet().length != 4) return false;
    if (isGenericAnswer(question.acceptedAnswer)) return false;
    var genericChoices = 0;
    for (final choice in question.choices) {
      if (isGenericAnswer(choice)) genericChoices++;
      if (_wordCount(choice) < 3 && isGenericAnswer(choice)) return false;
    }
    if (genericChoices >= 2) return false;
  }

  if (question.kind == QuizKind.trueFalse) {
    if (!prompt.contains(' ') || _wordCount(prompt) < 8) return false;
  }
  return true;
}

bool isGenericAnswer(String raw) {
  var text = raw.trim().toLowerCase();
  text = text.replaceFirst(RegExp(r'^the\s+'), '');
  text = text.replaceAll(RegExp(r'[.?!]+$'), '');
  if (_genericAnswers.contains(text)) return true;
  final words = text.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
  if (words.length == 1 && words.first.length <= 5) {
    return _genericAnswers.contains(words.first);
  }
  return false;
}

int _wordCount(String raw) =>
    raw.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty).length;

String capitalizeSentence(String raw) {
  final text = raw.trim();
  if (text.isEmpty) return text;
  return '${text[0].toUpperCase()}${text.substring(1)}';
}

String titleCaseTerm(String raw) {
  return raw
      .trim()
      .split(RegExp(r'\s+'))
      .where((w) => w.isNotEmpty)
      .map((w) => '${w[0].toUpperCase()}${w.substring(1)}')
      .join(' ');
}
