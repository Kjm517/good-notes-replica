import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../app/design.dart';
import '../../app/firebase_bootstrap.dart';
import '../../app/page_routes.dart';
import '../../app/pricing.dart';
import '../../app/providers.dart';
import '../../core/ai/ai_providers.dart';
import '../../core/sync/sync_providers.dart';
import '../../core/sync/sync_state.dart';
import '../auth/providers.dart';
import 'bug_report_sheet.dart';
import 'premium_plan_sheet.dart';
import 'premium_providers.dart';
import 'settings_widgets.dart';

export 'bug_report_sheet.dart' show kAppVersionLabel, kBugReportEmail;

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    final isPremium = ref.watch(isPremiumProvider);
    final plan = ref.watch(billingPlanProvider);
    final renews = ref.watch(premiumRenewsAtProvider);

    return Scaffold(
      backgroundColor: t.canvas,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 2, 18, 12),
              child: Row(
                children: [
                  IconButton(
                    tooltip: 'Back',
                    onPressed: () => context.canPop()
                        ? context.pop()
                        : context.go('/library'),
                    icon: Icon(notablyBackIcon, color: t.textSecondary),
                  ),
                  Text(
                    'Settings',
                    style: TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.02,
                      color: t.text,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 620),
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(18, 0, 18, 32),
                    children: [
                      SettingsSection(
                        label: 'Account',
                        child: _AccountCard(),
                      ),
                      SettingsSection(
                        label: 'Storage',
                        child: const SettingsGroupCard(
                          children: [StorageCapacityTile()],
                        ),
                      ),
                      if (isPremium)
                        SettingsSection(
                          label: 'Plan',
                          child: _ActivePlanCard(plan: plan, renewsAt: renews),
                        )
                      else
                        _GoPremiumBanner(
                          onUpgrade: () => PremiumPlanSheet.show(context),
                        ),
                      SettingsSection(
                        label: 'AI features',
                        child: _AiFeaturesCard(isPremium: isPremium),
                      ),
                      SettingsSection(
                        label: 'Appearance',
                        child: _AppearanceSection(),
                      ),
                      SettingsSection(
                        label: 'Support',
                        child: SettingsGroupCard(
                          children: [
                            SettingsRow(
                              icon: Icons.bug_report_outlined,
                              iconColor: Theme.of(context).colorScheme.error,
                              title: 'Report a bug',
                              subtitle: 'Send logs and screenshots',
                              trailing: Icon(
                                Icons.chevron_right_rounded,
                                color: t.textFaint,
                              ),
                              onTap: () => BugReportSheet.show(context),
                            ),
                            SettingsRow(
                              icon: Icons.info_outline_rounded,
                              title: 'About Notably',
                              subtitle: kAppVersionLabel,
                              trailing: Icon(
                                Icons.chevron_right_rounded,
                                color: t.textFaint,
                              ),
                              onTap: () => _showAbout(context),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      Center(
                        child: Text(
                          kAppVersionLabel,
                          style: AppTokens.mono(size: 11, color: t.textFaint),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showAbout(BuildContext context) {
    final t = context.tokens;
    showAboutDialog(
      context: context,
      applicationName: 'Notably',
      applicationVersion: kAppVersionLabel.replaceFirst('v', ''),
      applicationIcon: Icon(Icons.draw_rounded, size: 36, color: t.accentText),
      children: const [
        Text('A GoodNotes-style note-taking app with AI quizzes from your PDFs.'),
      ],
    );
  }
}

class _AccountCard extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    final user = ref.watch(authStateProvider).asData?.value;
    final isPremium = ref.watch(isPremiumProvider);

    if (user == null) {
      return SettingsGroupCard(
        children: [
          SettingsRow(
            icon: Icons.cloud_off_outlined,
            title: 'Not signed in',
            subtitle: firebaseReady
                ? 'Sign in to sync your notes across devices'
                : 'Notes are stored on this device',
            trailing: Icon(Icons.chevron_right_rounded, color: t.textFaint),
            onTap: () => context.push('/sign-in'),
          ),
        ],
      );
    }

    return SettingsGroupCard(
      children: [
        Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              CircleAvatar(
                radius: 21,
                backgroundColor:
                    isPremium ? const Color(0xFFF4D58A) : t.fill,
                foregroundColor:
                    isPremium ? const Color(0xFF3A2C07) : t.textMuted,
                backgroundImage: user.photoUrl == null
                    ? null
                    : NetworkImage(user.photoUrl!),
                child: user.photoUrl == null
                    ? Text(
                        user.label.characters.first.toUpperCase(),
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      )
                    : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            user.label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const SizedBox(width: 7),
                        TierBadge(premium: isPremium),
                      ],
                    ),
                    Text(
                      user.email ?? 'Signed in',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTokens.mono(size: 10.5, color: t.textFaint),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        SettingsRow(
          icon: Icons.logout_rounded,
          iconColor: Theme.of(context).colorScheme.error,
          title: 'Sign out',
          onTap: () => _signOut(context, ref),
        ),
      ],
    );
  }

  Future<void> _signOut(BuildContext context, WidgetRef ref) async {
    final auth = ref.read(authRepositoryProvider);
    if (auth == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final t = ctx.tokens;
        return AlertDialog(
          title: const Text('Sign out?'),
          content: Text(
            'Notes already on this device stay here. Sync pauses until you '
            'sign in again.',
            style: TextStyle(color: t.textSecondary),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: TextButton.styleFrom(
                foregroundColor: Theme.of(ctx).colorScheme.error,
              ),
              child: const Text('Sign out'),
            ),
          ],
        );
      },
    );
    if (confirmed != true) return;
    await auth.signOut();
  }
}

class _GoPremiumBanner extends StatelessWidget {
  const _GoPremiumBanner({required this.onUpgrade});

  final VoidCallback onUpgrade;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 4),
      child: PremiumGradientCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    gradient: const LinearGradient(
                      colors: [Color(0xFFF4D58A), Color(0xFFD9A94E)],
                    ),
                  ),
                  child: Icon(
                    Icons.workspace_premium_rounded,
                    color: t.premiumOn,
                    size: 21,
                  ),
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Go Premium',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: t.premiumText,
                        ),
                      ),
                      Text(
                        '${AppPricing.freeStorageLabel} · ${AppPricing.freeQuizLimitLabel}',
                        style: TextStyle(
                          fontSize: 11,
                          color: t.premiumText.withValues(alpha: 0.65),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: onUpgrade,
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(44),
                backgroundColor: t.premium,
                foregroundColor: t.premiumOn,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                AppPricing.upgradeFromMonthly,
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActivePlanCard extends StatelessWidget {
  const _ActivePlanCard({required this.plan, this.renewsAt});

  final BillingPlan plan;
  final DateTime? renewsAt;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final label = plan == BillingPlan.yearly
        ? 'Premium — Yearly'
        : 'Premium — Monthly';
    final price = plan == BillingPlan.yearly
        ? '${AppPricing.yearly}/yr'
        : '${AppPricing.monthly}/mo';
    final renew = renewsAt != null
        ? 'Renews ${DateFormat.yMMMd().format(renewsAt!)} · $price'
        : price;

    return PremiumGradientCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Icons.workspace_premium_rounded,
                  color: t.premiumText, size: 22),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: t.premiumText,
                      ),
                    ),
                    Text(
                      renew,
                      style: TextStyle(
                        fontSize: 11,
                        color: t.premiumText.withValues(alpha: 0.7),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => PremiumPlanSheet.show(context),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: t.premiumText,
                    side: BorderSide(color: t.premium.withValues(alpha: 0.4)),
                  ),
                  child: const Text('Manage plan'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Billing history is coming soon.'),
                      ),
                    );
                  },
                  child: const Text('Billing history'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _AiFeaturesCard extends ConsumerWidget {
  const _AiFeaturesCard({required this.isPremium});

  final bool isPremium;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    final stats = ref.watch(quizStatsProvider);
    final usage = ref.watch(monthlyQuizUsageProvider);
    final syncStatus = ref.watch(syncStatusProvider);
    final syncPaused = ref.watch(syncPausedProvider);
    final engine = ref.watch(syncEngineProvider);

    final onTrial = ref.watch(isPremiumTrialProvider);
    final unlimitedQuizzes = ref.watch(hasUnlimitedAiQuizzesProvider);
    final quizSubtitle = unlimitedQuizzes
        ? 'Unlimited · from any PDF or deck'
        : usage.when(
            data: (u) => onTrial
                ? '${u.used} of ${u.limit} AI quizzes used in your trial'
                : '${u.used} of ${u.limit} free AI quizzes used',
            loading: () => 'Checking usage…',
            error: (_, __) => onTrial
                ? AppPricing.freeQuizLimitLabel
                : '0 of ${AppPricing.freeQuizLimit} free AI quizzes used',
          );

    final historySubtitle = stats.when(
      data: (s) => s.count == 0
          ? 'No quizzes yet'
          : '${s.count} quizzes · ${s.avgPercent}% average',
      loading: () => 'Loading…',
      error: (_, __) => 'Quiz history',
    );

    final syncSubtitle = _syncLabel(syncStatus, syncPaused);

    return SettingsGroupCard(
      children: [
        SettingsRow(
          icon: Icons.auto_awesome_rounded,
          iconColor: isPremium ? t.premiumText : t.textMuted,
          title: 'AI quizzes',
          subtitle: quizSubtitle,
          dimmed: !isPremium,
          trailing: isPremium
              ? _AccentSwitch(value: true, onChanged: null)
              : UnlockChip(onTap: () => PremiumPlanSheet.show(context)),
        ),
        SettingsRow(
          icon: Icons.history_rounded,
          title: 'Quiz history',
          subtitle: isPremium ? historySubtitle : 'Keep every attempt and retake',
          dimmed: !isPremium,
          trailing: isPremium
              ? Icon(Icons.chevron_right_rounded, color: t.textFaint)
              : UnlockChip(onTap: () => PremiumPlanSheet.show(context)),
          onTap: isPremium
              ? () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Open a document and tap Quiz to view its history.',
                      ),
                    ),
                  );
                }
              : null,
        ),
        SettingsRow(
          icon: Icons.cloud_sync_rounded,
          title: 'Sync & backup',
          subtitle: syncSubtitle,
          trailing: engine == null
              ? null
              : _AccentSwitch(
                  value: !syncPaused,
                  onChanged: (v) =>
                      ref.read(syncPausedProvider.notifier).setPaused(!v),
                ),
        ),
      ],
    );
  }

  String _syncLabel(SyncStatus status, bool paused) {
    if (paused) return 'Sync paused';
    return switch (status.phase) {
      SyncPhase.idle when status.lastSyncedAt != null =>
        'Last synced ${_relative(status.lastSyncedAt!)}',
      SyncPhase.idle => 'Ready to sync',
      SyncPhase.syncing => 'Syncing…',
      SyncPhase.pending => '${status.pendingChanges} change(s) pending',
      SyncPhase.offline => 'Offline',
      SyncPhase.error => status.message ?? 'Sync error',
      _ => 'Included on every plan',
    };
  }

  String _relative(DateTime at) {
    final d = DateTime.now().difference(at);
    if (d.inMinutes < 1) return 'just now';
    if (d.inMinutes < 60) return '${d.inMinutes} min ago';
    if (d.inHours < 24) return '${d.inHours} hr ago';
    return DateFormat.MMMd().format(at);
  }
}

class _AppearanceSection extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(themeModeProvider);
    final controller = ref.read(themeModeProvider.notifier);
    return AppearancePicker(
      mode: mode,
      onChanged: controller.set,
    );
  }
}

class _AccentSwitch extends StatelessWidget {
  const _AccentSwitch({required this.value, this.onChanged});

  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Switch.adaptive(
      value: value,
      activeTrackColor: onChanged == null ? t.premium : t.accent,
      onChanged: onChanged,
    );
  }
}
