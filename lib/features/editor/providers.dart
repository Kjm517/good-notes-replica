import 'dart:ui' as ui;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/ai/ai_providers.dart';
import '../../core/ai/gemini_service.dart';
import '../../core/db/database.dart';
import '../../core/ink/ink_stroke.dart';
import '../../core/sync/sync_providers.dart';
import '../library/providers.dart';
import 'data/element_repository.dart';
import 'data/page_repository.dart';
import 'data/stroke_repository.dart';
import 'pages/page_background_service.dart';
import 'quiz/quiz_generator.dart';
import 'quiz/quiz_history.dart';
import 'quiz/quiz_history_repository.dart';
import 'quiz/quiz_models.dart';
import 'quiz/quiz_source_locator.dart';
import 'search/document_text_service.dart';
import 'state/editor_controller.dart';
import 'state/editor_state.dart';

final pageRepositoryProvider = Provider<PageRepository>((ref) {
  return PageRepository(ref.watch(databaseProvider), ref.watch(uuidProvider));
});

final strokeRepositoryProvider = Provider<StrokeRepository>((ref) {
  return StrokeRepository(ref.watch(databaseProvider));
});

final elementRepositoryProvider = Provider<ElementRepository>((ref) {
  return ElementRepository(
    ref.watch(databaseProvider),
    ref.watch(uuidProvider),
    ref.watch(assetRepositoryProvider),
  );
});

/// Live image/text elements for a page.
final pageElementsProvider =
    StreamProvider.family<List<CanvasElement>, String>((ref, pageId) {
  return ref.watch(elementRepositoryProvider).watchElements(pageId);
});

/// Live ink for a page, straight from the database.
///
/// The editor keeps strokes for the pages it has loaded; this is for anything
/// that needs a page's ink without opening it — the sidebar previews.
final pageStrokesProvider =
    StreamProvider.family<List<InkStroke>, String>((ref, pageId) {
  return ref.watch(strokeRepositoryProvider).watchStrokes(pageId);
});

/// Extracts and searches text inside PDF-backed documents.
final documentTextServiceProvider = Provider<DocumentTextService>((ref) {
  return DocumentTextService(
    ref.watch(databaseProvider),
    ref.watch(assetRepositoryProvider),
  );
});

/// Finds the page and the lines a quiz answer came from, so the source
/// preview can highlight them.
final quizSourceLocatorProvider = Provider<QuizSourceLocator>((ref) {
  final locator = QuizSourceLocator(
    ref.watch(databaseProvider),
    ref.watch(pageRepositoryProvider),
    ref.watch(assetRepositoryProvider),
  );
  ref.onDispose(locator.dispose);
  return locator;
});

final pageBackgroundServiceProvider = Provider<PageBackgroundService>((ref) {
  final service = PageBackgroundService(
    ref.watch(assetRepositoryProvider),
    files: ref.watch(fileSyncProvider),
  );
  ref.onDispose(service.dispose);
  return service;
});

/// Live pages of a document (for the thumbnail rail / navigation).
final pagesStreamProvider =
    StreamProvider.family<List<NotePage>, String>((ref, documentId) {
  return ref.watch(pageRepositoryProvider).watchPages(documentId);
});

/// The stateful editor for a document.
final editorControllerProvider =
    NotifierProvider.family<EditorController, EditorState, String>(
  EditorController.new,
);

/// Whether a resting palm/finger is ignored once a stylus is in use. Persisted
/// app-wide and read by the canvas' pointer routing.
final palmRejectionProvider =
    NotifierProvider<PalmRejectionController, bool>(PalmRejectionController.new);

class PalmRejectionController extends Notifier<bool> {
  static const _key = 'palm_rejection';

  @override
  bool build() => ref.watch(sharedPrefsProvider).getBool(_key) ?? true;

  Future<void> set(bool value) async {
    state = value;
    await ref.read(sharedPrefsProvider).setBool(_key, value);
  }
}

/// Whether PDF/scan text is indexed so it can be found with "find in document".
/// Persisted app-wide and checked before the editor warms its text index.
final ocrEnabledProvider =
    NotifierProvider<OcrEnabledController, bool>(OcrEnabledController.new);

