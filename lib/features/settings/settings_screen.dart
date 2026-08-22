import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../app/design.dart';
import '../../app/firebase_bootstrap.dart';
import '../../app/providers.dart';
import '../../core/ai/ai_providers.dart';
import '../../core/sync/sync_providers.dart';
import '../../core/sync/sync_state.dart';
import '../auth/providers.dart';
import 'bug_report_sheet.dart';
import 'premium_plan_sheet.dart';
import 'premium_providers.dart';
import 'settings_widgets.dart';

export 'bug_report_sheet.dart' show kBugReportEmail;

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
      appBar: AppBar(
        backgroundColor: t.canvas,
        title: const Text('Settings'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 4, 18, 40),
        children: [
          SettingsSection(
            label: 'Account',
            child: _AccountCard(),
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
                  trailing: Icon(Icons.chevron_right_rounded, color: t.textFaint),
                  onTap: () => BugReportSheet.show(context),
                ),
                SettingsRow(
                  icon: Icons.info_outline_rounded,
                  title: 'About Notably',
                  subtitle: 'v1.0.0 (1)',
                  trailing: Icon(Icons.chevron_right_rounded, color: t.textFaint),
                  onTap: () => _showAbout(context),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showAbout(BuildContext context) {
    final t = context.tokens;
    showAboutDialog(
      context: context,
      applicationName: 'Notably',
      applicationVersion: '1.0.0 (1)',
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
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () {},
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 21,
                    backgroundColor: isPremium
                        ? const Color(0xFFF4D58A)
                        : t.fill,
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
                  Icon(Icons.chevron_right_rounded, color: t.textFaint),
                ],
              ),
            ),
          ),
        ),
      ],
    );
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
                  child: Icon(Icons.workspace_premium_rounded, color: t.premiumOn, size: 21),
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
                        'Unlimited AI quizzes from your books',
                        style: TextStyle(fontSize: 11, color: t.premiumText.withValues(alpha: 0.65)),
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
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text(
                'Upgrade — from \$4.99/mo',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
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
    final label = plan == BillingPlan.yearly ? 'Premium — Yearly' : 'Premium — Monthly';
    final price = plan == BillingPlan.yearly ? '\$39.99/yr' : '\$4.99/mo';
    final renew = renewsAt != null
        ? 'Renews ${DateFormat.yMMMd().format(renewsAt!)} · $price'
        : price;

    return PremiumGradientCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Icons.workspace_premium_rounded, color: t.premiumText, size: 22),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: t.premiumText)),
                    Text(renew, style: TextStyle(fontSize: 11, color: t.premiumText.withValues(alpha: 0.7))),
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
                  onPressed: () {},
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
    final usage = ref.watch(monthlyQuizUsageProvider);
    final stats = ref.watch(quizStatsProvider);
    final syncStatus = ref.watch(syncStatusProvider);
    final syncPaused = ref.watch(syncPausedProvider);
    final engine = ref.watch(syncEngineProvider);

    final quizSubtitle = isPremium
        ? 'Unlimited · from any PDF or deck'
        : usage.when(
            data: (u) => '${u.used} of ${u.limit} free quizzes used this month',
            loading: () => 'Checking usage…',
            error: (_, __) => '3 of 3 free quizzes used this month',
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
                      content: Text('Open a document and tap Quiz to view its history.'),
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
