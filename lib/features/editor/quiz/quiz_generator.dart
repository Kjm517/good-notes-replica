import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';

import '../../../core/ai/gemini_service.dart';
import 'quiz_align.dart';
import '../../../core/sync/user_telemetry.dart';
import 'quiz_models.dart';
import 'quiz_quality.dart';

/// True when extracted text is too thin and Gemini should read page images
/// instead (scans, photos, slides, image-only PDFs).
bool shouldUsePageImages({
  required List<QuizSourcePage> compactText,
  required bool hasPageImages,
}) {
  if (!hasPageImages) return false;
  final chars = compactText.fold<int>(0, (n, p) => n + p.text.length);
  return compactText.length < 2 || chars < 500;
}

/// Extra items requested on the first pass so the exam-style filter can drop
/// a few without shrinking a 25-question quiz to 5–8.
int quizOversampleCount(int wanted) {
  if (wanted <= 0) return 0;
  return max(wanted, (wanted * 1.4).ceil());
}

/// Builds an exam-style quiz with Gemini. Offline requests are queued in the UI.
///
/// Gemini often returns fewer than asked (thinking tokens, truncated JSON),
/// and [keepExamStyle] drops stems that fail the exam-style rules. We oversample
/// and top up so the student actually gets [QuizConfig.count].
Future<List<QuizQuestion>> generateExamQuiz({
  required List<SourcePassage> passages,
  required QuizConfig config,
  required AiQuizGenerator ai,
  String? additionalInstructions,
  List<QuizSourceImage> images = const [],
}) async {
  final pages = compactQuizPages(passages);
  if (pages.isEmpty && images.isEmpty) {
    throw StateError(
      'No readable text or page images to quiz from.',
    );
  }
  await loadQuizStopWords();

  final wanted = config.count;
  final kept = <QuizQuestion>[];
  final seen = <String>{};

  for (var round = 0; round < 3 && kept.length < wanted; round++) {
    final need = wanted - kept.length;
    final ask = round == 0 ? quizOversampleCount(wanted) : min(wanted, need + 4);
    var extra = additionalInstructions;
    if (seen.isNotEmpty) {
      final avoid = seen.take(24).map((p) => '- $p').join('\n');
      extra = [
        if (additionalInstructions != null &&
            additionalInstructions.trim().isNotEmpty)
          additionalInstructions.trim(),
        'Do not repeat these questions:\n$avoid',
        'Write $ask NEW questions. Return exactly $ask items.',
      ].join('\n\n');
    }
    final raw = await ai.generate(
      textPages: pages,
      images: images,
      config: config.copyWith(count: ask),
      additionalInstructions: extra,
    );
    final batch = keepRequestedKinds(
      keepExamStyle(alignQuestionsToSource(raw, pages)),
      config.kinds,
    );
    debugPrint(
      'Quiz round ${round + 1}: asked $ask, parsed ${raw.length}, '
      'usable ${batch.length}',
    );
    for (final q in batch) {
      final key = q.prompt.toLowerCase().replaceAll(RegExp(r'\s+'), ' ').trim();
      if (key.isEmpty || !seen.add(key)) continue;
      kept.add(q);
      if (kept.length >= wanted) break;
    }
  }

  if (kept.isEmpty) {
    throw StateError(
      'Gemini did not return usable exam questions. Try again.',
    );
  }
  return kept.take(wanted).toList();
}

List<QuizQuestion> keepExamStyle(List<QuizQuestion> questions) => [
      for (final q in questions)
        if (isExamStyleQuestion(q)) q,
    ];

List<QuizQuestion> keepRequestedKinds(
  List<QuizQuestion> questions,
  Set<QuizKind> kinds,
) {
  if (kinds.isEmpty) return questions;
  return [for (final q in questions) if (kinds.contains(q.kind)) q];
}

