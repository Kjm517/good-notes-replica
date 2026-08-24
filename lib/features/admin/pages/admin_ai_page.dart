import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/design.dart';
import '../admin_api.dart';
import '../widgets/admin_stat_card.dart';
import '../widgets/admin_widgets.dart';

class AdminAiPage extends ConsumerStatefulWidget {
  const AdminAiPage({super.key});

  @override
  ConsumerState<AdminAiPage> createState() => _AdminAiPageState();
}

class _AdminAiPageState extends ConsumerState<AdminAiPage> {
  var _days = 30;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final aiAsync = ref.watch(adminAiProvider(_days));

    return aiAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => AdminErrorView(
        message: '$e',
        onRetry: () => ref.invalidate(adminAiProvider(_days)),
      ),
      data: (usage) => SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Expanded(
                  child: AdminPageHeader(
                    title: 'AI usage',
                    subtitle: 'Gemini quiz generation telemetry from the app.',
                  ),
                ),
                SegmentedButton<int>(
                  segments: const [
                    ButtonSegment(value: 7, label: Text('7d')),
                    ButtonSegment(value: 30, label: Text('30d')),
                    ButtonSegment(value: 90, label: Text('90d')),
                  ],
                  selected: {_days},
                  onSelectionChanged: (s) => setState(() => _days = s.first),
                ),
              ],
            ),
            const SizedBox(height: 20),
            LayoutBuilder(
              builder: (context, c) {
                final cols = c.maxWidth > 900 ? 3 : 1;
                return GridView.count(
                  crossAxisCount: cols,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: 14,
                  crossAxisSpacing: 14,
                  childAspectRatio: cols == 1 ? 2.8 : 1.6,
                  children: [
                    AdminStatCard(
                      label: 'Generations',
                      value: '${usage.totalEvents}',
                      trend: 'Last $_days days',
                      icon: Icons.auto_awesome_outlined,
                    ),
                    AdminStatCard(
                      label: 'Tokens',
                      value: _formatTokens(usage.totalPromptTokens + usage.totalOutputTokens),
                      trend: '${usage.totalPromptTokens} in · ${usage.totalOutputTokens} out',
                      icon: Icons.token_outlined,
                    ),
                    AdminStatCard(
                      label: 'Est. spend',
                      value: '\$${usage.estimatedSpendUsd.toStringAsFixed(2)}',
                      trend: 'Blended Gemini estimate',
                      icon: Icons.payments_outlined,
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 24),
            Text('Top users', style: AppTokens.sectionLabel(t.textFaint)),
            const SizedBox(height: 10),
            AdminDataTable(
              columns: const ['UID', 'Events', 'Tokens'],
              emptyMessage: 'No AI events recorded yet.',
              rows: [
                for (final u in usage.byUser.take(20))
                  [
                    Text(shortUid(u.uid), style: AppTokens.mono(size: 11, color: t.text)),
                    Text('${u.events}', style: TextStyle(color: t.textSecondary)),
                    Text(_formatTokens(u.tokens), style: TextStyle(color: t.textSecondary)),
                  ],
              ],
            ),
            const SizedBox(height: 24),
            Text('Recent events', style: AppTokens.sectionLabel(t.textFaint)),
            const SizedBox(height: 10),
            AdminDataTable(
              columns: const ['Feature', 'User', 'Tokens', 'When'],
              emptyMessage: 'No recent events.',
              rows: [
                for (final e in usage.recent.take(15))
                  [
                    Text(e.feature, style: TextStyle(color: t.text)),
                    Text(shortUid(e.uid), style: AppTokens.mono(size: 10, color: t.textFaint)),
                    Text(
                      _formatTokens(e.promptTokens + e.outputTokens),
                      style: TextStyle(color: t.textSecondary),
                    ),
                    Text(
                      e.createdAt.length >= 16 ? e.createdAt.substring(0, 16).replaceFirst('T', ' ') : e.createdAt,
                      style: AppTokens.mono(size: 10, color: t.textMuted),
                    ),
                  ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatTokens(int n) {
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}k';
    return '$n';
  }
}
