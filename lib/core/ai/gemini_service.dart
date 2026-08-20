import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

/// Gemini API key from `.env` (`GEMINI_API_KEY` or `GOOGLE_API_KEY`).
String get kGeminiApiKey {
  final fromEnv = _cleanKey(
    dotenv.env['GEMINI_API_KEY'] ?? dotenv.env['GOOGLE_API_KEY'] ?? '',
  );
  if (fromEnv.isNotEmpty) return fromEnv;
  return _cleanKey(const String.fromEnvironment('GEMINI_API_KEY'));
}

String _cleanKey(String raw) {
  var key = raw.trim();
  if (key.length >= 2 &&
      ((key.startsWith('"') && key.endsWith('"')) ||
          (key.startsWith("'") && key.endsWith("'")))) {
    key = key.substring(1, key.length - 1).trim();
  }
  return key;
}

const String _kDefaultModel = 'gemini-3.6-flash';
const List<String> _kFallbackModels = [
  'gemini-3.5-flash',
  'gemini-3.5-flash-lite',
];

/// Structured result from a Gemini text generation call.
class GeminiTextResult {
  const GeminiTextResult({required this.text, this.promptTokenCount = 0, this.candidatesTokenCount = 0});
  final String text;
  final int promptTokenCount;
  final int candidatesTokenCount;
}

/// Service that talks to the Gemini API for content extraction and quiz
/// generation. All calls are stateless — the caller provides the content and
/// prompt, Gemini returns structured text.
class GeminiService {
  GeminiService({String? apiKey, String? model})
      : _apiKey = apiKey ?? kGeminiApiKey,
        _modelName = model ?? _kDefaultModel;

  final String _apiKey;
  final String _modelName;

  bool get enabled => _apiKey.isNotEmpty;

  /// Coarse key type for logs — never the secret itself.
  String get keyKind {
    if (_apiKey.startsWith('AQ.')) return 'auth key';
    if (_apiKey.startsWith('AIza')) return 'standard key';
    return 'api key';
  }

  // ---------------------------------------------------------------------------
  // Quiz generation
  // ---------------------------------------------------------------------------

  /// Generates quiz questions from extracted text and/or page images.
  ///
  /// Page images let Gemini write "What do you call / Where is" items about
  /// diagrams and photos, not only running text.
  Future<GeminiTextResult> generateQuiz({
    List<QuizSourcePage> textPages = const [],
    List<QuizSourceImage> images = const [],
    required int questionCount,
    required Set<String> questionKinds,
    required String difficulty,
    String? additionalInstructions,
  }) async {
    if (!enabled) {
      throw StateError(
        'Gemini API key not configured. Add GEMINI_API_KEY to .env and rebuild.',
      );
    }

    final parts = <Map<String, dynamic>>[];
    for (final img in images) {
      if (img.bytes.isEmpty) continue;
      parts.add({'text': '--- Page ${img.pageIndex + 1} ---'});
      parts.add({
        'inlineData': {
          'mimeType': img.mimeType,
          'data': base64Encode(img.bytes),
        },
      });
    }

    final context = StringBuffer();
    if (textPages.isNotEmpty) {
      context.writeln(_buildDocumentContext(textPages));
    }
    if (images.isNotEmpty) {
      context.writeln(
        'Page images are attached. Read diagrams, photos, slides, arrows, '
        'and labels. Write questions from what is actually shown.',
      );
    }
    if (parts.isEmpty && context.isEmpty) {
      throw StateError('No text or images provided for quiz generation.');
    }

    parts.add({
      'text': _buildQuizPrompt(
        context: context.toString(),
        questionCount: questionCount,
        kinds: questionKinds,
        difficulty: difficulty,
        additionalInstructions: additionalInstructions,
        hasImages: images.isNotEmpty,
      ),
    });
    return _generateParts(parts);
  }

