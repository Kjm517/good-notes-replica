/// Prompt for replacing exactly one question.
///
/// "Regenerate question 5" must not become "read the textbook again". The
/// whole point is that everything already known about the document — its
/// extracted text, its figures, the other 24 questions — stays put, and the
/// only new work is one small call about one page.
///
/// Kept as a pure function so the cost-shaping can be tested: the guarantees
/// that matter are that exactly one page's text is sent, exactly one question
/// is asked for, and the answer already rejected is named so it is not
/// returned again.
library;

/// Roughly a page of prose. Enough to write a question from, small enough that
/// a regeneration costs a fraction of a full generation.
const int kSingleQuestionContextChars = 6000;

String buildSingleQuestionPrompt({
  required String pageText,
  required int pageIndex,
  required String kind,
  required String difficulty,
  /// Questions already in the quiz, so the replacement is not a duplicate.
  List<String> avoidPrompts = const [],
  /// The answer the student rejected, when they asked for a different item.
  String? rejectedAnswer,
}) {
  final trimmed = pageText.trim().length > kSingleQuestionContextChars
      ? '${pageText.trim().substring(0, kSingleQuestionContextChars)}…'
      : pageText.trim();

  final avoid = avoidPrompts
      .where((p) => p.trim().isNotEmpty)
      .take(12)
      .map((p) => '- $p')
      .join('\n');

  return '''
Write exactly ONE $kind question at $difficulty difficulty, from the page below.

Return a single JSON object, not an array, not wrapped in prose:
{"kind":"$kind","prompt":"…","choices":[],"correctIndex":0,"acceptedAnswer":"…","explanation":"2 sentences of fact, then See page ${pageIndex + 1}.","pageIndex":$pageIndex}

Rules
- Answer only from the page text below. Do not use outside knowledge.
- The question must stand on its own: never write "according to the passage"
  or "as shown above", because the student is not shown the page.
${rejectedAnswer != null && rejectedAnswer.trim().isNotEmpty ? '- Do NOT ask about "$rejectedAnswer" again; that item was rejected.\n' : ''}${avoid.isNotEmpty ? '- Do not repeat any of these questions:\n$avoid\n' : ''}
PAGE ${pageIndex + 1}
$trimmed
''';
}
