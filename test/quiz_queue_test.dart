import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:notably/core/network/network_status.dart';
import 'package:notably/features/editor/quiz/quiz_models.dart';
import 'package:notably/features/editor/quiz/quiz_queue.dart';

void main() {
  test('QuizConfig round-trips source sections and kinds', () {
    const config = QuizConfig(
      count: 50,
      kinds: {QuizKind.shortAnswer, QuizKind.trueFalse},
      difficulty: QuizDifficulty.hard,
      timer: QuizTimerMode.seconds60,
      source: QuizSource(
        mode: QuizSourceMode.sections,
        sectionIds: {'ch-2', 'ch-3'},
        startPage: 4,
        endPage: 18,
      ),
    );
    final restored = QuizConfig.fromJson(config.toJson());
    expect(restored.count, 50);
    expect(restored.kinds, config.kinds);
    expect(restored.difficulty, QuizDifficulty.hard);
    expect(restored.timer, QuizTimerMode.seconds60);
    expect(restored.source.mode, QuizSourceMode.sections);
    expect(restored.source.sectionIds, {'ch-2', 'ch-3'});
    expect(restored.source.startPage, 4);
    expect(restored.source.endPage, 18);
  });

  test('parseQuizQueue skips junk and empty document ids', () {
    final queuedAt = DateTime.utc(2026, 8, 19, 12);
    final job = QueuedQuizJob(
      documentId: 'doc-1',
      title: 'Cell biology',
      config: QuizConfig.defaults,
      queuedAt: queuedAt,
    );
    final raw = encodeQuizQueue([job]);
    final parsed = parseQuizQueue(raw);
    expect(parsed, hasLength(1));
    expect(parsed.single.documentId, 'doc-1');
    expect(parsed.single.title, 'Cell biology');
    expect(parsed.single.config.count, 25);
    expect(parsed.single.queuedAt.toUtc(), queuedAt);

    expect(parseQuizQueue(null), isEmpty);
    expect(parseQuizQueue('not-json'), isEmpty);
    expect(parseQuizQueue('{"documentId":"x"}'), isEmpty);
    expect(
      parseQuizQueue(
        '[{"documentId":""},{"documentId":"ok","title":"T","config":{}}]',
      ),
      hasLength(1),
    );
  });

  test('hasNetworkInterface treats none as offline', () {
    expect(hasNetworkInterface(const []), isFalse);
    expect(hasNetworkInterface(const [ConnectivityResult.none]), isFalse);
    expect(hasNetworkInterface(const [ConnectivityResult.wifi]), isTrue);
    expect(
      hasNetworkInterface(const [
        ConnectivityResult.none,
        ConnectivityResult.mobile,
      ]),
      isTrue,
    );
  });

  test('isQuizNetworkError ignores HTTP API failures', () {
    expect(
      isQuizNetworkError(Exception('ClientException: Failed to fetch')),
      isTrue,
    );
    expect(
      isQuizNetworkError(
        Exception('SocketException: Failed host lookup: generativelanguage'),
      ),
      isTrue,
    );
    expect(isQuizNetworkError(Exception('HTTP 429 RESOURCE_EXHAUSTED')), isFalse);
    expect(isQuizNetworkError(Exception('HTTP 404 NOT_FOUND')), isFalse);
    expect(
      isQuizNetworkError(StateError('Gemini did not return usable exam questions.')),
      isFalse,
    );
  });
}