  /// Generates quiz questions from image bytes (PPT slides, scans, photos).
  Future<GeminiTextResult> generateQuizFromImages({
    required List<QuizSourceImage> images,
    required int questionCount,
    required Set<String> questionKinds,
    required String difficulty,
    String? additionalInstructions,
  }) {
    return generateQuiz(
      images: images,
      questionCount: questionCount,
      questionKinds: questionKinds,
      difficulty: difficulty,
      additionalInstructions: additionalInstructions,
    );
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  String _buildDocumentContext(List<QuizSourcePage> pages) {
    final buf = StringBuffer();
    buf.writeln('The following text was extracted from a document (${pages.length} pages):');
    buf.writeln();
    for (final p in pages) {
      if (p.text.trim().isEmpty) continue;
      buf.writeln('--- Page ${p.pageIndex + 1} ---');
      buf.writeln(p.text);
      buf.writeln();
    }
    return buf.toString();
  }

  String _buildQuizPrompt({
    required String context,
    required int questionCount,
    required Set<String> kinds,
    required String difficulty,
    String? additionalInstructions,
    bool hasImages = false,
  }) {
    final kindDescriptions = <String>[];
    if (kinds.contains('multipleChoice')) {
      kindDescriptions.add(
        '- Multiple choice: open with What / When / Where / Why / How / '
        'What do you call — never "Which of the following". Four parallel '
        'options of the same kind. Exactly one is correct.',
      );
    }
    if (kinds.contains('trueFalse')) {
      kindDescriptions.add(
        '- True/False: one complete claim a student could mark T/F. '
        'Never a fragment, heading, or citation.',
      );
    }
    if (kinds.contains('shortAnswer')) {
      kindDescriptions.add(
        '- Short answer: What do you call / What is / What are / Where is / '
        'Name / Identify — with a short accepted phrase. Not a fill-in-the-blank.',
      );
    }

    final visualBlock = hasImages
        ? '''
ILLUSTRATIONS AND IMAGES
Page photos are attached. Read the figures, flowcharts, labeled drawings and slide graphics for content — on diagram-heavy pages that is where the facts are.
The student answering never sees the page. So turn what the picture shows into a question that stands on its own in words.
- YES: "What do you call the inflammatory infection of the gingival tissue overlying a partially erupted tooth?"
- NO: "What is the infection labeled C in Figure 64.7?" — the student cannot see Figure 64.7.
Name the thing the picture is about, describe it in words, and ask about that. Do not invent labels that are not visible.
HIGHLIGHT
Every question must include "highlight" as one highlighter stroke over the cited LINE, in ONE column.
Two-column pages: never span the gutter. Left column is about x=0.07 w=0.40; right column x=0.53 w=0.40.
h is one line of body type (0.016–0.022). y is the top of that line (not a paragraph, table, or figure).
'''
        : '''
If the text only names a figure without describing it, skip guessing the picture. Prefer What is / What do you call questions from the prose.
Omit "highlight" unless you can see the page layout.
''';

    return '''
You are a university exam writer. Write $questionCount questions a professor would put on a midterm. Use grammatical, natural English. Rewrite awkward source phrasing; do not copy broken sentences.

Generate exactly $questionCount questions.

HARD RULE — MULTIPLE CHOICE OPENINGS
Never write "Which of the following", "Which one of the following", or "Which of these".
Rotate the first word. The set MUST include all of these (at least two each if $questionCount >= 12, otherwise at least one each):
- What … ?   (What is / What are / What do you call / What happens)
- When … ?   (When does / When is / When should)
- Where … ?  (Where is / Where does / Where would)
- Why … ?    (Why does / Why is / Why would)
Also mix How … ? and Name / Identify.
Do not use the same opening for more than a third of the multiple-choice items.

GOOD examples:
{"kind":"shortAnswer","prompt":"What do you call the organelle that packages proteins for transport across the membrane?","choices":[],"correctIndex":0,"acceptedAnswer":"Golgi apparatus","explanation":"The Golgi apparatus packages proteins and lipids into vesicles for delivery to other organelles or the cell surface. Cargo typically arrives from the rough endoplasmic reticulum, which synthesises those proteins. See page 14.","pageIndex":13,"highlight":{"x":0.08,"y":0.42,"w":0.38,"h":0.019}}
{"kind":"multipleChoice","prompt":"Where is ATP generated in animal cells?","choices":["Mitochondria during cellular respiration","Lysosomes during hydrolysis","The nucleus during transcription","The Golgi during packaging"],"correctIndex":0,"acceptedAnswer":"Mitochondria during cellular respiration","explanation":"Mitochondria generate ATP through cellular respiration. That energy conversion occurs at the inner mitochondrial membrane. Lysosomes hydrolyse worn-out organelles; they do not produce ATP. See page 15.","pageIndex":14,"highlight":{"x":0.53,"y":0.18,"w":0.38,"h":0.019}}
{"kind":"multipleChoice","prompt":"When do mitochondria generate ATP?","choices":["During cellular respiration","During Golgi packaging","During lysosomal digestion","During nuclear transcription"],"correctIndex":0,"acceptedAnswer":"During cellular respiration","explanation":"ATP is generated during cellular respiration, the mitochondrial pathway that oxidises fuel molecules. Golgi packaging and lysosomal digestion are separate organelle functions. See page 15.","pageIndex":14,"highlight":{"x":0.08,"y":0.18,"w":0.38,"h":0.019}}
{"kind":"multipleChoice","prompt":"Why do eukaryotic cells contain ribosomes?","choices":["They synthesise proteins from amino acids","They store the cell's genetic material","They generate ATP by respiration","They digest worn-out organelles"],"correctIndex":0,"acceptedAnswer":"They synthesise proteins from amino acids","explanation":"Ribosomes synthesise proteins from amino acids. The nucleus stores DNA, and mitochondria produce ATP by respiration. See page 14.","pageIndex":13,"highlight":{"x":0.08,"y":0.10,"w":0.38,"h":0.019}}
{"kind":"multipleChoice","prompt":"What prevents backflow from the left ventricle into the left atrium during contraction?","choices":["The mitral valve leaflet","The aortic sinus wall","The papillary muscle","The chordae tendineae"],"correctIndex":0,"acceptedAnswer":"The mitral valve leaflet","explanation":"The mitral valve leaflet sits between the left atrium and the left ventricle and closes during ventricular contraction. The aortic valve occupies the outflow tract instead. See page 8.","pageIndex":7,"highlight":{"x":0.18,"y":0.36,"w":0.36,"h":0.022}}

BAD example — never write anything like this:
{"prompt":"Which of the following is often injected, especially near the limbus?","choices":["The Eye","Patients","Panuveitis","Suspected Viral Etiology"],"explanation":"The Eye is often injected, especially near the limbus."}

$visualBlock
REQUIRED
- Prompts are complete questions or a full true/false claim.
- Fix grammar and word choice from the source.
- All four MC options must be the same type of answer.
- Scatter the right answer. correctIndex must vary across 0, 1, 2, and 3 in the set — never make every item A.
- pageIndex is the page whose text states the accepted answer. Never cite a contributors list, TOC, or title page.
- sourceQuote must appear verbatim on that page. It is checked against the file, and a quote that does not match is discarded.
- acceptedAnswer must name the thing in the SOURCE'S OWN WORDS, not a synonym or a paraphrase. The app highlights that wording on the page for the student, so "lipoteichoic acid" works and "a cell-wall sugar polymer" does not. Keep the phrasing grammatical, but do not reword the term itself.
- The highlight must cover the sentence that contains the accepted answer, not a nearby heading or author name.

EXPLANATION — facts, not grading
Write 3–5 sentences of real facts about the topic: what it is, what it does, when/where it occurs, how it differs from related structures.
Use Google Search to confirm well-known scientific or medical facts that support the source page. Never contradict the page. Never invent a dose, trial name, percentage, or statistic that is not on the page or in a standard reference.
Do not mention "correct", "wrong options", "the answer", or "this statement is true/false".
Contrast related facts in the same breath ("Lysosomes digest organelles; they do not make ATP") instead of saying an option is incorrect.
Do not repeat the question. End with "See page N."

NEVER
- Paste a source clause after "Which of the following is/are…".
- Generic options: the eye, patients, people, chapter, study, results.
- Fill-in-the-blank, cloze, "______", author lists, "et al.", DOIs.
- Inventing facts, labels, or figure parts that are not in the source.
- Questions the student cannot answer without seeing the page: never mention a figure, diagram, panel, illustration, numbered table, "labeled A/B/C", or "this page". Every question must be self-contained.
- "Which of the following" as a multiple-choice stem.
- "The correct statement is…" or any explanation that only validates the answer.

Difficulty: $difficulty (easy = definition / naming, medium = comprehension, hard = application).

Question types:
${kindDescriptions.join('\n')}

Return a JSON array only. Each element:
{
  "kind": "multipleChoice" | "trueFalse" | "shortAnswer",
  "prompt": "The question text",
  "choices": ["A", "B", "C", "D"],
  "correctIndex": 2,
  "acceptedAnswer": "the correct answer as a student would write it",
  "explanation": "3-5 sentences of facts about the topic, then See page N.",
  "pageIndex": 0,
  "sourceQuote": "the sentence from that page which states the answer, copied exactly",
  "highlight": {"x": 0.08, "y": 0.40, "w": 0.38, "h": 0.019}
}
For shortAnswer, choices is []. pageIndex is 0-based from the source headings.

SOURCE QUOTE (this is what the student is shown)
"sourceQuote" is ONE sentence copied CHARACTER FOR CHARACTER out of the page text above — the sentence that states the answer.
The app searches the real PDF for this sentence and draws a highlighter over it, so it has to match the source exactly.
- Copy it. Do not paraphrase it, tidy its grammar, shorten it, or join two sentences.
- Pick the sentence that TEACHES the answer, not one that merely mentions the term in a list or an aside.
- If the answer came from a figure, a table, or a page you cannot quote exactly, use "" instead. An empty quote is fine; an invented one is not.
highlight x/y/w/h are 0–1 fractions of the page image covering the source passage or figure. Omit highlight only if you cannot see the page.

$context
${additionalInstructions != null ? '\nAdditional instructions: $additionalInstructions' : ''}
''';
  }

  Future<GeminiTextResult> _generateParts(
    List<Map<String, dynamic>> parts,
  ) async {
    Object? lastError;
    for (final model in {_modelName, ..._kFallbackModels}) {
      for (final useSearch in [true, false]) {
        try {
          return await _generateWithModel(
            model,
            parts,
            googleSearch: useSearch,
          );
        } catch (e) {
          lastError = e;
          debugPrint('Gemini $model search=$useSearch failed: $e');
          if (_isModelUnavailable(e)) break;
        }
      }
    }
    throw StateError('Gemini request failed: $lastError');
  }

  Future<GeminiTextResult> _generateWithModel(
    String model,
    List<Map<String, dynamic>> parts, {
    bool googleSearch = false,
  }) async {
    final uri = Uri.parse(
      'https://generativelanguage.googleapis.com/v1beta/models/'
      '$model:generateContent',
    );
    final body = jsonEncode({
      'contents': [
        {
          'role': 'user',
          'parts': parts,
        },
      ],
      'generationConfig': {
        'temperature': 0.65,
        'topP': 0.9,
        'maxOutputTokens': 32768,
        'responseMimeType': 'application/json',
      },
      if (googleSearch)
        'tools': [
          {'google_search': <String, dynamic>{}},
        ],
    });

    var response = await http.post(
      uri,
      headers: {
        'Content-Type': 'application/json',
        'x-goog-api-key': _apiKey,
      },
      body: body,
    );

    // Auth keys (AQ.) sometimes reject x-goog-api-key and want Bearer.
    if (response.statusCode == 401 || response.statusCode == 403) {
      response = await http.post(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_apiKey',
        },
        body: body,
      );
    }

    if (response.statusCode >= 400) {
      throw StateError(
        'HTTP ${response.statusCode}: ${_shortGeminiError(response.body)}',
      );
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      throw StateError('Unexpected Gemini response');
    }
    final text = _textFromGemini(decoded);
    if (text.isEmpty) {
      throw StateError('Gemini returned no text');
    }
    final usage = decoded['usageMetadata'] as Map<String, dynamic>?;
    return GeminiTextResult(
      text: text,
      promptTokenCount: (usage?['promptTokenCount'] as num?)?.toInt() ?? 0,
      candidatesTokenCount:
          (usage?['candidatesTokenCount'] as num?)?.toInt() ?? 0,
    );
  }

