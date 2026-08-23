import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../app/design.dart';
import '../editor/providers.dart';
import '../editor/quiz/quiz_history.dart';
import '../editor/quiz/quiz_history_page.dart';
import '../library/providers.dart';
import 'entitlements.dart';
import 'premium_plan_sheet.dart';
import 'settings_widgets.dart';

/// All quiz attempts across documents — opened from Settings.
class GlobalQuizHistoryPage extends ConsumerWidget {
  const GlobalQuizHistoryPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    final hasAccess = ref.watch(hasPremiumFeaturesProvider);
    if (!hasAccess) {
      return Scaffold(
        backgroundColor: t.canvas,
        appBar: AppBar(backgroundColor: t.canvas, title: const Text('Quiz history')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.lock_outline_rounded, size: 40, color: t.textFaint),
                const SizedBox(height: 12),
                const Text(
                  'Quiz history is a Premium feature',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                Text(
                  'Upgrade to Premium to view and retake past quizzes.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: t.textMuted, height: 1.4),
                ),
                const SizedBox(height: 20),
                FilledButton(
                  onPressed: () => PremiumPlanSheet.show(context),
                  child: const Text('See Premium plans'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final async = ref.watch(allQuizHistoryProvider);
    final records = async.valueOrNull ?? const [];
    final stats = quizHistoryStats(records);

    return Scaffold(
      backgroundColor: t.canvas,
      appBar: AppBar(
        backgroundColor: t.canvas,
        title: const Text('Quiz history'),
      ),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => Center(
          child: Text('Could not load quiz history', style: TextStyle(color: t.textMuted)),
        ),
        data: (_) {
          if (records.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.history_rounded, size: 40, color: t.textFaint),
                    const SizedBox(height: 12),
                    const Text(
                      'No quizzes yet',
                      style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Generate a quiz from any document and your attempts will appear here.',
                      textAlign: TextAlign.center,
                      style: TextStyle(height: 1.4, color: t.textMuted),
                    ),
                  ],
                ),
              ),
            );
          }

          final byDocument = <String, List<QuizHistoryRecord>>{};
          for (final record in records) {
            (byDocument[record.documentId] ??= []).add(record);
          }

          return ListView(
            padding: const EdgeInsets.fromLTRB(18, 8, 18, 32),
            children: [
              _StatsRow(stats: stats),
              const SizedBox(height: 18),
              for (final entry in byDocument.entries)
                _DocumentHistoryTile(
                  documentId: entry.key,
                  records: entry.value,
                ),
            ],
          );
        },
      ),
    );
  }
}

class _StatsRow extends StatelessWidget {
  const _StatsRow({required this.stats});

  final QuizHistoryStats stats;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: _StatTile(value: '${stats.taken}', label: 'Quizzes taken')),
        const SizedBox(width: 10),
        Expanded(
          child: _StatTile(
            value: stats.taken == 0 ? '—' : '${stats.averagePercent}%',
            label: 'Avg score',
          ),
        ),
        const SizedBox(width: 10),
        Expanded(child: _StatTile(value: '${stats.dayStreak}', label: 'Day streak')),
      ],
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 14, 12, 12),
      decoration: BoxDecoration(
        color: t.surface,
        borderRadius: BorderRadius.circular(Radii.card),
        border: Border.all(color: t.line),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: AppTokens.mono(size: 22, color: t.text, weight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            textAlign: TextAlign.center,
            style: AppTokens.sectionLabel(t.textFaint).copyWith(fontSize: 9),
          ),
        ],
      ),
    );
  }
}

class _DocumentHistoryTile extends ConsumerWidget {
  const _DocumentHistoryTile({
    required this.documentId,
    required this.records,
  });

  final String documentId;
  final List<QuizHistoryRecord> records;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    final doc = ref.watch(documentStreamProvider(documentId)).asData?.value;
    final title = doc?.title.trim().isNotEmpty == true
        ? doc!.title.trim()
        : 'Document';
    final avg = records.isEmpty
        ? 0
        : (records.fold<int>(0, (n, r) => n + r.percent) / records.length)
            .round();
    final latest = records.first;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: SettingsGroupCard(
        children: [
          SettingsRow(
            icon: Icons.menu_book_outlined,
            title: title,
            subtitle:
                '${records.length} quiz${records.length == 1 ? '' : 'zes'} · $avg% avg · ${DateFormat.MMMd().format(latest.completedAt)}',
            trailing: Icon(Icons.chevron_right_rounded, color: t.textFaint),
            onTap: () {
              QuizHistoryPage.open(
                context,
                documentId: documentId,
                documentTitle: title,
              );
            },
          ),
        ],
      ),
    );
  }
}
