import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/design.dart';
import '../../../app/page_routes.dart';
import '../../../app/providers.dart';
import '../../../core/ai/gemini_service.dart';
import '../../../core/db/database.dart';
import '../../../core/models/outline_entry.dart';
import '../../../core/network/network_status.dart';
import '../../library/providers.dart';
import '../../settings/entitlements.dart';
import '../../settings/premium_plan_sheet.dart';
import '../../settings/quiz_upgrade_sheet.dart';
import '../pages/page_background_service.dart';
import '../providers.dart';
import 'quiz_align.dart';
import 'quiz_generator.dart';
import 'quiz_history.dart';
import 'quiz_history_page.dart';
import 'quiz_models.dart';
import 'quiz_queue.dart';
import 'quiz_source_locator.dart';
import 'quiz_source_preview.dart';

/// Full-screen quiz: setup → generate from the opened file → take → score.
///
/// Matches redesign §11. Gold is reserved for this premium surface; the
/// rest of the editor stays on the indigo tokens.
class QuizFlow extends ConsumerStatefulWidget {
  const QuizFlow({
    super.key,
    required this.documentId,
    required this.title,
    required this.pageCount,
    this.onJumpToPage,
  });

  final String documentId;
  final String title;
  final int pageCount;
  final void Function(int pageIndex)? onJumpToPage;

  static Future<void> open(
    BuildContext context, {
    required String documentId,
    required String title,
    required int pageCount,
    void Function(int pageIndex)? onJumpToPage,
  }) async {
    final container = ProviderScope.containerOf(context);
    final ent = await container.read(entitlementProvider.future);
    if (!context.mounted) return;
    if (!ent.canGenerateQuiz) {
      await _promptQuizUpgrade(context, ent);
      return;
    }
    await Navigator.of(context).push(
      notablyRoute<void>(
        fullscreenDialog: true,
        builder: (_) => QuizFlow(
          documentId: documentId,
          title: title,
          pageCount: pageCount,
          onJumpToPage: onJumpToPage,
        ),
      ),
    );
  }

  static Future<void> _promptQuizUpgrade(
    BuildContext context,
    UserEntitlement ent,
  ) async {
    final subtitle = ent.isTrialActive
        ? 'You\'ve used all ${ent.quizLimit} trial quizzes. Upgrade for '
            'unlimited AI quizzes from this document.'
        : ent.trialExpired
            ? 'Your free trial has ended. Upgrade to Premium for unlimited '
                'AI quizzes from your PDFs.'
            : null;
    await QuizUpgradeSheet.show(context, subtitle: subtitle);
  }

  @override
  ConsumerState<QuizFlow> createState() => _QuizFlowState();
}

enum _Phase { setup, generating, taking, results }

class _QuizFlowState extends ConsumerState<QuizFlow> {
  _Phase _phase = _Phase.setup;
  QuizConfig _config = QuizConfig.defaults;
  List<QuizQuestion> _questions = const [];
  final Map<int, QuizAnswer> _answers = {};
  int _index = 0;
  String _status = '';
  double _progress = 0;
  final _shortAnswer = TextEditingController();
  Timer? _timer;
  Duration _remaining = Duration.zero;
  bool _revealed = false;
  String _familyId = '';

  /// The pages this quiz was written from — where the answers actually live.
  Set<int> _sourcePages = const {};
  String? _draftId;
  DateTime? _startedAt;
  var _savedAttempt = false;
  var _launchingQueued = false;
  var _fromHistory = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(
        ref.read(documentTextServiceProvider).ensureOutline(widget.documentId),
      );
      final queued = ref
          .read(quizQueueProvider.notifier)
          .forDocument(widget.documentId);
      if (queued != null && mounted) {
        setState(() => _config = queued.config);
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _shortAnswer.dispose();
    super.dispose();
  }

  Future<void> _queueCurrent() async {
    await ref
        .read(quizQueueProvider.notifier)
        .enqueue(
          QueuedQuizJob(
            documentId: widget.documentId,
            title: widget.title,
            config: _config,
            queuedAt: DateTime.now(),
          ),
        );
  }