List<QuizSourcePage> compactQuizPages(
  List<SourcePassage> passages, {
  int maxChars = 18000,
}) {
  final out = <QuizSourcePage>[];
  var used = 0;
  for (final p in passages) {
    final kept = [
      for (final raw in p.sentence.split(RegExp(r'(?<=[.?!])\s+')))
        if (isQuizWorthyText(raw)) raw.trim(),
    ].join(' ');
    var text = kept.isNotEmpty ? kept : p.sentence.trim();
    if (text.isEmpty) continue;
    if (isFrontMatterPage(text)) continue;
    if (text.length > 2500) text = text.substring(0, 2500);
    if (used + text.length > maxChars && out.isNotEmpty) break;
    out.add(QuizSourcePage(pageIndex: p.pageIndex, text: text));
    used += text.length;
  }
  return out;
}

// ---------------------------------------------------------------------------
// AI-powered quiz generator (Gemini)
// ---------------------------------------------------------------------------

/// Generates quiz questions using the Gemini AI API.
class AiQuizGenerator {
  AiQuizGenerator(this._gemini, {Random? random}) : _random = random ?? Random();

  final GeminiService _gemini;
  final Random _random;

  /// Generates from text, page images, or both in one Gemini call.
  Future<List<QuizQuestion>> generate({
    List<QuizSourcePage> textPages = const [],
    List<QuizSourceImage> images = const [],
    required QuizConfig config,
    String? additionalInstructions,
  }) async {
    final result = await _gemini.generateQuiz(
      textPages: textPages,
      images: images,
      questionCount: config.count,
      questionKinds: config.kinds.map(_kindName).toSet(),
      difficulty: _difficultyName(config.difficulty),
      additionalInstructions: additionalInstructions,
    );
    unawaited(UserTelemetry.recordAiUsage(
      feature: 'quiz',
      promptTokens: result.promptTokenCount,
      outputTokens: result.candidatesTokenCount,
    ));
    return _parseResponse(result.text, config);
  }

  /// Generates questions from pre-extracted PDF text.
  Future<List<QuizQuestion>> generateFromText({
    required List<QuizSourcePage> textPages,
    required QuizConfig config,
    String? additionalInstructions,
    List<QuizSourceImage> images = const [],
  }) {
    return generate(
      textPages: textPages,
      images: images,
      config: config,
      additionalInstructions: additionalInstructions,
    );
  }

  /// Generates questions from image bytes (PPT slides, scanned pages).
  Future<List<QuizQuestion>> generateFromImages({
    required List<QuizSourceImage> images,
    required QuizConfig config,
    String? additionalInstructions,
  }) {
    return generate(
      images: images,
      config: config,
      additionalInstructions: additionalInstructions,
    );
  }

  /// Parses the JSON array returned by Gemini into [QuizQuestion] objects.
  List<QuizQuestion> _parseResponse(String text, QuizConfig config) {
    final decoded = decodeQuizQuestionArray(text);
    if (decoded.isEmpty) {
      throw FormatException('Expected JSON array of quiz questions');
    }

    final questions = <QuizQuestion>[];
    for (final item in decoded) {
      if (item is! Map) continue;
      try {
        questions.add(
          _parseQuestion(Map<String, dynamic>.from(item))
              .withShuffledChoices(_random),
        );
      } catch (e) {
        debugPrint('Skipping malformed quiz question: $e');
      }
    }
    return questions;
  }

  QuizQuestion _parseQuestion(Map<String, dynamic> json) {
    final kindStr = json['kind'] as String? ?? 'multipleChoice';
    final kind = switch (kindStr) {
      'multipleChoice' => QuizKind.multipleChoice,
      'trueFalse' => QuizKind.trueFalse,
      'shortAnswer' => QuizKind.shortAnswer,
      'identification' => QuizKind.identification,
      _ => QuizKind.multipleChoice,
    };

    final choices = (json['choices'] as List?)
            ?.map((e) => e.toString())
            .toList() ??
        [];

    return QuizQuestion(
      kind: kind,
      prompt: json['prompt'] as String? ?? '',
      choices: choices,
      correctIndex: (json['correctIndex'] as num?)?.toInt() ?? 0,
      acceptedAnswer: json['acceptedAnswer'] as String? ?? '',
      explanation: json['explanation'] as String? ?? '',
      pageIndex: (json['pageIndex'] as num?)?.toInt() ?? 0,
      sourceQuote: (json['sourceQuote'] ?? json['quote'] ?? '').toString().trim(),
      highlight: QuizHighlight.tryParse(
        json['highlight'] ??
            json['bbox'] ??
            json['box'] ??
            json['sourceBox'] ??
            json['sourceRect'],
      ),
    );
  }

