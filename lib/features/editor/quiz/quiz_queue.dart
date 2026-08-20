import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import 'quiz_models.dart';

/// A quiz the user asked for while Gemini could not be reached.
class QueuedQuizJob {
  const QueuedQuizJob({
    required this.documentId,
    required this.title,
    required this.config,
    required this.queuedAt,
  });

  final String documentId;
  final String title;
  final QuizConfig config;
  final DateTime queuedAt;

  Map<String, dynamic> toJson() => {
        'documentId': documentId,
        'title': title,
        'config': config.toJson(),
        'queuedAt': queuedAt.toIso8601String(),
      };

  factory QueuedQuizJob.fromJson(Map<String, dynamic> json) {
    final configRaw = json['config'];
    return QueuedQuizJob(
      documentId: json['documentId'] as String? ?? '',
      title: json['title'] as String? ?? '',
      config: configRaw is Map
          ? QuizConfig.fromJson(Map<String, dynamic>.from(configRaw))
          : QuizConfig.defaults,
      queuedAt: DateTime.tryParse(json['queuedAt'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
    );
  }
}

/// Parses the SharedPreferences JSON list. Invalid entries are skipped.
List<QueuedQuizJob> parseQuizQueue(String? raw) {
  if (raw == null || raw.isEmpty) return const [];
  try {
    final decoded = jsonDecode(raw);
    if (decoded is! List) return const [];
    return [
      for (final item in decoded)
        if (item is Map)
          QueuedQuizJob.fromJson(Map<String, dynamic>.from(item)),
    ].where((job) => job.documentId.isNotEmpty).toList();
  } catch (_) {
    return const [];
  }
}

String encodeQuizQueue(List<QueuedQuizJob> jobs) =>
    jsonEncode([for (final job in jobs) job.toJson()]);

/// One pending generate-request per document, persisted locally.
class QuizQueueController extends Notifier<List<QueuedQuizJob>> {
  static const prefsKey = 'quiz_generation_queue';

  @override
  List<QueuedQuizJob> build() {
    return parseQuizQueue(ref.watch(sharedPrefsProvider).getString(prefsKey));
  }

  QueuedQuizJob? forDocument(String documentId) {
    for (final job in state) {
      if (job.documentId == documentId) return job;
    }
    return null;
  }

  Future<void> enqueue(QueuedQuizJob job) async {
    state = [
      for (final existing in state)
        if (existing.documentId != job.documentId) existing,
      job,
    ];
    await _persist();
  }

  Future<void> remove(String documentId) async {
    state = [
      for (final job in state)
        if (job.documentId != documentId) job,
    ];
    await _persist();
  }

  Future<void> _persist() async {
    await ref.read(sharedPrefsProvider).setString(
          prefsKey,
          encodeQuizQueue(state),
        );
  }
}

final quizQueueProvider =
    NotifierProvider<QuizQueueController, List<QueuedQuizJob>>(
  QuizQueueController.new,
);
