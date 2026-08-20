import 'package:flutter/services.dart';

import '../../../core/ai/gemini_service.dart';
import 'quiz_models.dart';
import 'quiz_quality.dart';

final _seePageRe = RegExp(r'See\s+pages?\s+\d+\.?', caseSensitive: false);

const kQuizStopWordsAsset = 'assets/quiz/stop_words.txt';

Set<String> _stop = {};
var _stopLoaded = false;

/// Parses one-word-per-line lists. Lines starting with `#` are ignored.
Set<String> parseQuizStopWords(String raw) => {
      for (final line in raw.split(RegExp(r'\r?\n')))
        if (line.trim().isNotEmpty && !line.trim().startsWith('#'))
          line.trim().toLowerCase(),
    };

/// Loads stop words from [kQuizStopWordsAsset], or [contents] in tests.
Future<Set<String>> loadQuizStopWords({String? contents}) async {
  if (contents != null) {
    _stop = parseQuizStopWords(contents);
    _stopLoaded = true;
    return _stop;
  }
  if (_stopLoaded) return _stop;
  final raw = await rootBundle.loadString(kQuizStopWordsAsset);
  _stop = parseQuizStopWords(raw);
  _stopLoaded = true;
  return _stop;
}

Set<String> get quizStopWords => _stop;

/// Distinctive words from the answer (and prompt) used to find the source page.
List<String> answerSearchTerms(String answer, [String prompt = '']) {
  final stop = quizStopWords;
  final blob = '$answer $prompt'.toLowerCase().replaceAll(
        RegExp(r'[^a-z0-9\s-]'),
        ' ',
      );
  final seen = <String>{};
  final out = <String>[];
  for (final word in blob.split(RegExp(r'\s+'))) {
    if (word.length < 5 || stop.contains(word) || !seen.add(word)) continue;
    out.add(word);
  }
  out.sort((a, b) => b.length.compareTo(a.length));
  return out.take(8).toList();
}

int scorePageForTerms(String pageText, List<String> terms) {
  if (terms.isEmpty || pageText.isEmpty) return 0;
  final lower = pageText.toLowerCase();
  var score = 0;
  for (final term in terms) {
    if (lower.contains(term)) score += term.length >= 8 ? 2 : 1;
  }
  return score;
}

int firstTermOffset(String pageText, List<String> terms) {
  final lower = pageText.toLowerCase();
  for (final term in terms) {
    final i = lower.indexOf(term);
    if (i >= 0) return i;
  }
  return 0;
}

/// Rough two-column layout: first half of extracted text is the left column.
QuizHighlight highlightForTextOffset(String pageText, int offset) {
  final len = pageText.isEmpty ? 1 : pageText.length;
  final frac = (offset / len).clamp(0.0, 0.97);
  final left = frac < 0.5;
  final along = left ? frac * 2 : (frac - 0.5) * 2;
  return QuizHighlight(
    x: left ? 0.07 : 0.53,
    y: (0.08 + along * 0.74).clamp(0.06, 0.82),
    w: 0.39,
    h: 0.019,
  );
}

String rewriteSeePage(String explanation, int pageIndex) {
  final cite = 'See page ${pageIndex + 1}.';
  final text = explanation.trim();
  if (text.isEmpty) return cite;
  if (_seePageRe.hasMatch(text)) {
    return text.replaceFirst(_seePageRe, cite);
  }
  return '$text $cite';
}

/// Moves [question] onto the page whose text actually contains the answer,
/// and draws the highlighter there — not on a contributor list Gemini guessed.
QuizQuestion alignQuestionToSource(
  QuizQuestion question,
  List<QuizSourcePage> pages,
) {
  if (pages.isEmpty) return question;
  final terms = answerSearchTerms(question.acceptedAnswer, question.prompt);
  if (terms.isEmpty) {
    return question.copyWith(clearHighlight: true);
  }

  QuizSourcePage? best;
  var bestScore = 0;
  for (final page in pages) {
    if (isReferencePage(page.text)) continue;
    final score = scorePageForTerms(page.text, terms);
    if (score > bestScore) {
      bestScore = score;
      best = page;
    }
  }
  if (best == null || bestScore < 2) {
    return question.copyWith(clearHighlight: true);
  }

  final offset = firstTermOffset(best.text, terms);
  return question.copyWith(
    pageIndex: best.pageIndex,
    highlight: highlightForTextOffset(best.text, offset),
    explanation: rewriteSeePage(question.explanation, best.pageIndex),
  );
}

List<QuizQuestion> alignQuestionsToSource(
  List<QuizQuestion> questions,
  List<QuizSourcePage> pages,
) =>
    [for (final q in questions) alignQuestionToSource(q, pages)];