class OcrEnabledController extends Notifier<bool> {
  static const _key = 'ocr_enabled';

  @override
  bool build() => ref.watch(sharedPrefsProvider).getBool(_key) ?? true;

  Future<void> set(bool value) async {
    state = value;
    await ref.read(sharedPrefsProvider).setBool(_key, value);
  }
}

/// First-page thumbnail for a document's library card: the PDF cover / imported
/// image if the first page has a background, otherwise null (card shows the
/// notebook cover). Reuses the background cache, so opening the doc is instant.
final documentThumbnailProvider =
    FutureProvider.family<ui.Image?, String>((ref, documentId) async {
  final page = await ref.watch(pageRepositoryProvider).firstPage(documentId);
  if (page == null) return null;
  final service = ref.watch(pageBackgroundServiceProvider);
  if (!service.hasBackground(page)) return null;
  // A card only needs a small preview — rendering the full page here would
  // burn GPU memory for no visible gain.
  final image = await service.loadThumbnail(page, targetWidth: 320);
  ref.onDispose(() => image?.dispose());
  return image;
});

// ---------------------------------------------------------------------------
// Quiz providers
// ---------------------------------------------------------------------------

/// The AI quiz generator (uses Gemini when the API key is loaded).
final aiQuizGeneratorProvider = Provider<AiQuizGenerator?>((ref) {
  final gemini = ref.watch(geminiServiceProvider);
  if (gemini == null) return null;
  return AiQuizGenerator(gemini);
});

final quizHistoryRepositoryProvider = Provider<QuizHistoryRepository>((ref) {
  return QuizHistoryRepository(
    ref.watch(databaseProvider),
    ref.watch(uuidProvider),
  );
});

final quizHistoryProvider =
    StreamProvider.family<List<QuizHistoryRecord>, String>((ref, documentId) {
  return ref.watch(quizHistoryRepositoryProvider).watchForDocument(documentId);
});

/// Quiz generation state — tracks the async generation process.
class QuizGenerationState {
  const QuizGenerationState({
    this.questions = const [],
    this.isGenerating = false,
    this.error,
    this.usedAI = false,
  });

  final List<QuizQuestion> questions;
  final bool isGenerating;
  final String? error;
  final bool usedAI;

  QuizGenerationState copyWith({
    List<QuizQuestion>? questions,
    bool? isGenerating,
    String? error,
    bool? usedAI,
    bool clearError = false,
  }) =>
      QuizGenerationState(
        questions: questions ?? this.questions,
        isGenerating: isGenerating ?? this.isGenerating,
        error: clearError ? null : (error ?? this.error),
        usedAI: usedAI ?? this.usedAI,
      );
}

/// Manages quiz generation for a document via Gemini.
class QuizGenerationController extends Notifier<QuizGenerationState> {
  @override
  QuizGenerationState build() => const QuizGenerationState();

  /// Generates questions from a document's pre-extracted text.
  Future<void> generate({
    required List<QuizSourcePage> textPages,
    required QuizConfig config,
    String? additionalInstructions,
  }) async {
    state = state.copyWith(isGenerating: true, clearError: true);

    try {
      final ai = ref.read(aiQuizGeneratorProvider);
      if (ai == null) {
        throw StateError('Add a Gemini API key to generate quizzes.');
      }
      final passages = textPages
          .map((p) => SourcePassage(pageIndex: p.pageIndex, sentence: p.text))
          .toList();
      final questions = await generateExamQuiz(
        passages: passages,
        config: config,
        ai: ai,
        additionalInstructions: additionalInstructions,
      );
      state = state.copyWith(
        questions: questions,
        isGenerating: false,
        usedAI: true,
      );
    } catch (e) {
      state = state.copyWith(
        isGenerating: false,
        error: e.toString(),
      );
    }
  }

  void reset() {
    state = const QuizGenerationState();
  }
}

final quizGenerationProvider =
    NotifierProvider<QuizGenerationController, QuizGenerationState>(
  QuizGenerationController.new,
);