  String _kindName(QuizKind kind) => switch (kind) {
        QuizKind.multipleChoice => 'multipleChoice',
        QuizKind.trueFalse => 'trueFalse',
        QuizKind.shortAnswer => 'shortAnswer',
        QuizKind.identification => 'identification',
      };

  String _difficultyName(QuizDifficulty d) => switch (d) {
        QuizDifficulty.easy => 'easy',
        QuizDifficulty.medium => 'medium',
        QuizDifficulty.hard => 'hard',
      };
}

// ---------------------------------------------------------------------------
// Local generator (tests only — the quiz UI always uses Gemini)
// ---------------------------------------------------------------------------

/// Builds exam-style questions from extracted PDF text without a network call.
class LocalQuizGenerator {
  LocalQuizGenerator({Random? random}) : _random = random ?? Random();

  final Random _random;

  static final _sentenceSplit = RegExp(r'(?<=[.?!])\s+');
  static final _wordSplit = RegExp(r"[^\w']+");
  static const _stop = {
    'about', 'after', 'also', 'because', 'before', 'being', 'between',
    'could', 'during', 'every', 'from', 'have', 'their', 'there', 'these',
    'those', 'through', 'under', 'until', 'using', 'which', 'while', 'with',
    'would', 'other', 'into', 'than', 'them', 'then', 'this', 'that', 'what',
    'when', 'where', 'your', 'they', 'were', 'been', 'more', 'some', 'such',
    'inside', 'across',
  };

  List<QuizQuestion> generate({
    required List<SourcePassage> passages,
    required QuizConfig config,
  }) {
    final sentences = <SourcePassage>[];
    for (final passage in passages) {
      for (final raw in passage.sentence.split(_sentenceSplit)) {
        final sentence = raw.trim();
        if (_usable(sentence, config.difficulty)) {
          sentences.add(SourcePassage(
            pageIndex: passage.pageIndex,
            sentence: sentence,
          ));
        }
      }
    }
    if (sentences.isEmpty) return const [];

    sentences.shuffle(_random);
    // Identification is deliberately absent here: this path only has sentences,
    // and an identification item without a figure to point at is unanswerable.
    // Asking for it alone falls back to multiple choice rather than returning
    // an empty quiz.
    final kinds = {
      for (final kind in config.kinds)
        if (kind != QuizKind.identification) kind,
    };
    final kindList = (kinds.isEmpty ? {QuizKind.multipleChoice} : kinds).toList();
    final out = <QuizQuestion>[];
    final used = <String>{};

    var i = 0;
    while (out.length < config.count && i < sentences.length * 4) {
      final source = sentences[i % sentences.length];
      i++;
      if (!used.add(source.sentence.toLowerCase())) continue;
      final kind = kindList[out.length % kindList.length];
      final question = switch (kind) {
        QuizKind.multipleChoice => _multipleChoice(source, sentences),
        QuizKind.trueFalse => _trueFalse(source, sentences),
        QuizKind.shortAnswer => _shortAnswer(source),
        // Unreachable — filtered out of kindList above.
        QuizKind.identification => null,
      };
      if (question != null && isExamStyleQuestion(question)) out.add(question);
    }
    return out;
  }

  bool _usable(String sentence, QuizDifficulty difficulty) {
    if (!isQuizWorthyText(sentence)) return false;
    final words = sentence.split(RegExp(r'\s+'));
    final (minW, maxW) = switch (difficulty) {
      QuizDifficulty.easy => (6, 22),
      QuizDifficulty.medium => (8, 32),
      QuizDifficulty.hard => (10, 40),
    };
    return words.length >= minW && words.length <= maxW;
  }

