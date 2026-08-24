import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/design.dart';
import '../admin_api.dart';
import '../csv_export.dart';
import '../widgets/admin_widgets.dart';

class AdminSubscriptionsPage extends ConsumerStatefulWidget {
  const AdminSubscriptionsPage({super.key});

  @override
  ConsumerState<AdminSubscriptionsPage> createState() => _AdminSubscriptionsPageState();
}

class _AdminSubscriptionsPageState extends ConsumerState<AdminSubscriptionsPage> {
  Future<void> _toggle(AdminSubscriptionRow row) async {
    final api = ref.read(adminApiServiceProvider);
    if (api == null) return;
    try {
      await api.updateSubscription(
        row.uid,
        isPremium: !row.isPremium,
        plan: row.plan ?? 'monthly',
      );
      ref.invalidate(adminSubscriptionsProvider);
      ref.invalidate(adminOverviewProvider(30));
      ref.invalidate(adminBadgeCountsProvider);
      ref.invalidate(adminUsersProvider(''));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(row.isPremium ? 'Revoked premium' : 'Granted premium')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final subsAsync = ref.watch(adminSubscriptionsProvider);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AdminPageHeader(
            title: 'Subscriptions',
            subtitle: 'PayMongo wallet entitlements stored in R2.',
            trailing: subsAsync.asData == null
                ? null
                : OutlinedButton.icon(
                    onPressed: () async {
                      final subs = subsAsync.asData!.value;
                      await exportCsv(
                        filename: 'notably-subscriptions.csv',
                        headers: const ['uid', 'email', 'plan', 'expires', 'mrr_php'],
                        rows: [
                          for (final s in subs)
                            [
                              s.uid,
                              s.email ?? '',
                              s.plan ?? '',
                              s.expiresAt ?? '',
                              s.mrrPhp.toStringAsFixed(2),
                            ],
                        ],
                      );
                    },
                    icon: const Icon(Icons.download_outlined, size: 18),
                    label: const Text('CSV'),
                  ),
          ),
          const SizedBox(height: 16),
          subsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => AdminErrorView(
              message: '$e',
              onRetry: () => ref.invalidate(adminSubscriptionsProvider),
            ),
            data: (subs) {
              final active = subs.where((s) => s.isPremium).toList();
              final mrr = active.fold<double>(0, (s, r) => s + r.mrrPhp);
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      _MetricChip(label: 'Active', value: '${active.length}', t: t),
                      const SizedBox(width: 10),
                      _MetricChip(label: 'MRR', value: formatPhp(mrr.round()), t: t),
                    ],
                  ),
                  const SizedBox(height: 16),
                  AdminDataTable(
                    columns: const ['User', 'Plan', 'Expires', 'MRR', ''],
                    // Wider than the icon default: this column holds a
                    // "Revoke"/"Grant" text button, which 52px would clip.
                    actionWidth: 104,
                    flex: const [5, 2, 2, 2],
                    emptyMessage: 'No subscription records yet.',
                    rows: [
                      for (final s in subs)
                        [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                s.email ?? shortUid(s.uid),
                                style: TextStyle(fontWeight: FontWeight.w600, color: t.text),
                              ),
                              Text(shortUid(s.uid), style: AppTokens.mono(size: 10, color: t.textFaint)),
                            ],
                          ),
                          AdminStatusChip(
                            label: s.isPremium ? (s.plan ?? 'premium') : 'lapsed',
                            color: s.isPremium ? t.success : t.textMuted,
                          ),
                          Text(
                            s.expiresAt?.substring(0, 10) ?? '—',
                            style: AppTokens.mono(size: 11, color: t.textMuted),
                          ),
                          Text(formatPhp(s.mrrPhp.round()), style: TextStyle(color: t.textSecondary)),
                          TextButton(
                            onPressed: () => _toggle(s),
                            child: Text(s.isPremium ? 'Revoke' : 'Grant'),
                          ),
                        ],
                    ],
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _MetricChip extends StatelessWidget {
  const _MetricChip({required this.label, required this.value, required this.t});

  final String label;
  final String value;
  final AppTokens t;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: t.surface,
        borderRadius: BorderRadius.circular(Radii.control),
        border: Border.all(color: t.line),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: AppTokens.mono(size: 11, color: t.textFaint)),
          const SizedBox(width: 8),
          Text(value, style: TextStyle(fontWeight: FontWeight.w700, color: t.text)),
        ],
      ),
    );
  }
}