  String _textFromGemini(Map<String, dynamic> json) {
    final candidates = json['candidates'];
    if (candidates is! List || candidates.isEmpty) return '';
    final first = candidates.first;
    if (first is! Map) return '';
    final content = first['content'];
    if (content is! Map) return '';
    final parts = content['parts'];
    if (parts is! List) return '';
    final buf = StringBuffer();
    for (final part in parts) {
      if (part is! Map) continue;
      if (part['thought'] == true) continue;
      if (part['text'] is String) buf.write(part['text']);
    }
    return buf.toString();
  }

  bool _isModelUnavailable(Object error) {
    final raw = error.toString();
    return raw.contains('HTTP 404') ||
        raw.contains('NOT_FOUND') ||
        raw.toLowerCase().contains('no longer available');
  }

  String _shortGeminiError(String body) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map && decoded['error'] is Map) {
        final err = decoded['error'] as Map;
        return '${err['status'] ?? ''} ${err['message'] ?? body}'.trim();
      }
    } catch (_) {}
    if (body.length > 180) return '${body.substring(0, 180)}…';
    return body;
  }
}

// ---------------------------------------------------------------------------
// Data classes for source content
// ---------------------------------------------------------------------------

class QuizSourcePage {
  const QuizSourcePage({required this.pageIndex, required this.text});
  final int pageIndex;
  final String text;
}

class QuizSourceImage {
  const QuizSourceImage({
    required this.pageIndex,
    required this.bytes,
    required this.mimeType,
  });
  final int pageIndex;
  final Uint8List bytes;
  final String mimeType;
}