  QuizQuestion? _multipleChoice(
    SourcePassage source,
    List<SourcePassage> pool,
  ) {
    final topic = _topic(source.sentence);
    if (topic == null || isGenericAnswer(topic)) return null;
    final trueClaim = capitalizeSentence(_asClaim(source.sentence));
    if (_wordCount(trueClaim) < 8) return null;

    final falseClaims = <String>{};
    for (final other in pool) {
      final otherTopic = _topic(other.sentence);
      if (otherTopic == null) continue;
      if (otherTopic.toLowerCase() == topic.toLowerCase()) continue;
      final swapped = capitalizeSentence(
        _asClaim(
          source.sentence.replaceFirst(
            RegExp(RegExp.escape(topic), caseSensitive: false),
            otherTopic,
          ),
        ),
      );
      if (swapped.toLowerCase() == trueClaim.toLowerCase()) continue;
      if (_wordCount(swapped) < 8) continue;
      falseClaims.add(swapped);
      if (falseClaims.length >= 3) break;
    }
    if (falseClaims.length < 3) return null;

    final options = [...falseClaims.take(3), trueClaim]..shuffle(_random);
    const stems = [
      'What is the correct statement?',
      'What does the material state?',
      'When is this description accurate?',
      'Where does this fact belong?',
      'Why is this the right description?',
    ];
    return QuizQuestion(
      kind: QuizKind.multipleChoice,
      prompt: stems[_random.nextInt(stems.length)],
      choices: options,
      correctIndex: options.indexOf(trueClaim),
      acceptedAnswer: trueClaim,
      explanation:
          'Fact: ${capitalizeSentence(_asClaim(source.sentence))} '
          'See page ${source.pageIndex + 1}.',
      pageIndex: source.pageIndex,
    );
  }

  QuizQuestion? _trueFalse(SourcePassage source, List<SourcePassage> pool) {
    final topic = _topic(source.sentence);
    var statement = capitalizeSentence(source.sentence);
    var correctTrue = true;
    if (_random.nextBool() && topic != null) {
      final others = pool
          .map((p) => _topic(p.sentence))
          .whereType<String>()
          .where((t) => t.toLowerCase() != topic.toLowerCase())
          .toList();
      if (others.isNotEmpty) {
        final wrong = others[_random.nextInt(others.length)];
        statement = capitalizeSentence(
          source.sentence.replaceFirst(
            RegExp(RegExp.escape(topic), caseSensitive: false),
            wrong,
          ),
        );
        correctTrue = false;
      }
    }
    return QuizQuestion(
      kind: QuizKind.trueFalse,
      prompt: _asClaim(statement),
      choices: const ['True', 'False'],
      correctIndex: correctTrue ? 0 : 1,
      acceptedAnswer: correctTrue ? 'True' : 'False',
      explanation: _explain(
        source,
        'Fact: ${capitalizeSentence(_asClaim(source.sentence))}',
      ),
      pageIndex: source.pageIndex,
    );
  }

  QuizQuestion? _shortAnswer(SourcePassage source) {
    final topic = _topic(source.sentence);
    final fact = _factAfterTopic(source.sentence, topic);
    if (topic == null || fact == null) return null;
    if (isGenericAnswer(topic)) return null;
    final answer = titleCaseTerm(topic);
    final claim = capitalizeSentence(_asClaim(fact));
    final prompt = switch (_random.nextInt(4)) {
      0 => 'What do you call the following?\n\n$claim',
      1 => 'What is the term for this description?\n\n$claim',
      2 => 'What are we referring to here?\n\n$claim',
      _ => 'What term does the material describe as follows?\n\n$claim',
    };
    return QuizQuestion(
      kind: QuizKind.shortAnswer,
      prompt: prompt,
      choices: const [],
      correctIndex: 0,
      acceptedAnswer: answer,
      explanation:
          'Fact: $answer is known as the structure that does this because '
          '$claim '
          'See page ${source.pageIndex + 1}.',
      pageIndex: source.pageIndex,
    );
  }

