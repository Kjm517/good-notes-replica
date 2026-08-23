import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/design.dart';
import '../admin_api.dart';
import '../admin_section.dart';
import '../widgets/admin_stat_card.dart';
import '../widgets/admin_widgets.dart';

class AdminOverviewPage extends ConsumerStatefulWidget {
  const AdminOverviewPage({super.key});

  @override
  ConsumerState<AdminOverviewPage> createState() => _AdminOverviewPageState();
}

class _AdminOverviewPageState extends ConsumerState<AdminOverviewPage> {
  var _days = 30;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final overviewAsync = ref.watch(adminOverviewProvider(_days));

    return overviewAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => AdminErrorView(
        message: '$e',
        onRetry: () => ref.invalidate(adminOverviewProvider(_days)),
      ),
      data: (data) => SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Text(
                  'Overview',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: t.text,
                  ),
                ),
                const Spacer(),
                _PeriodPills(
                  tokens: t,
                  selected: _days,
                  onSelected: (d) => setState(() => _days = d),
                ),
              ],
            ),
            const SizedBox(height: 20),
            LayoutBuilder(
              builder: (context, c) {
                final cols = c.maxWidth > 1100 ? 4 : (c.maxWidth > 640 ? 2 : 1);
                return GridView.count(
                  crossAxisCount: cols,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: 14,
                  crossAxisSpacing: 14,
                  childAspectRatio: cols == 1 ? 2.6 : 1.55,
                  children: [
                    AdminStatCard(
                      label: 'Total users',
                      value: '${data.totalUsers}',
                      trend: '${data.fileCount} files in R2',
                      icon: Icons.group_outlined,
                    ),
                    AdminStatCard(
                      label: 'Premium accounts',
                      value: '${data.premiumAccounts}',
                      trend: 'PayMongo entitlements',
                      icon: Icons.workspace_premium_outlined,
                    ),
                    AdminStatCard(
                      label: 'MRR',
                      value: formatPhp(data.mrrPhp),
                      trend: 'Estimated recurring',
                      icon: Icons.payments_outlined,
                    ),
                    AdminStatCard(
                      label: 'AI spend',
                      value: '\$${data.aiSpendEstimateUsd.toStringAsFixed(2)}',
                      trend: '${data.aiEventsInPeriod} events · $_days d',
                      icon: Icons.auto_awesome_outlined,
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 24),
            Text('Needs attention', style: AppTokens.sectionLabel(t.textFaint)),
            const SizedBox(height: 10),
            _AttentionRow(
              icon: Icons.bug_report_outlined,
              title: 'Open bug reports',
              subtitle: 'From Settings → Report a bug',
              badge: data.openBugs > 0 ? '${data.openBugs}' : null,
              tokens: t,
              onTap: () => context.go(AdminSection.bugs.location),
            ),
            _AttentionRow(
              icon: Icons.cloud_outlined,
              title: 'Storage',
              subtitle: formatStorageBytes(data.storageBytes),
              tokens: t,
              onTap: () => context.go(AdminSection.documents.location),
            ),
            _AttentionRow(
              icon: Icons.receipt_long_outlined,
              title: 'Subscriptions',
              subtitle: '${data.premiumAccounts} active premium',
              tokens: t,
              onTap: () => context.go(AdminSection.subscriptions.location),
            ),
          ],
        ),
      ),
    );
  }
}

class _PeriodPills extends StatelessWidget {
  const _PeriodPills({
    required this.tokens,
    required this.selected,
    required this.onSelected,
  });

  final AppTokens tokens;
  final int selected;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    final t = tokens;
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: t.fill,
        borderRadius: BorderRadius.circular(Radii.control),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final (days, label) in [(7, '7d'), (30, '30d'), (90, '90d')])
            GestureDetector(
              onTap: () => onSelected(days),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: selected == days ? t.surface : Colors.transparent,
                  borderRadius: BorderRadius.circular(Radii.inner),
                  boxShadow: selected == days
                      ? AppTokens.elevation(t.shadow, y: 2, blur: 8, opacity: 0.06)
                      : null,
                ),
                child: Text(
                  label,
                  style: AppTokens.mono(
                    size: 11,
                    weight: selected == days ? FontWeight.w600 : FontWeight.w500,
                    color: selected == days ? t.text : t.textMuted,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _AttentionRow extends StatelessWidget {
  const _AttentionRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.tokens,
    this.badge,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final AppTokens tokens;
  final String? badge;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final t = tokens;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(Radii.card),
        child: Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: t.surface,
            borderRadius: BorderRadius.circular(Radii.card),
            border: Border.all(color: t.line),
          ),
          child: Row(
            children: [
              Icon(icon, color: t.textMuted),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: TextStyle(fontWeight: FontWeight.w600, color: t.text)),
                    Text(subtitle, style: TextStyle(fontSize: 12, color: t.textMuted)),
                  ],
                ),
              ),
              if (badge != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: t.pdfBadge.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    badge!,
                    style: AppTokens.mono(size: 11, weight: FontWeight.w700, color: t.pdfBadge),
                  ),
                ),
              Icon(Icons.chevron_right_rounded, color: t.textFaint),
            ],
          ),
        ),
      ),
    );
  }
}