  Future<void> _showNetworkError(String body) async {
    if (!mounted) return;
    final t = context.tokens;
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: t.surface,
        title: Text(
          kNetworkErrorTitle,
          style: TextStyle(color: t.text, fontWeight: FontWeight.w700),
        ),
        content: Text(
          body,
          style: TextStyle(color: t.textSecondary, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text('OK', style: TextStyle(color: t.accentText)),
          ),
        ],
      ),
    );
  }

  Future<void> _generate({bool fromQueue = false}) async {
    final ent = await ref.read(entitlementProvider.future);
    if (!ent.canGenerateQuiz) {
      if (!mounted) return;
      await _showQuizLimitReached(ent);
      return;
    }
    final online = fromQueue || await isOnlineNow();
    if (!online) {
      await _queueCurrent();
      await _showNetworkError(
        '$kNoWifiOrMobileData This quiz is queued and will generate '
        'when you are back online. You can still retake quizzes from history.',
      );
      return;
    }
    final ai = ref.read(aiQuizGeneratorProvider);
    if (ai == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Add a Gemini API key to generate quizzes.'),
        ),
      );
      return;
    }
    setState(() {
      _phase = _Phase.generating;
      _status = 'Reading your document…';
      _progress = 0.06;
    });
    final service = ref.read(documentTextServiceProvider);
    final pagesToExtract = _pagesToExtract();
    _sourcePages = pagesToExtract;
    await service.index(
      widget.documentId,
      pageIndices: pagesToExtract,
      onProgress: (p) {
        if (mounted) {
          setState(() {
            _progress = 0.06 + p * 0.42;
            _status = 'Extracting text…';
          });
        }
      },
    );
    if (!mounted) return;
    final passages = [
      for (final page in await service.pageTexts(widget.documentId))
        if (pagesToExtract.contains(page.pageIndex))
          SourcePassage(pageIndex: page.pageIndex, sentence: page.text),
    ];
    final notePages = await ref
        .read(pageRepositoryProvider)
        .getPages(widget.documentId);
    final selectedPages = [
      for (final page in notePages)
        if (pagesToExtract.contains(page.pageIndex)) page,
    ];
    final backgrounds = ref.read(pageBackgroundServiceProvider);
    final canRender = selectedPages.any(backgrounds.hasBackground);
    final images = <QuizSourceImage>[];
    var attemptedImages = false;
    if (canRender) {
      attemptedImages = true;
      images.addAll(await _pageImagesForQuiz(selectedPages, backgrounds));
    }
    if (!mounted) return;
    setState(() {
      _status = 'Asking Notably...';
      _progress = 0.88;
    });
    List<QuizQuestion> questions;
    try {
      questions = await generateExamQuiz(
        passages: passages,
        images: images,
        config: _config,
        ai: ai,
      );
    } catch (e) {
      debugPrint('Gemini quiz failed: $e');
      if (!mounted) return;
      setState(() {
        _phase = _Phase.setup;
        _status = '';
      });
      if (isQuizNetworkError(e)) {
        await _queueCurrent();
        await _showNetworkError(
          'Could not reach the internet. Check Wi-Fi or mobile data. '
          'This quiz is queued and will generate when you are back online.',
        );
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(_aiFailureMessage(e))));
      return;
    }
    if (!mounted) return;
    await ref.read(quizQueueProvider.notifier).remove(widget.documentId);
    if (!mounted) return;
    if (questions.isEmpty) {
      setState(() {
        _phase = _Phase.setup;
        _status = '';
      });
      if (!mounted) return;
      final pending = await service.hasUnextractedPages(
        widget.documentId,
        pageIndices: pagesToExtract,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _emptyQuizMessage(
              passages: passages,
              triedImages: attemptedImages,
              pendingExtract: pending,
            ),
          ),
        ),
      );
      return;
    }
    setState(() {
      _status = 'Marking the answers on the page…';
      _progress = 0.94;
    });
    questions = await _markAnswers(questions);
    if (!mounted) return;
    final familyId = ref.read(uuidProvider).v4();
    String? draftId;
    try {
      draftId = await ref
          .read(quizHistoryRepositoryProvider)
          .saveGenerated(
            documentId: widget.documentId,
            familyId: familyId,
            title: _quizTitle(),
            sourceLabel: _config.source.label(
              outline: _outlineTree,
              pageCount: widget.pageCount,
            ),
            questions: questions,
          );
    } catch (e) {
      debugPrint('Quiz history save failed: $e');
    }
    ref.read(entitlementServiceProvider).refresh();
    if (!mounted) return;
    setState(() {
      _questions = questions;
      _familyId = familyId;
      _draftId = draftId;
      _savedAttempt = false;
      _fromHistory = false;
      _answers.clear();
      _index = 0;
      _revealed = false;
      _shortAnswer.clear();
      _startedAt = DateTime.now();
      _phase = _Phase.taking;
      _progress = 1;
    });
    _armTimer();
  }

  List<OutlineNode> get _outlineTree {
    final json = ref
        .read(documentStreamProvider(widget.documentId))
        .asData
        ?.value
        ?.outline;
    return OutlineNode.nest(OutlineEntry.decode(json));
  }

  /// Cap so a 25-question quiz doesn't extract a 900-page textbook first.
  static const _kQuizPageCap = 100;

  Set<int> _pagesToExtract() {
    final filter = _config.source.pageFilter(
      outline: _outlineTree,
      pageCount: widget.pageCount,
    );
    final all = filter ?? {for (var i = 0; i < widget.pageCount; i++) i};
    return samplePageIndices(all, _kQuizPageCap);
  }

  Future<List<QuizSourceImage>> _pageImagesForQuiz(
    List<NotePage> pages,
    PageBackgroundService backgrounds,
  ) async {
    final sample = samplePageIndices(
      pages.map((p) => p.pageIndex),
      kMaxQuizImagePages,
    );
    final chosen = [
      for (final page in pages)
        if (sample.contains(page.pageIndex) && backgrounds.hasBackground(page))
          page,
    ];
    final out = <QuizSourceImage>[];
    for (var i = 0; i < chosen.length; i++) {
      if (!mounted) break;
      setState(() {
        _status = 'Reading page ${chosen[i].pageIndex + 1}…';
        _progress = 0.5 + (i / chosen.length) * 0.36;
      });
      final packed = await backgrounds.bytesForAiQuiz(chosen[i]);
      if (packed == null) continue;
      out.add(
        QuizSourceImage(
          pageIndex: chosen[i].pageIndex,
          bytes: packed.bytes,
          mimeType: packed.mimeType,
        ),
      );
    }
    return out;
  }

  String _emptyQuizMessage({
    required List<SourcePassage> passages,
    required bool triedImages,
    required bool pendingExtract,
  }) {
    if (triedImages) {
      return 'Gemini could not read these pages. Try a smaller range, '
          'or a clearer scan.';
    }
    if (passages.every((p) => p.sentence.trim().isEmpty)) {
      return pendingExtract
          ? 'Could not extract text from this file. Try a smaller page '
                'range, then generate again.'
          : 'These pages have no selectable text. Generate again so Gemini '
                'can read the page images.';
    }
    return 'Not enough readable sentences on these pages to write a quiz. '
        'Try a wider page range.';
  }

  String _aiFailureMessage(Object error) {
    final raw = error.toString();
    if (raw.contains('API key') || raw.contains('not configured')) {
      return 'Add a Gemini API key to generate quizzes.';
    }
    if (isQuizNetworkError(error)) {
      return kNoWifiOrMobileData;
    }
    if (raw.contains('HTTP 429') ||
        raw.toLowerCase().contains('resource exhausted')) {
      return 'Gemini is busy. Try again in a moment.';
    }
    if (raw.contains('HTTP 404') ||
        raw.contains('NOT_FOUND') ||
        raw.toLowerCase().contains('no longer available')) {
      return 'Gemini could not write this quiz. Try again.';
    }
    if (raw.contains('No readable text') ||
        raw.contains('did not return usable')) {
      return raw.replaceFirst(RegExp(r'^StateError:\s*'), '');
    }
    return 'Gemini could not write this quiz. Check Wi-Fi or mobile data and try again.';
  }

  /// Reads the source once per question, while the quiz is still being built,
  /// and keeps the highlight on the question.
  ///
  /// Doing it here means the marks are part of the generated quiz: they are
  /// saved with the attempt, survive a restart, and need no further work — or
  /// network — when the student taps "See page" during the quiz.
  Future<List<QuizQuestion>> _markAnswers(List<QuizQuestion> questions) async {
    final locator = ref.read(quizSourceLocatorProvider);
    // Generation already made the student wait; this pass is capped so a book
    // that resists the search cannot stretch it much further. The clock starts
    // after the first answer, so opening the book once is not counted against
    // the rest. Anything left unresolved is looked up when its answer is
    // revealed.
    DateTime? deadline;
    final marked = <QuizQuestion>[];
    for (var i = 0; i < questions.length; i++) {
      final question = questions[i];
      final expired = deadline != null && DateTime.now().isAfter(deadline);
      if (question.location != null || expired) {
        marked.add(question);
        continue;
      }
      try {
        final match = await locator.locate(
          documentId: widget.documentId,
          candidatePages: _candidatePages(question),
          target: question.sourceTarget,
          sourcePages: _sourcePages,
        );
        final location = match.location;
        marked.add(
          location == null
              ? question
              : question.copyWith(
                  pageIndex: location.pageIndex,
                  location: location,
                  explanation: rewriteSeePage(
                    question.explanation,
                    location.pageIndex,
                  ),
                ),
        );
      } catch (e) {
        debugPrint('Marking the answer failed: $e');
        marked.add(question);
      }
      deadline ??= DateTime.now().add(const Duration(seconds: 20));
      if (!mounted) return marked + questions.sublist(marked.length);
      setState(() => _progress = 0.94 + (i + 1) / questions.length * 0.05);
    }
    return marked;
  }

  /// The pages a citation might mean: the number written in the explanation,
  /// and the one the question itself carries.
  List<int> _candidatePages(QuizQuestion question) {
    final last = math.max(0, widget.pageCount - 1);
    final cited =
        firstCitedPageIndex(question.explanation) ?? question.pageIndex;
    return [
      cited.clamp(0, last),
      if (question.pageIndex != cited) question.pageIndex.clamp(0, last),
    ];
  }

  /// Reads the source as soon as the answer is on screen, so tapping
  /// "See page" opens on a highlight instead of a spinner. The result is kept
  /// on the question, so it survives the rest of the quiz and the trip into
  /// history.
  void _prefetchSource(int index) {
    if (index < 0 || index >= _questions.length) return;
    final question = _questions[index];
    if (question.location != null) return;
    unawaited(
      ref
          .read(quizSourceLocatorProvider)
          .locate(
            documentId: widget.documentId,
            candidatePages: _candidatePages(question),
            target: question.sourceTarget,
            sourcePages: _sourcePages,
          )
          .then((match) => _applySourceMatch(question.acceptedAnswer, match))
          .catchError((Object error) {
            debugPrint('Quiz source prefetch failed: $error');
          }),
    );
  }

  /// Moves the question onto the page the answer was actually found on, so the
  /// badge and the "See page" citation stop disagreeing with the preview.
  ///
  /// Keyed by the answer rather than a position, because the preview can be
  /// opened from the results list as well as from the question on screen.
  void _applySourceMatch(String answer, QuizSourceMatch match) {
    if (!mounted) return;
    final location = match.location;
    if (location == null) return;
    final index = _questions.indexWhere(
      (q) => q.acceptedAnswer == answer && q.location == null,
    );
    if (index < 0) return;
    final next = [..._questions];
    next[index] = _questions[index].copyWith(
      pageIndex: location.pageIndex,
      location: location,
      explanation: rewriteSeePage(
        _questions[index].explanation,
        location.pageIndex,
      ),
    );
    setState(() => _questions = next);
  }

  void _openSourcePage(int pageIndex, [QuizSourceTarget? target]) {
    final last = math.max(0, widget.pageCount - 1);
    final clamped = pageIndex.clamp(0, last);
    unawaited(
      QuizSourcePreview.show(
        context,
        documentId: widget.documentId,
        pageIndex: clamped,
        target: target,
        onResolved: target == null
            ? null
            : (match) => _applySourceMatch(target.answer, match),
        onOpenInNotebook: widget.onJumpToPage == null
            ? null
            : (resolved) {
                widget.onJumpToPage!(resolved.clamp(0, last));
                Navigator.of(context).maybePop();
              },
      ),
    );
  }

  Future<void> _pickSource() async {
    final next = await showModalBottomSheet<QuizSource>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) => _SourcePickerSheet(
        pageCount: widget.pageCount,
        outline: _outlineTree,
        initial: _config.source,
      ),
    );
    if (next == null || !mounted) return;
    setState(() => _config = _config.copyWith(source: next));
  }

  void _armTimer() {
    _timer?.cancel();
    final per = _config.perQuestionLimit;
    final full = _config.fullLimitFor(_questions.length);
    if (per == null && full == null) {
      _remaining = Duration.zero;
      return;
    }
    _remaining = per ?? full!;
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted || _phase != _Phase.taking) return;
      if (_remaining <= const Duration(seconds: 1)) {
        _timer?.cancel();
        if (per != null) {
          _lockIn(timedOut: true);
        } else {
          unawaited(_finishQuiz());
        }
        return;
      }
      setState(() => _remaining -= const Duration(seconds: 1));
    });
  }

  QuizQuestion get _current => _questions[_index];

  void _pick(int choice) {
    if (_revealed) return;
    final q = _current;
    final correct = choice == q.correctIndex;
    setState(() {
      _answers[_index] = QuizAnswer(
        choiceIndex: choice,
        written: q.choices[choice],
        correct: correct,
      );
      _revealed = true;
    });
    _prefetchSource(_index);
  }

  void _submitWritten() {
    if (_revealed) return;
    final q = _current;
    final written = _shortAnswer.text.trim();
    setState(() {
      _answers[_index] = QuizAnswer(
        choiceIndex: null,
        written: written,
        correct: answersMatch(written, q.acceptedAnswer),
      );
      _revealed = true;
    });
    _prefetchSource(_index);
  }

  void _lockIn({bool timedOut = false}) {
    if (_revealed) {
      _next();
      return;
    }
    final q = _current;
    if (q.kind == QuizKind.shortAnswer) {
      _submitWritten();
    } else {
      setState(() {
        _answers[_index] = QuizAnswer(
          choiceIndex: null,
          written: timedOut ? '' : null,
          correct: false,
        );
        _revealed = true;
      });
      _prefetchSource(_index);
    }
  }

  void _next() {
    if (_index >= _questions.length - 1) {
      unawaited(_finishQuiz());
      return;
    }
    setState(() {
      _index++;
      _revealed = _answers.containsKey(_index);
      _shortAnswer.clear();
      if (_answers[_index]?.written != null &&
          _current.kind == QuizKind.shortAnswer) {
        _shortAnswer.text = _answers[_index]!.written!;
      }
    });
    if (_config.perQuestionLimit != null) _armTimer();
  }

  Future<void> _finishQuiz() async {
    _timer?.cancel();
    if (!_savedAttempt && _questions.isNotEmpty) {
      _savedAttempt = true;
      final elapsed = _startedAt == null
          ? Duration.zero
          : DateTime.now().difference(_startedAt!);
      try {
        final repo = ref.read(quizHistoryRepositoryProvider);
        final familyId = _familyId.isEmpty
            ? ref.read(uuidProvider).v4()
            : _familyId;
        final draftId = _draftId;
        if (draftId != null) {
          await repo.completeAttempt(
            id: draftId,
            questions: _questions,
            answers: _answers,
            duration: elapsed,
          );
        } else {
          await repo.saveAttempt(
            documentId: widget.documentId,
            familyId: familyId,
            title: _quizTitle(),
            sourceLabel: _config.source.label(
              outline: _outlineTree,
              pageCount: widget.pageCount,
            ),
            questions: _questions,
            answers: _answers,
            duration: elapsed,
          );
        }
        _draftId = null;
      } catch (e) {
        debugPrint('Quiz history save failed: $e');
      }
    }
    if (!mounted) return;
    setState(() => _phase = _Phase.results);
  }

  String _quizTitle() {
    return quizHeadlineFrom(
      storedTitle: '',
      questions: _questions,
      bookTitle: widget.title,
      outline: _outlineTree,
      pageCount: widget.pageCount,
      source: _config.source,
    );
  }

  Future<void> _showQuizLimitReached(UserEntitlement ent) async {
    await QuizFlow._promptQuizUpgrade(context, ent);
  }

  Future<void> _openHistory() async {
    final ent = await ref.read(entitlementProvider.future);
    if (!mounted) return;
    if (!ent.canAccessQuizHistory) {
      await PremiumPlanSheet.show(context);
      return;
    }
    final action = await QuizHistoryPage.open(
      context,
      documentId: widget.documentId,
      documentTitle: widget.title,
      onJumpToPage: _openSourcePage,
    );
    if (action == null || !mounted) return;
    final questions = action.missedOnly
        ? action.record.missedQuestions
        : action.record.questions;
    if (questions.isEmpty) return;
    _beginAttempt(
      questions: questions,
      familyId: action.record.familyId,
      fromHistory: true,
      draftId: action.record.completed ? null : action.record.id,
    );
  }

  void _beginAttempt({
    required List<QuizQuestion> questions,
    required String familyId,
    bool fromHistory = false,
    String? draftId,
  }) {
    setState(() {
      _questions = reshuffleQuiz(questions);
      _familyId = familyId;
      _fromHistory = fromHistory;
      _draftId = draftId;
      _savedAttempt = false;
      _answers.clear();
      _index = 0;
      _revealed = false;
      _shortAnswer.clear();
      _startedAt = DateTime.now();
      _phase = _Phase.taking;
    });
    _armTimer();
  }

  void _closeQuiz() {
    if (_fromHistory && (_phase == _Phase.taking || _phase == _Phase.results)) {
      _timer?.cancel();
      setState(() {
        _fromHistory = false;
        _phase = _Phase.setup;
        _questions = const [];
        _answers.clear();
        _index = 0;
        _revealed = false;
        _shortAnswer.clear();
        _status = '';
      });
      unawaited(_openHistory());
      return;
    }
    Navigator.of(context).maybePop();
  }

  int get _correctCount => _answers.values.where((a) => a.correct).length;

  @override
  Widget build(BuildContext context) {
    ref.watch(documentStreamProvider(widget.documentId));
    final online = ref.watch(onlineProvider).asData?.value ?? true;
    final queued = [
      for (final job in ref.watch(quizQueueProvider))
        if (job.documentId == widget.documentId) job,
    ].firstOrNull;
    final hasHistory =
        ref
            .watch(quizHistoryProvider(widget.documentId))
            .asData
            ?.value
            .isNotEmpty ??
        false;
    final entitlement = ref.watch(entitlementProvider);
    final canAccessHistory =
        entitlement.asData?.value.canAccessQuizHistory ?? false;
    ref.listen<AsyncValue<bool>>(onlineProvider, (prev, next) {
      final wasOnline = prev?.asData?.value;
      final isOnline = next.asData?.value ?? false;
      if (wasOnline != false ||
          !isOnline ||
          _phase != _Phase.setup ||
          _launchingQueued) {
        return;
      }
      if (!(ModalRoute.of(context)?.isCurrent ?? true)) return;
      final job = ref
          .read(quizQueueProvider.notifier)
          .forDocument(widget.documentId);
      if (job == null) return;
      _launchingQueued = true;
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        try {
          if (!mounted || _phase != _Phase.setup) return;
          setState(() => _config = job.config);
          await _generate(fromQueue: true);
        } finally {
          _launchingQueued = false;
        }
      });
    });
    final t = context.tokens;
    return PopScope(
      canPop:
          !(_fromHistory &&
              (_phase == _Phase.taking || _phase == _Phase.results)),
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _closeQuiz();
      },
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: Theme.of(context).brightness == Brightness.dark
            ? SystemUiOverlayStyle.light
            : SystemUiOverlayStyle.dark,
        child: Scaffold(
          backgroundColor: t.canvas,
          appBar: AppBar(
            backgroundColor: t.surfaceAlt,
            surfaceTintColor: Colors.transparent,
            leading: IconButton(
              tooltip:
                  _fromHistory &&
                      (_phase == _Phase.taking || _phase == _Phase.results)
                  ? 'Quiz history'
                  : 'Close quiz',
              icon: const Icon(Icons.close_rounded),
              onPressed: _closeQuiz,
            ),
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  switch (_phase) {
                    _Phase.setup || _Phase.generating => 'New quiz',
                    _Phase.taking => '${widget.title} quiz',
                    _Phase.results => 'Quiz results',
                  },
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  switch (_phase) {
                    _Phase.setup || _Phase.generating => widget.title,
                    _Phase.taking =>
                      'Question ${_index + 1} of ${_questions.length}',
                    _Phase.results =>
                      '$_correctCount / ${_questions.length} correct',
                  },
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTokens.mono(size: 11, color: t.textFaint),
                ),
              ],
            ),
            actions: [
              Padding(
                padding: const EdgeInsets.only(right: 12),
                child: _PremiumChip(),
              ),
            ],
          ),
          body: switch (_phase) {
            _Phase.setup => _SetupView(
              title: widget.title,
              config: _config,
              sourceLabel: _config.source.label(
                outline: _outlineTree,
                pageCount: widget.pageCount,
              ),
              online: online,
              queued: queued != null,
              hasHistory: hasHistory,
              historyEnabled: canAccessHistory,
              onChanged: (c) => setState(() => _config = c),
              onGenerate: _generate,
              onPickSource: _pickSource,
              onOpenHistory: _openHistory,
              onCancelQueue: () => unawaited(
                ref.read(quizQueueProvider.notifier).remove(widget.documentId),
              ),
            ),
            _Phase.generating => _GeneratingView(
              progress: _progress,
              status: _status,
            ),
            _Phase.taking => _TakingView(
              question: _current,
              index: _index,
              total: _questions.length,
              answered: _answers.length,
              revealed: _revealed,
              answer: _answers[_index],
              timer: _remaining,
              showTimer: _config.timer != QuizTimerMode.off,
              shortAnswer: _shortAnswer,
              onPick: _pick,
              onSubmitWritten: _submitWritten,
              onNext: _next,
              onOpenPage: _openSourcePage,
            ),
            _Phase.results => _ResultsView(
              questions: _questions,
              answers: _answers,
              onNewQuiz: () => setState(() {
                _fromHistory = false;
                _phase = _Phase.setup;
                _answers.clear();
                _index = 0;
                _revealed = false;
              }),
              onRetake: () => _beginAttempt(
                questions: _questions,
                familyId: _familyId,
                fromHistory: _fromHistory,
              ),
              onOpenPage: _openSourcePage,
            ),
          },
        ),
      ),
    );
  }
}