  int _wordCount(String raw) =>
      raw.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty).length;

  String _explain(SourcePassage source, String fact) {
    return '${capitalizeSentence(fact)} '
        'See page ${source.pageIndex + 1} of the material.';
  }

  String? _topic(String sentence) {
    final tokens = sentence.split(RegExp(r'\s+'));
    final start = <String>[];
    for (final token in tokens) {
      final word = token.replaceAll(_wordSplit, '');
      if (word.isEmpty) continue;
      if (_looksLikeVerb(word)) break;
      final lower = word.toLowerCase();
      if (_stop.contains(lower)) {
        if (start.isEmpty) continue;
        break;
      }
      start.add(word);
      if (start.length >= 3) break;
    }
    if (start.isEmpty) return null;
    return start.join(' ');
  }

  bool _looksLikeVerb(String word) {
    return RegExp(
      r'^(is|are|was|were|be|been|being|has|have|had|does|do|did|'
      r'can|may|might|should|must|will|would|'
      r'cause[sd]?|include[sd]?|contain[sd]?|consist[s]?|'
      r'produce[sd]?|prevent[sd]?|inhibit[sd]?|bind[s]?|bound|'
      r'encode[sd]?|occur[s]?|lead[s]?|allow[s]?|require[sd]?|'
      r'involve[sd]?|mean[s]?|called|used|found|located|'
      r'composed|responsible|generate[sd]?|synthesi[sz]e[sd]?|'
      r'package[sd]?|digest[s]?|store[sd]?|control[s]?|'
      r'transport[s]?|function[s]?|act[s]?)$',
      caseSensitive: false,
    ).hasMatch(word);
  }

  String _asClaim(String raw) {
    final text = raw.trim();
    if (text.isEmpty) return text;
    if (RegExp(r'[.?!]$').hasMatch(text)) return text;
    return '$text.';
  }

  String? _factAfterTopic(String sentence, String? topic) {
    if (topic == null) return null;
    final match = RegExp(
      '${RegExp.escape(topic)}\\s+',
      caseSensitive: false,
    ).firstMatch(sentence);
    if (match == null) return null;
    var fact = sentence.substring(match.end).trim();
    fact = fact.replaceAll(RegExp(r'[.?!]+$'), '');
    final words = fact.split(RegExp(r'\s+'));
    if (words.length < 4) return null;
    return fact;
  }
}

/// Grades a short-answer string against the accepted term.
bool answersMatch(String written, String accepted) {
  final a = _norm(written);
  final b = _norm(accepted);
  if (a.isEmpty) return false;
  return a == b || b.contains(a) || a.contains(b);
}

String _norm(String s) =>
    s.toLowerCase().replaceAll(RegExp(r"[^\w]+"), ' ').trim();

/// Pulls a JSON array of question objects out of Gemini output.
///
/// Thinking models often hit MAX_TOKENS mid-array. The last object is
/// incomplete; every complete `{...}` before that is still usable.
List<dynamic> decodeQuizQuestionArray(String text) {
  var cleaned = text.trim();
  if (cleaned.startsWith('```')) {
    cleaned = cleaned
        .replaceFirst(RegExp(r'^```\w*\n?'), '')
        .replaceFirst(RegExp(r'\n?```$'), '')
        .trim();
  }
  final start = cleaned.indexOf('[');
  if (start < 0) return const [];

  final end = cleaned.lastIndexOf(']');
  if (end > start) {
    try {
      final decoded = jsonDecode(cleaned.substring(start, end + 1));
      if (decoded is List && decoded.isNotEmpty) return decoded;
    } catch (_) {}
  }

  final slice = cleaned.substring(start);
  final lastComplete = slice.lastIndexOf('}');
  if (lastComplete < 0) return const [];
  try {
    final decoded = jsonDecode('${slice.substring(0, lastComplete + 1)}]');
    if (decoded is List) return decoded;
  } catch (_) {}
  return const [];
}
