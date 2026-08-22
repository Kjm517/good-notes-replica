import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../app/design.dart';
import '../../../app/page_routes.dart';
import '../../../core/models/outline_entry.dart';
import '../../library/providers.dart';
import '../providers.dart';
import 'quiz_history.dart';
import 'quiz_models.dart';
import 'quiz_source_preview.dart';

class QuizHistoryAction {
  const QuizHistoryAction({required this.record, this.missedOnly = false});

  final QuizHistoryRecord record;
  final bool missedOnly;
}

/// Past quizzes for one opened file — redesign quiz history.
class QuizHistoryPage extends ConsumerWidget {
  const QuizHistoryPage({
    super.key,
    required this.documentId,
    required this.documentTitle,
    this.onJumpToPage,
  });

  final String documentId;
  final String documentTitle;
  final void Function(int pageIndex, [QuizSourceTarget? target])? onJumpToPage;

  static Future<QuizHistoryAction?> open(
    BuildContext context, {
    required String documentId,
    required String documentTitle,
    void Function(int pageIndex, [QuizSourceTarget? target])? onJumpToPage,
  }) {
    return Navigator.of(context).push<QuizHistoryAction>(
      notablyRoute(
        builder: (_) => QuizHistoryPage(
          documentId: documentId,
          documentTitle: documentTitle,
          onJumpToPage: onJumpToPage,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    final async = ref.watch(quizHistoryProvider(documentId));
    final records = async.valueOrNull ?? const <QuizHistoryRecord>[];
    final stats = quizHistoryStats(records);
    final groups = groupQuizHistory(records);
    final doc = ref.watch(documentStreamProvider(documentId)).asData?.value;
    final pageCount =
        ref.watch(documentPageCountProvider(documentId)).asData?.value ?? 0;
    final outline = OutlineNode.nest(OutlineEntry.decode(doc?.outline));

    return Scaffold(
      backgroundColor: t.canvas,
      appBar: AppBar(
        backgroundColor: t.surfaceAlt,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          tooltip: 'Back',
          icon: Icon(notablyBackIcon),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: const Text(
          'Quiz history',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
        actions: [
          if (records.isNotEmpty)
            TextButton(
              onPressed: () => _clearAll(context, ref),
              child: Text(
                'Clear all',
                style: TextStyle(color: t.textSecondary),
              ),
            ),
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
              decoration: BoxDecoration(
                color: t.premiumSoft,
                borderRadius: BorderRadius.circular(100),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.workspace_premium_rounded,
                    size: 14,
                    color: t.premiumText,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'PREMIUM',
                    style: AppTokens.sectionLabel(
                      t.premiumText,
                    ).copyWith(fontSize: 10),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      body: async.isLoading && records.isEmpty
          ? Center(child: CircularProgressIndicator(color: t.premium))
          : Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 720),
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(18, 16, 18, 40),
                  children: [
                    _StatsRow(stats: stats),
                    const SizedBox(height: 18),
                    if (groups.isEmpty)
                      _EmptyHistory(documentTitle: documentTitle)
                    else
                      for (final group in groups) ...[
                        _HistoryCard(
                          group: group,
                          bookTitle: documentTitle,
                          outline: outline,
                          pageCount: pageCount,
                          onOpen: () {
                            if (!group.latest.completed) {
                              Navigator.pop(
                                context,
                                QuizHistoryAction(record: group.latest),
                              );
                              return;
                            }
                            _openReview(
                              context,
                              group,
                              outline: outline,
                              pageCount: pageCount,
                            );
                          },
                          onRetake: () => Navigator.pop(
                            context,
                            QuizHistoryAction(record: group.latest),
                          ),
                          onDelete: () => _deleteGroup(context, ref, group),
                        ),
                        const SizedBox(height: 12),
                      ],
                  ],
                ),
              ),
            ),
    );
  }

  Future<void> _openReview(
    BuildContext context,
    QuizHistoryGroup group, {
    required List<OutlineNode> outline,
    required int pageCount,
  }) async {
    final action = await Navigator.of(context).push<QuizHistoryAction>(
      notablyRoute(
        builder: (_) => _HistoryReviewPage(
          group: group,
          headline: quizHeadline(
            group.latest,
            bookTitle: documentTitle,
            outline: outline,
            pageCount: pageCount,
          ),
          bookTitle: documentTitle,
          onJumpToPage: onJumpToPage,
        ),
      ),
    );
    if (action != null && context.mounted) {
      Navigator.pop(context, action);
    }
  }

  Future<void> _deleteGroup(
    BuildContext context,
    WidgetRef ref,
    QuizHistoryGroup group,
  ) async {
    final latest = group.latest;
    final extra = group.attempts.length > 1
        ? ' This also removes ${group.attempts.length - 1} retake'
              '${group.attempts.length == 2 ? '' : 's'}.'
        : '';
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete quiz?'),
        content: Text('“${latest.title}” will be removed from history.$extra'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    await ref
        .read(quizHistoryRepositoryProvider)
        .deleteFamily(documentId: documentId, familyId: latest.familyId);
  }

  Future<void> _clearAll(BuildContext context, WidgetRef ref) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Clear all quizzes?'),
        content: const Text(
          'Every saved quiz for this document will be deleted. '
          'This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Clear all'),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    await ref
        .read(quizHistoryRepositoryProvider)
        .deleteAllForDocument(documentId);
  }
}

class _StatsRow extends StatelessWidget {
  const _StatsRow({required this.stats});

  final QuizHistoryStats stats;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _StatTile(value: '${stats.taken}', label: 'Quizzes taken'),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _StatTile(
            value: stats.taken == 0 ? '—' : '${stats.averagePercent}%',
            label: 'Avg score',
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _StatTile(value: '${stats.dayStreak}', label: 'Day streak'),
        ),
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
            style: AppTokens.mono(
              size: 22,
              color: t.text,
              weight: FontWeight.w700,
            ),
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

class _EmptyHistory extends StatelessWidget {
  const _EmptyHistory({required this.documentTitle});

  final String documentTitle;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Padding(
      padding: const EdgeInsets.only(top: 36),
      child: Column(
        children: [
          Icon(Icons.history_rounded, size: 40, color: t.textFaint),
          const SizedBox(height: 12),
          const Text(
            'No quizzes yet',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          Text(
            'Generate a quiz from $documentTitle and it will show up here.',
            textAlign: TextAlign.center,
            style: TextStyle(height: 1.4, color: t.textMuted),
          ),
        ],
      ),
    );
  }
}

class _HistoryCard extends StatelessWidget {
  const _HistoryCard({
    required this.group,
    required this.bookTitle,
    required this.outline,
    required this.pageCount,
    required this.onOpen,
    required this.onRetake,
    required this.onDelete,
  });

  final QuizHistoryGroup group;
  final String bookTitle;
  final List<OutlineNode> outline;
  final int pageCount;
  final VoidCallback onOpen;
  final VoidCallback onRetake;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final latest = group.latest;
    final trail = group.scoreTrail;
    final taken = latest.completed;
    final headline = quizHeadline(
      latest,
      bookTitle: bookTitle,
      outline: outline,
      pageCount: pageCount,
    );
    final showBook =
        headline.toLowerCase() != bookTitle.trim().toLowerCase() &&
        bookTitle.trim().isNotEmpty;
    final meta = taken
        ? '${latest.correctCount}/${latest.questionCount}'
              ' · ${_relativeDay(latest.completedAt)}'
        : '${latest.questionCount} questions · Not taken';
    return Material(
      color: t.surface,
      borderRadius: BorderRadius.circular(Radii.card),
      child: InkWell(
        onTap: onOpen,
        borderRadius: BorderRadius.circular(Radii.card),
        child: Container(
          padding: const EdgeInsets.fromLTRB(14, 14, 8, 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(Radii.card),
            border: Border.all(color: t.line),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  SizedBox(
                    width: 64,
                    child: Text(
                      taken ? '${latest.percent}%' : '—',
                      style: AppTokens.mono(
                        size: 22,
                        color: taken ? t.premiumText : t.textMuted,
                        weight: FontWeight.w700,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          headline,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        if (showBook) ...[
                          const SizedBox(height: 2),
                          Text(
                            bookTitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 13,
                              color: t.textSecondary,
                            ),
                          ),
                        ],
                        const SizedBox(height: 2),
                        Text(
                          meta,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTokens.mono(size: 11, color: t.textMuted),
                        ),
                      ],
                    ),
                  ),
                  TextButton.icon(
                    onPressed: onRetake,
                    icon: Icon(
                      taken ? Icons.refresh_rounded : Icons.play_arrow_rounded,
                      size: 18,
                      color: t.premiumText,
                    ),
                    label: Text(
                      taken ? 'Retake' : 'Take',
                      style: TextStyle(color: t.premiumText),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Delete quiz',
                    icon: Icon(
                      Icons.delete_outline_rounded,
                      color: t.textMuted,
                    ),
                    onPressed: onDelete,
                  ),
                ],
              ),
              if (trail.length > 1) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    Text(
                      'Attempts',
                      style: AppTokens.sectionLabel(
                        t.textFaint,
                      ).copyWith(fontSize: 9),
                    ),
                    const SizedBox(width: 8),
                    for (var i = 0; i < trail.length; i++) ...[
                      if (i > 0)
                        Icon(
                          Icons.arrow_forward_rounded,
                          size: 12,
                          color: t.textFaint,
                        ),
                      Text(
                        '${trail[i]}%',
                        style: AppTokens.mono(
                          size: 11,
                          color: i == trail.length - 1
                              ? t.premiumText
                              : t.textMuted,
                          weight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _HistoryReviewPage extends StatelessWidget {
  const _HistoryReviewPage({
    required this.group,
    required this.headline,
    required this.bookTitle,
    this.onJumpToPage,
  });

  final QuizHistoryGroup group;
  final String headline;
  final String bookTitle;
  final void Function(int pageIndex, [QuizSourceTarget? target])? onJumpToPage;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final latest = group.latest;
    final previous = group.attempts.length > 1 ? group.attempts[1] : null;
    final improved = previous != null && latest.percent > previous.percent;
    final missed = latest.missedQuestions;

    return Scaffold(
      backgroundColor: t.canvas,
      appBar: AppBar(
        backgroundColor: t.surfaceAlt,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          tooltip: 'Close',
          icon: const Icon(Icons.close_rounded),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Results',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            Text(
              headline.toLowerCase() == bookTitle.trim().toLowerCase()
                  ? headline
                  : '$headline · $bookTitle',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTokens.mono(size: 11, color: t.textFaint),
            ),
          ],
        ),
      ),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 40),
            children: [
              Text(
                '${latest.percent}%',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 56,
                  fontWeight: FontWeight.w800,
                ),
              ),
              Text(
                '${latest.correctCount} of ${latest.questionCount}',
                textAlign: TextAlign.center,
                style: AppTokens.mono(size: 14, color: t.textMuted),
              ),
              if (improved) ...[
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.trending_up_rounded, size: 16, color: t.premium),
                    const SizedBox(width: 6),
                    Text(
                      'Best yet — up from ${previous.percent}%',
                      style: TextStyle(color: t.premiumText),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: _ReviewStat(
                      icon: Icons.check_circle_rounded,
                      value: '${latest.correctCount}',
                      label: 'Correct',
                      color: t.premium,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _ReviewStat(
                      icon: Icons.cancel_rounded,
                      value: '${latest.missedCount}',
                      label: 'Missed',
                      color: t.pdfBadge,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _ReviewStat(
                      icon: Icons.timer_outlined,
                      value: formatQuizClock(latest.duration),
                      label: 'Time',
                      color: t.textMuted,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (missed.isNotEmpty)
                _ActionTile(
                  icon: Icons.tune_rounded,
                  title: 'Retake — missed only',
                  subtitle: 'Practise the ${missed.length} you got wrong',
                  onTap: () => Navigator.pop(
                    context,
                    QuizHistoryAction(record: latest, missedOnly: true),
                  ),
                ),
              _ActionTile(
                icon: Icons.refresh_rounded,
                title: 'Retake quiz',
                subtitle: 'Same questions, new attempt',
                onTap: () =>
                    Navigator.pop(context, QuizHistoryAction(record: latest)),
              ),
              const SizedBox(height: 12),
              for (var i = 0; i < latest.questions.length; i++)
                _ReviewQuestion(
                  index: i,
                  question: latest.questions[i],
                  answer: latest.answers.elementAtOrNull(i),
                  onOpenPage: onJumpToPage,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ReviewStat extends StatelessWidget {
  const _ReviewStat({
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String value;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 12, 10, 12),
      decoration: BoxDecoration(
        color: t.surface,
        borderRadius: BorderRadius.circular(Radii.control),
        border: Border.all(color: t.line),
      ),
      child: Column(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(height: 6),
          Text(
            value,
            style: AppTokens.mono(
              size: 18,
              color: t.text,
              weight: FontWeight.w700,
            ),
          ),
          Text(
            label,
            style: AppTokens.sectionLabel(t.textFaint).copyWith(fontSize: 9),
          ),
        ],
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: t.surface,
        borderRadius: BorderRadius.circular(Radii.control),
        child: ListTile(
          onTap: onTap,
          leading: Icon(icon, color: t.premiumText),
          title: Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          subtitle: Text(subtitle, style: TextStyle(color: t.textMuted)),
          trailing: Icon(Icons.chevron_right_rounded, color: t.textFaint),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(Radii.control),
            side: BorderSide(color: t.line),
          ),
        ),
      ),
    );
  }
}

class _ReviewQuestion extends StatelessWidget {
  const _ReviewQuestion({
    required this.index,
    required this.question,
    required this.answer,
    this.onOpenPage,
  });

  final int index;
  final QuizQuestion question;
  final QuizAnswer? answer;
  final void Function(int pageIndex, [QuizSourceTarget? target])? onOpenPage;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final ok = answer?.correct ?? false;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
        decoration: BoxDecoration(
          color: t.surface,
          borderRadius: BorderRadius.circular(Radii.control),
          border: Border.all(color: t.line),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  ok ? Icons.check_circle_rounded : Icons.cancel_outlined,
                  size: 18,
                  color: ok ? t.premium : t.pdfBadge,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    question.prompt.split('\n').last,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            QuizExplanationText(
              explanation: question.explanation,
              fallbackPageIndex: question.pageIndex,
              target: question.sourceTarget,
              onOpenPage: (page, [target]) {
                onOpenPage?.call(page, target);
              },
            ),
          ],
        ),
      ),
    );
  }
}

String _relativeDay(DateTime when, [DateTime? now]) {
  final n = now ?? DateTime.now();
  final day = DateTime(when.year, when.month, when.day);
  final today = DateTime(n.year, n.month, n.day);
  final diff = today.difference(day).inDays;
  if (diff == 0) return 'today';
  if (diff == 1) return 'yesterday';
  return DateFormat('MMM d').format(when);
}