class _PremiumChip extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    final ent = ref.watch(entitlementProvider).asData?.value;
    final label = switch (ent?.tier) {
      EntitlementTier.trial => 'TRIAL',
      EntitlementTier.premium => 'PREMIUM',
      _ => 'FREE',
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: t.premiumSoft,
        borderRadius: BorderRadius.circular(100),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.workspace_premium_rounded, size: 14, color: t.premiumText),
          const SizedBox(width: 4),
          Text(
            label,
            style: AppTokens.sectionLabel(t.premiumText).copyWith(fontSize: 10),
          ),
        ],
      ),
    );
  }
}

class _SetupView extends StatelessWidget {
  const _SetupView({
    required this.title,
    required this.config,
    required this.sourceLabel,
    required this.online,
    required this.queued,
    required this.hasHistory,
    required this.historyEnabled,
    required this.onChanged,
    required this.onGenerate,
    required this.onPickSource,
    required this.onOpenHistory,
    required this.onCancelQueue,
  });

  final String title;
  final QuizConfig config;
  final String sourceLabel;
  final bool online;
  final bool queued;
  final bool hasHistory;
  final bool historyEnabled;
  final ValueChanged<QuizConfig> onChanged;
  final VoidCallback onGenerate;
  final VoidCallback onPickSource;
  final VoidCallback onOpenHistory;
  final VoidCallback onCancelQueue;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final wide = MediaQuery.sizeOf(context).width >= AppBreakpoints.phone;
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
        child: ListView(
          padding: EdgeInsets.fromLTRB(wide ? 28 : 18, 18, wide ? 28 : 18, 40),
          children: [
            Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: t.premium,
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: t.premium.withValues(alpha: 0.45),
                        blurRadius: 18,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Icon(Icons.quiz_rounded, color: t.premiumOn),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Create a quiz',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.3,
                        ),
                      ),
                      Text(
                        'AI-formulated from $title',
                        style: TextStyle(fontSize: 13, color: t.textMuted),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: historyEnabled ? 'Quiz history' : 'Quiz history (Premium)',
                  onPressed: historyEnabled ? onOpenHistory : null,
                  icon: Icon(
                    Icons.history_rounded,
                    color: historyEnabled ? t.premiumText : t.textFaint,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              'Notably writes a practice exam for you',
              style: TextStyle(
                fontSize: 13.5,
                height: 1.45,
                color: t.textSecondary,
              ),
            ),
            _OfflineQuizBanner(
              online: online,
              queued: queued,
              hasHistory: hasHistory,
              historyEnabled: historyEnabled,
              onOpenHistory: onOpenHistory,
              onCancelQueue: onCancelQueue,
            ),
            const SizedBox(height: 22),
            Text(
              'NUMBER OF QUESTIONS',
              style: AppTokens.sectionLabel(t.textFaint),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                for (final length in kQuizLengths)
                  _LengthCard(
                    length: length,
                    selected: config.count == length.count,
                    onTap: () =>
                        onChanged(config.copyWith(count: length.count)),
                  ),
              ],
            ),
            const SizedBox(height: 22),
            Text('QUESTION TYPES', style: AppTokens.sectionLabel(t.textFaint)),
            const SizedBox(height: 8),
            _TypeTile(
              label: 'Multiple choice',
              selected: config.kinds.contains(QuizKind.multipleChoice),
              onTap: () =>
                  onChanged(_toggleKind(config, QuizKind.multipleChoice)),
            ),
            _TypeTile(
              label: 'True / false',
              selected: config.kinds.contains(QuizKind.trueFalse),
              onTap: () => onChanged(_toggleKind(config, QuizKind.trueFalse)),
            ),
            _TypeTile(
              label: 'Short answer',
              selected: config.kinds.contains(QuizKind.shortAnswer),
              onTap: () => onChanged(_toggleKind(config, QuizKind.shortAnswer)),
            ),
            const SizedBox(height: 18),
            Text('DIFFICULTY', style: AppTokens.sectionLabel(t.textFaint)),
            const SizedBox(height: 10),
            _Segmented<QuizDifficulty>(
              value: config.difficulty,
              labels: const {
                QuizDifficulty.easy: 'Easy',
                QuizDifficulty.medium: 'Medium',
                QuizDifficulty.hard: 'Hard',
              },
              onChanged: (d) => onChanged(config.copyWith(difficulty: d)),
            ),
            const SizedBox(height: 18),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.menu_book_rounded, color: t.textMuted),
              title: const Text('Source pages'),
              subtitle: Text(sourceLabel),
              trailing: Icon(Icons.chevron_right_rounded, color: t.textFaint),
              onTap: onPickSource,
            ),
            const SizedBox(height: 8),
            Text(
              'TIMER PER QUESTION',
              style: AppTokens.sectionLabel(t.textFaint),
            ),
            const SizedBox(height: 10),
            _Segmented<QuizTimerMode>(
              value: config.timer,
              labels: const {
                QuizTimerMode.off: 'Off',
                QuizTimerMode.seconds30: '30s',
                QuizTimerMode.seconds60: '60s',
                QuizTimerMode.seconds90: '90s',
                QuizTimerMode.full: 'Full',
              },
              onChanged: (timer) => onChanged(config.copyWith(timer: timer)),
            ),
            const SizedBox(height: 28),
            FilledButton.icon(
              onPressed:
                  config.kinds.isEmpty ||
                      (config.source.mode == QuizSourceMode.sections &&
                          config.source.sectionIds.isEmpty)
                  ? null
                  : onGenerate,
              style: FilledButton.styleFrom(
                backgroundColor: t.premium,
                foregroundColor: t.premiumOn,
                minimumSize: const Size.fromHeight(52),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(Radii.control),
                ),
              ),
              icon: Icon(
                online ? Icons.auto_awesome_rounded : Icons.schedule_rounded,
              ),
              label: Text(
                online
                    ? 'Generate ${config.count}-question quiz'
                    : 'Queue ${config.count}-question quiz',
              ),
            ),
          ],
        ),
      ),
    );
  }

  static QuizConfig _toggleKind(QuizConfig config, QuizKind kind) {
    final next = {...config.kinds};
    if (!next.add(kind)) next.remove(kind);
    return config.copyWith(kinds: next);
  }
}

class _OfflineQuizBanner extends StatelessWidget {
  const _OfflineQuizBanner({
    required this.online,
    required this.queued,
    required this.hasHistory,
    required this.historyEnabled,
    required this.onOpenHistory,
    required this.onCancelQueue,
  });

  final bool online;
  final bool queued;
  final bool hasHistory;
  final bool historyEnabled;
  final VoidCallback onOpenHistory;
  final VoidCallback onCancelQueue;

  @override
  Widget build(BuildContext context) {
    if (online && !queued) return const SizedBox.shrink();
    final t = context.tokens;
    final scheme = Theme.of(context).colorScheme;
    final offline = !online;
    final (icon, title, body) = switch ((online, queued)) {
      (false, false) => (
        Icons.wifi_off_rounded,
        kNetworkErrorTitle,
        hasHistory
            ? '$kNoWifiOrMobileData Queue this one, or retake a quiz you already took.'
            : '$kNoWifiOrMobileData Queue this one and it will generate when you are back online.',
      ),
      (false, true) => (
        Icons.schedule_rounded,
        kNetworkErrorTitle,
        'No Wi-Fi or mobile data. This quiz is queued and will start automatically when you are back online.',
      ),
      _ => (
        Icons.cloud_done_rounded,
        'Ready to generate',
        'This quiz was queued while you were offline. Generate now, or remove it.',
      ),
    };
    final accent = offline ? scheme.error : t.premiumText;
    final fill = offline ? scheme.errorContainer : t.premiumSoft;
    final line = offline
        ? scheme.error.withValues(alpha: 0.35)
        : t.premium.withValues(alpha: 0.35);
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 12, 10, 10),
        decoration: BoxDecoration(
          color: fill,
          borderRadius: BorderRadius.circular(Radii.control),
          border: Border.all(color: line),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(icon, size: 18, color: accent),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: accent,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        body,
                        style: TextStyle(
                          fontSize: 13,
                          height: 1.4,
                          color: t.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (!online && hasHistory && historyEnabled) ...[
              const SizedBox(height: 4),
              TextButton(
                onPressed: onOpenHistory,
                child: Text(
                  'Open quiz history',
                  style: TextStyle(color: accent),
                ),
              ),
            ],
            if (queued)
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton(
                  onPressed: onCancelQueue,
                  child: Text(
                    'Remove from queue',
                    style: TextStyle(color: t.textMuted),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _LengthCard extends StatelessWidget {
  const _LengthCard({
    required this.length,
    required this.selected,
    required this.onTap,
  });

  final QuizLength length;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Material(
      color: selected ? t.premiumSoft : t.surface,
      borderRadius: BorderRadius.circular(Radii.card),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(Radii.card),
        child: Container(
          width: 148,
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(Radii.card),
            border: Border.all(color: selected ? t.premium : t.lineStrong),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    '${length.count}',
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const Spacer(),
                  if (selected)
                    Icon(
                      Icons.check_circle_rounded,
                      size: 18,
                      color: t.premium,
                    ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                length.label,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              Text(
                length.hint,
                style: AppTokens.mono(size: 11, color: t.textFaint),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TypeTile extends StatelessWidget {
  const _TypeTile({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return ListTile(
      onTap: onTap,
      contentPadding: EdgeInsets.zero,
      leading: Icon(
        selected
            ? Icons.check_box_rounded
            : Icons.check_box_outline_blank_rounded,
        color: selected ? t.premium : t.textMuted,
      ),
      title: Text(label),
    );
  }
}

class _Segmented<T> extends StatelessWidget {
  const _Segmented({
    required this.value,
    required this.labels,
    required this.onChanged,
  });

  final T value;
  final Map<T, String> labels;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: t.fill,
        borderRadius: BorderRadius.circular(Radii.control),
      ),
      child: Row(
        children: [
          for (final entry in labels.entries)
            Expanded(
              child: GestureDetector(
                onTap: () => onChanged(entry.key),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 140),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: value == entry.key ? t.surface : Colors.transparent,
                    borderRadius: BorderRadius.circular(Radii.inner),
                    boxShadow: value == entry.key
                        ? [
                            BoxShadow(
                              color: t.shadow.withValues(alpha: 0.1),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ]
                        : null,
                  ),
                  child: Text(
                    entry.value,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                      color: value == entry.key ? t.text : t.textMuted,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _GeneratingView extends StatelessWidget {
  const _GeneratingView({required this.progress, required this.status});

  final double progress;
  final String status;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final shown = progress.clamp(0.05, 1.0);
    final percent = (shown * 100).round();
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.auto_awesome_rounded, size: 36, color: t.premium),
            const SizedBox(height: 18),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 320),
              child: LinearProgressIndicator(
                value: shown,
                color: t.premium,
                backgroundColor: t.premiumSoft,
              ),
            ),
            const SizedBox(height: 12),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 320),
              child: Row(
                children: [
                  Expanded(
                    child: Text(status, style: TextStyle(color: t.textMuted)),
                  ),
                  Text(
                    '$percent%',
                    style: AppTokens.mono(
                      size: 13,
                      color: t.premiumText,
                      weight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TakingView extends StatelessWidget {
  const _TakingView({
    required this.question,
    required this.index,
    required this.total,
    required this.answered,
    required this.revealed,
    required this.answer,
    required this.timer,
    required this.showTimer,
    required this.shortAnswer,
    required this.onPick,
    required this.onSubmitWritten,
    required this.onNext,
    required this.onOpenPage,
  });

  final QuizQuestion question;
  final int index;
  final int total;
  final int answered;
  final bool revealed;
  final QuizAnswer? answer;
  final Duration timer;
  final bool showTimer;
  final TextEditingController shortAnswer;
  final ValueChanged<int> onPick;
  final VoidCallback onSubmitWritten;
  final VoidCallback onNext;
  final void Function(int pageIndex, [QuizSourceTarget? target]) onOpenPage;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final letters = const ['A', 'B', 'C', 'D', 'E'];
    final mm = timer.inMinutes.remainder(60).toString().padLeft(2, '0');
    final ss = timer.inSeconds.remainder(60).toString().padLeft(2, '0');
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 40),
          children: [
            Row(
              children: [
                Text(
                  switch (question.kind) {
                    QuizKind.multipleChoice => 'Multiple choice',
                    QuizKind.trueFalse => 'True / false',
                    QuizKind.shortAnswer => 'Short answer',
                  },
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: t.textSecondary,
                  ),
                ),
                const Spacer(),
                TextButton(
                  onPressed: () =>
                      onOpenPage(question.pageIndex, question.sourceTarget),
                  // The pen says the answer has been found on that page, so
                  // the student knows there is something to be shown.
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (question.location != null) ...[
                        Icon(
                          Icons.brush_rounded,
                          size: 13,
                          color: t.premiumText,
                        ),
                        const SizedBox(width: 4),
                      ],
                      Text(
                        'from p.${question.pageIndex + 1}',
                        style: AppTokens.mono(size: 12, color: t.premiumText),
                      ),
                    ],
                  ),
                ),
                if (showTimer) ...[
                  Icon(Icons.timer_outlined, size: 16, color: t.premiumText),
                  const SizedBox(width: 4),
                  Text(
                    '$mm:$ss',
                    style: AppTokens.mono(size: 13, color: t.premiumText),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 8),
            Text(
              question.prompt,
              style: const TextStyle(
                fontSize: 18,
                height: 1.35,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 18),
            if (question.choices.isNotEmpty)
              for (var i = 0; i < question.choices.length; i++)
                _ChoiceTile(
                  letter: letters[i],
                  label: question.choices[i],
                  selected: answer?.choiceIndex == i,
                  revealed: revealed,
                  correct: i == question.correctIndex,
                  onTap: () => onPick(i),
                )
            else ...[
              TextField(
                controller: shortAnswer,
                enabled: !revealed,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => onSubmitWritten(),
                decoration: const InputDecoration(hintText: 'Type your answer'),
              ),
              const SizedBox(height: 10),
              if (!revealed)
                Align(
                  alignment: Alignment.centerRight,
                  child: FilledButton(
                    onPressed: onSubmitWritten,
                    child: const Text('Check'),
                  ),
                ),
            ],
            if (revealed) ...[
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: (answer?.correct ?? false) ? t.premiumSoft : t.fill,
                  borderRadius: BorderRadius.circular(Radii.control),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      (answer?.correct ?? false)
                          ? 'Correct — ${question.acceptedAnswer}'
                          : 'Answer — ${question.acceptedAnswer}',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: (answer?.correct ?? false)
                            ? t.premiumText
                            : t.text,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Explanation',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                        color: t.textMuted,
                      ),
                    ),
                    const SizedBox(height: 4),
                    QuizExplanationText(
                      explanation: question.explanation,
                      fallbackPageIndex: question.pageIndex,
                      target: question.sourceTarget,
                      onOpenPage: onOpenPage,
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 22),
            Row(
              children: [
                Text(
                  '$answered answered · ${total - answered} remaining',
                  style: AppTokens.mono(size: 11, color: t.textFaint),
                ),
                const Spacer(),
                FilledButton.icon(
                  onPressed: revealed ? onNext : null,
                  icon: Icon(
                    index == total - 1
                        ? Icons.flag_rounded
                        : Icons.arrow_forward_rounded,
                  ),
                  label: Text(
                    index == total - 1 ? 'See results' : 'Next question',
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ChoiceTile extends StatelessWidget {
  const _ChoiceTile({
    required this.letter,
    required this.label,
    required this.selected,
    required this.revealed,
    required this.correct,
    required this.onTap,
  });

  final String letter;
  final String label;
  final bool selected;
  final bool revealed;
  final bool correct;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    Color border = t.lineStrong;
    Color fill = t.surface;
    if (revealed && correct) {
      border = t.premium;
      fill = t.premiumSoft;
    } else if (revealed && selected && !correct) {
      border = t.pdfBadge;
      fill = t.fill;
    } else if (selected) {
      border = t.accent;
      fill = t.accentSoft;
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: fill,
        borderRadius: BorderRadius.circular(Radii.control),
        child: InkWell(
          onTap: revealed ? null : onTap,
          borderRadius: BorderRadius.circular(Radii.control),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(Radii.control),
              border: Border.all(color: border),
            ),
            child: Row(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: t.fill,
                  ),
                  child: Text(
                    letter,
                    style: AppTokens.mono(size: 12, color: t.textSecondary),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(label, style: const TextStyle(fontSize: 15)),
                ),
                if (revealed && correct)
                  Icon(Icons.check_circle_rounded, color: t.premium),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ResultsView extends StatelessWidget {
  const _ResultsView({
    required this.questions,
    required this.answers,
    required this.onNewQuiz,
    required this.onRetake,
    required this.onOpenPage,
  });

  final List<QuizQuestion> questions;
  final Map<int, QuizAnswer> answers;
  final VoidCallback onNewQuiz;
  final VoidCallback onRetake;
  final void Function(int pageIndex, [QuizSourceTarget? target]) onOpenPage;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final correct = answers.values.where((a) => a.correct).length;
    final pct = questions.isEmpty
        ? 0
        : (correct * 100 / questions.length).round();
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 40),
          children: [
            Text(
              '$pct%',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 56, fontWeight: FontWeight.w800),
            ),
            Text(
              '$correct of ${questions.length} correct',
              textAlign: TextAlign.center,
              style: AppTokens.mono(size: 14, color: t.textMuted),
            ),
            const SizedBox(height: 22),
            FilledButton(
              onPressed: onNewQuiz,
              style: FilledButton.styleFrom(
                backgroundColor: t.premium,
                foregroundColor: t.premiumOn,
                minimumSize: const Size.fromHeight(48),
              ),
              child: const Text('New quiz'),
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: onRetake,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Retake quiz'),
              style: OutlinedButton.styleFrom(
                foregroundColor: t.premiumText,
                minimumSize: const Size.fromHeight(48),
                side: BorderSide(color: t.premium),
              ),
            ),
            const SizedBox(height: 18),
            for (var i = 0; i < questions.length; i++)
              ListTile(
                contentPadding: EdgeInsets.zero,
                onTap: () => onOpenPage(
                  questions[i].pageIndex,
                  questions[i].sourceTarget,
                ),
                leading: Icon(
                  (answers[i]?.correct ?? false)
                      ? Icons.check_circle_rounded
                      : Icons.cancel_outlined,
                  color: (answers[i]?.correct ?? false)
                      ? t.premium
                      : t.pdfBadge,
                ),
                title: Text(
                  questions[i].prompt.split('\n').last,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Text(
                  'See page ${questions[i].pageIndex + 1} · ${questions[i].acceptedAnswer}',
                  style: TextStyle(color: t.premiumText),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _SourcePickerSheet extends StatefulWidget {
  const _SourcePickerSheet({
    required this.pageCount,
    required this.outline,
    required this.initial,
  });

  final int pageCount;
  final List<OutlineNode> outline;
  final QuizSource initial;

  @override
  State<_SourcePickerSheet> createState() => _SourcePickerSheetState();
}

class _SourcePickerSheetState extends State<_SourcePickerSheet> {
  late QuizSourceMode _mode;
  late Set<String> _sectionIds;
  late int _start;
  late int _end;
  final _expanded = <String>{};

  @override
  void initState() {
    super.initState();
    _mode = widget.initial.mode;
    _sectionIds = OutlineNode.expandSelection(
      widget.initial.sectionIds,
      roots: widget.outline,
    );
    _start = widget.initial.startPage ?? 0;
    _end = widget.initial.endPage ?? math.max(0, widget.pageCount - 1);
    for (final root in widget.outline) {
      _expanded.add(root.id);
    }
    if (widget.outline.isEmpty && _mode == QuizSourceMode.sections) {
      _mode = QuizSourceMode.all;
    }
  }

  QuizSource _current() => switch (_mode) {
    QuizSourceMode.all => const QuizSource(),
    QuizSourceMode.sections => QuizSource(
      mode: QuizSourceMode.sections,
      sectionIds: _sectionIds,
    ),
    QuizSourceMode.pageRange => QuizSource(
      mode: QuizSourceMode.pageRange,
      startPage: math.min(_start, _end),
      endPage: math.max(_start, _end),
    ),
  };

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final height = MediaQuery.sizeOf(context).height * 0.72;
    return SizedBox(
      height: height,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Source pages',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: t.text,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context, _current()),
                  child: const Text('Done'),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 24),
              children: [
                _modeTile(
                  context,
                  mode: QuizSourceMode.all,
                  title: 'All pages',
                  subtitle: '${widget.pageCount} in this document',
                ),
                if (widget.outline.isNotEmpty)
                  _modeTile(
                    context,
                    mode: QuizSourceMode.sections,
                    title: 'Chapters and sections',
                    subtitle: 'Use the document table of contents',
                  ),
                _modeTile(
                  context,
                  mode: QuizSourceMode.pageRange,
                  title: 'Page range',
                  subtitle: widget.pageCount == 0
                      ? 'No pages'
                      : 'Pages ${_start + 1}–${_end + 1}',
                ),
                if (_mode == QuizSourceMode.pageRange &&
                    widget.pageCount > 1) ...[
                  const SizedBox(height: 8),
                  Text('FROM', style: AppTokens.sectionLabel(t.textFaint)),
                  Slider(
                    value: _start.toDouble(),
                    min: 0,
                    max: (widget.pageCount - 1).toDouble(),
                    divisions: widget.pageCount - 1,
                    label: '${_start + 1}',
                    onChanged: (v) => setState(() {
                      _start = v.round();
                      if (_end < _start) _end = _start;
                    }),
                  ),
                  Text('TO', style: AppTokens.sectionLabel(t.textFaint)),
                  Slider(
                    value: _end.toDouble(),
                    min: 0,
                    max: (widget.pageCount - 1).toDouble(),
                    divisions: widget.pageCount - 1,
                    label: '${_end + 1}',
                    onChanged: (v) => setState(() {
                      _end = v.round();
                      if (_start > _end) _start = _end;
                    }),
                  ),
                ],
                if (_mode == QuizSourceMode.sections &&
                    widget.outline.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text('SECTIONS', style: AppTokens.sectionLabel(t.textFaint)),
                  const SizedBox(height: 6),
                  for (final node in widget.outline) _sectionRow(node),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _modeTile(
    BuildContext context, {
    required QuizSourceMode mode,
    required String title,
    required String subtitle,
  }) {
    final t = context.tokens;
    final selected = _mode == mode;
    return ListTile(
      leading: Icon(
        selected
            ? Icons.radio_button_checked_rounded
            : Icons.radio_button_off_rounded,
        color: selected ? t.premiumText : t.textMuted,
      ),
      title: Text(title),
      subtitle: Text(subtitle),
      onTap: () => setState(() => _mode = mode),
    );
  }

  Widget _sectionRow(OutlineNode node) {
    final t = context.tokens;
    final subtree = node.subtreeIds;
    final selectedCount = subtree.where(_sectionIds.contains).length;
    final checked = selectedCount == subtree.length;
    final partial = selectedCount > 0 && !checked;
    final open = _expanded.contains(node.id);
    final indent = 8.0 + node.depth.clamp(0, 5) * 14.0;
    return Column(
      children: [
        ListTile(
          contentPadding: EdgeInsets.fromLTRB(indent, 0, 8, 0),
          leading: Icon(
            checked
                ? Icons.check_box_rounded
                : partial
                ? Icons.indeterminate_check_box_rounded
                : Icons.check_box_outline_blank_rounded,
            color: checked || partial ? t.premiumText : t.textMuted,
          ),
          title: Text(node.title, maxLines: 2, overflow: TextOverflow.ellipsis),
          subtitle: Text(
            'p.${node.pageNumber}',
            style: AppTokens.mono(size: 11, color: t.textFaint),
          ),
          trailing: node.hasChildren
              ? IconButton(
                  tooltip: open ? 'Collapse' : 'Expand',
                  onPressed: () => setState(() {
                    if (!_expanded.add(node.id)) _expanded.remove(node.id);
                  }),
                  icon: Icon(
                    open
                        ? Icons.expand_more_rounded
                        : Icons.chevron_right_rounded,
                    color: t.textMuted,
                  ),
                )
              : null,
          onTap: () => setState(() {
            _sectionIds = OutlineNode.toggleSubtree(_sectionIds, node);
          }),
        ),
        if (open)
          for (final child in node.children) _sectionRow(child),
      ],
    );
  }
}
