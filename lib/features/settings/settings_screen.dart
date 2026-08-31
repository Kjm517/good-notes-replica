import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../app/app_version.dart';
import '../../app/design.dart';
import '../../app/supabase_bootstrap.dart';
import '../../app/providers.dart';
import '../../core/sync/sync_providers.dart';
import '../../core/sync/sync_state.dart';
import '../auth/providers.dart';
import '../legal/legal_copy.dart';
import '../legal/legal_sheet.dart';
import 'entitlements.dart';
import 'about_notably_sheet.dart';
import 'bug_report_sheet.dart';
import 'paymongo_billing.dart';
import 'manage_plan_sheet.dart';
import 'renewal_reminder_card.dart';
import 'premium_plan_sheet.dart';
import 'premium_providers.dart';
import 'settings_widgets.dart';
import '../pwa/pwa_install.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  @override
  void initState() {
    super.initState();
    // Re-check worker entitlement whenever Settings opens so an admin revoke
    // shows up without requiring a full app restart.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(ref.read(payMongoEntitlementRefreshProvider)());
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final entitlement = ref.watch(entitlementProvider);
    final ent = entitlement.asData?.value;
    final hasPremiumFeatures = ent?.hasPremiumFeatures ?? false;
    final plan = ref.watch(billingPlanProvider);
    final renews = ref.watch(premiumRenewsAtProvider);
    final width = MediaQuery.sizeOf(context).width;
    final horizontalPad = width >= AppBreakpoints.phone ? 24.0 : 18.0;

    return Scaffold(
      backgroundColor: t.canvas,
      appBar: AppBar(
        backgroundColor: t.canvas,
        title: const Text('Settings'),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 620),
            child: ListView(
              padding: EdgeInsets.fromLTRB(horizontalPad, 8, horizontalPad, 40),
              children: [
                SettingsSection(
                  label: 'Account',
                  child: SettingsGroupCard(
                    children: [_AccountHeader(entitlement: ent)],
                  ),
                ),
                SettingsSection(
                  label: 'Plan',
                  child: ent?.isPremium == true
                      ? Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const RenewalReminderCard(),
                            _ActivePlanCard(plan: plan, renewsAt: renews),
                          ],
                        )
                      : ent?.isTrialActive == true
                          ? _TrialPlanCard(entitlement: ent!)
                          : _GoPremiumCard(trialExpired: ent?.trialExpired ?? false),
                ),
                SettingsSection(
                  label: 'AI Features',
                  child: _AiFeaturesCard(
                    entitlement: ent,
                    hasPremiumFeatures: hasPremiumFeatures,
                  ),
                ),
                SettingsSection(
                  label: 'Appearance',
                  child: _AppearanceSection(),
                ),
                SettingsSection(
                  label: 'Support',
                  child: _SupportSection(),
                ),
                if (kIsWeb)
                  SettingsSection(
                    label: 'App',
                    child: SettingsGroupCard(
                      children: [
                        SettingsRow(
                          icon: Icons.install_desktop_outlined,
                          title: pwaIsStandalone()
                              ? 'Installed'
                              : 'Install Notably',
                          subtitle: pwaIsStandalone()
                              ? 'Running as an installed app'
                              : pwaInstallAvailable()
                                  ? 'Add to your home screen or apps list'
                                  : 'Chrome menu → Cast, save, and share → Install Notably',
                          onTap: pwaIsStandalone()
                              ? null
                              : () async {
                                  final ok = await promptPwaInstall();
                                  if (!context.mounted || ok) return;
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        'Use the Chrome install icon in the address bar, or the browser menu.',
                                      ),
                                    ),
                                  );
                                },
                        ),
                      ],
                    ),
                  ),
                if (kIsWeb)
                  SettingsSection(
                    label: 'Admin',
                    child: SettingsGroupCard(
                      children: [
                        SettingsRow(
                          icon: Icons.admin_panel_settings_outlined,
                          title: 'Admin console',
                          subtitle: 'Staff sign-in (separate from this account)',
                          onTap: () => context.push('/admin/overview'),
                        ),
                      ],
                    ),
                  ),
                SettingsSection(
                  label: 'About',
                  child: _AboutSection(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AccountHeader extends ConsumerWidget {
  const _AccountHeader({this.entitlement});

  final UserEntitlement? entitlement;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    final user = ref.watch(authStateProvider).asData?.value;
    final plan = ref.watch(billingPlanProvider);
    final tier = entitlement?.isPremium == true && plan == BillingPlan.lifetime
        ? 'Lifetime'
        : (entitlement?.tierLabel ?? 'Free');
    final premiumBadge = entitlement?.isPremium == true || entitlement?.isTrialActive == true;

    if (user == null) {
      return ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        leading: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: t.fill,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(Icons.cloud_off_rounded, size: 22, color: t.textMuted),
        ),
        title: const Text(
          'Not signed in',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          supabaseReady
              ? 'Sign in to sync your notes and start your 7-day trial'
              : 'Sync is not set up — notes stay on this device',
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(fontSize: 12.5, color: t.textMuted),
        ),
        trailing: TierBadge(label: tier, premium: premiumBadge),
        onTap: () => context.push('/sign-in'),
      );
    }

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      leading: CircleAvatar(
        radius: 22,
        backgroundColor: t.accentSoft,
        foregroundColor: t.accentText,
        backgroundImage:
            user.photoUrl == null ? null : NetworkImage(user.photoUrl!),
        child: user.photoUrl == null
            ? Text(
                user.label.characters.first.toUpperCase(),
                style: const TextStyle(fontWeight: FontWeight.w700),
              )
            : null,
      ),
      title: Text(
        user.label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
      ),
      subtitle: Text(
        user.email ?? 'Signed in',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: AppTokens.mono(size: 11, color: t.textMuted),
      ),
      trailing: TierBadge(label: tier, premium: premiumBadge),
    );
  }
}

class _TrialPlanCard extends StatelessWidget {
  const _TrialPlanCard({required this.entitlement});

  final UserEntitlement entitlement;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final days = entitlement.trialDaysRemaining ?? 0;
    return PremiumGradientCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Icons.hourglass_top_rounded, color: t.premiumText, size: 26),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Free trial',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: t.text,
                      ),
                    ),
                    Text(
                      '$days day${days == 1 ? '' : 's'} left · ${entitlement.quizUsed} of ${entitlement.quizLimit} quizzes used',
                      style: AppTokens.mono(size: 10, color: t.textFaint),
                    ),
                  ],
                ),
              ),
              const TierBadge(label: 'Trial', premium: true),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            '5 GB storage · quiz history and AI quizzes unlocked during your trial. '
            'Upgrade to Premium for 15 GB and unlimited quizzes.',
            style: TextStyle(fontSize: 13, color: t.textSecondary, height: 1.4),
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: () => PremiumPlanSheet.show(context),
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(48),
              backgroundColor: t.premium,
              foregroundColor: t.premiumOn,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(Radii.control),
              ),
            ),
            child: const Text('Upgrade to Premium'),
          ),
        ],
      ),
    );
  }
}

class _GoPremiumCard extends StatelessWidget {
  const _GoPremiumCard({required this.trialExpired});

  final bool trialExpired;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return PremiumGradientCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Icons.workspace_premium_rounded, color: t.premiumText, size: 26),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      trialExpired ? 'Trial ended' : 'Go Premium',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: t.text,
                      ),
                    ),
                    Text(
                      trialExpired
                          ? 'Premium features are locked'
                          : 'Unlimited AI quizzes & history',
                      style: AppTokens.mono(size: 10, color: t.textFaint),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            trialExpired
                ? (kIsWeb
                    ? 'Your trial has ended. On the web, Premium is card, GCash, or Maya from ${monthlyPriceLabel()}.'
                    : 'Your 7-day trial has ended. Premium from ${monthlyPriceLabel()} '
                        'keeps unlimited AI quizzes, history, and 15 GB storage.')
                : (kIsWeb
                    ? 'Premium on the web is billed with card, GCash, or Maya from ${monthlyPriceLabel()} — not Google Play.'
                    : 'Start a 7-day trial with $kTrialQuizLimit AI quizzes, or go Premium from '
                        '${monthlyPriceLabel()} — ${yearlyPriceLabel()} ${yearlySavingsLabel().toLowerCase()}.'),
            style: TextStyle(fontSize: 13, color: t.textSecondary, height: 1.4),
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: () => PremiumPlanSheet.show(context),
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(48),
              backgroundColor: t.premium,
              foregroundColor: t.premiumOn,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(Radii.control),
              ),
            ),
            child: const Text('See plans'),
          ),
        ],
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
    final planName = billingPlanLabel(plan);
    final lifetime = plan == BillingPlan.lifetime;
    final renewLabel = lifetime
        ? 'Never expires'
        : renewsAt == null
            ? 'Active subscription'
            : 'Renews ${DateFormat.yMMMd().format(renewsAt!)}';

    return PremiumGradientCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Icons.verified_rounded, color: t.premiumText, size: 24),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Premium · $planName',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(renewLabel, style: AppTokens.mono(size: 10, color: t.textFaint)),
                    Text(
                      '15 GB storage · unlimited AI quizzes',
                      style: AppTokens.mono(size: 10, color: t.textFaint),
                    ),
                  ],
                ),
              ),
              const TierBadge(label: 'Active', premium: true),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => ManagePlanSheet.show(context),
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
                  onPressed: () => context.push('/billing-history'),
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
  const _AiFeaturesCard({
    required this.hasPremiumFeatures,
    this.entitlement,
  });

  final UserEntitlement? entitlement;
  final bool hasPremiumFeatures;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    final stats = ref.watch(quizStatsProvider);
    final syncStatus = ref.watch(syncStatusProvider);
    final syncPaused = ref.watch(syncPausedProvider);

    final ent = entitlement;
    final quizSubtitle = ent == null
        ? 'Checking usage…'
        : ent.quizUsageLabel();

    final historySubtitle = stats.when(
      data: (s) => s.count == 0
          ? 'No quizzes yet'
          : '${s.count} quizzes · ${s.avgPercent}% average',
      loading: () => 'Loading…',
      error: (_, _) => 'Quiz history',
    );

    final syncSubtitle = _syncLabel(syncStatus, syncPaused);

    return SettingsGroupCard(
      children: [
        SettingsRow(
          icon: Icons.auto_awesome_rounded,
          iconColor: hasPremiumFeatures ? t.premiumText : t.textMuted,
          title: 'AI quizzes',
          subtitle: quizSubtitle,
          dimmed: !hasPremiumFeatures && ent?.isFree == true,
          trailing: ent?.isPremium == true
              ? const AccentSwitch(value: true, onChanged: null)
              : hasPremiumFeatures
                  ? null
                  : UnlockChip(onTap: () => PremiumPlanSheet.show(context)),
        ),
        SettingsRow(
          icon: Icons.history_rounded,
          title: 'Quiz history',
          subtitle: hasPremiumFeatures
              ? historySubtitle
              : ent?.trialExpired == true
                  ? 'Locked — upgrade to Premium'
                  : 'Keep every attempt and retake',
          dimmed: !hasPremiumFeatures,
          trailing: hasPremiumFeatures
              ? Icon(Icons.chevron_right_rounded, color: t.textFaint)
              : UnlockChip(onTap: () => PremiumPlanSheet.show(context)),
          onTap: hasPremiumFeatures ? () => context.push('/quiz-history') : null,
        ),
        SettingsRow(
          icon: Icons.cloud_sync_rounded,
          title: 'Cloud sync',
          subtitle: syncSubtitle,
          trailing: AccentSwitch(
            value: !syncPaused,
            onChanged: (enabled) {
              ref.read(syncPausedProvider.notifier).setPaused(!enabled);
            },
          ),
        ),
      ],
    );
  }

  static String _syncLabel(SyncStatus status, bool paused) {
    if (paused) return 'Paused — notes stay on this device';
    return switch (status.phase) {
      SyncPhase.disabled => 'Sign in to sync across devices',
      SyncPhase.idle => status.message ?? 'Up to date',
      SyncPhase.syncing => status.progressMessage ?? 'Syncing…',
      SyncPhase.pending =>
        status.pendingChanges > 0
            ? '${status.pendingChanges} changes pending'
            : 'Pending sync',
      SyncPhase.offline => 'Offline — will sync when online',
      SyncPhase.paused => 'Sync paused',
      SyncPhase.error => status.message ?? 'Sync error',
    };
  }
}

class _AppearanceSection extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(themeModeProvider);
    final controller = ref.read(themeModeProvider.notifier);
    return SettingsGroupCard(
      children: [
        Padding(
          padding: const EdgeInsets.all(14),
          child: AppearancePicker(
            mode: mode,
            onChanged: controller.set,
          ),
        ),
      ],
    );
  }
}

class _AboutSection extends StatelessWidget {
  const _AboutSection();

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return SettingsGroupCard(
      children: [
        SettingsRow(
          icon: Icons.info_outline_rounded,
          title: 'About Notably',
          subtitle: 'Version $kAppVersion',
          trailing: Icon(Icons.chevron_right_rounded, color: t.textFaint),
          onTap: () => AboutNotablySheet.show(context),
        ),
        SettingsRow(
          icon: Icons.description_outlined,
          title: 'Terms of Use',
          trailing: Icon(Icons.chevron_right_rounded, color: t.textFaint),
          onTap: () => LegalSheet.show(context, initial: LegalDoc.terms),
        ),
        SettingsRow(
          icon: Icons.privacy_tip_outlined,
          title: 'Privacy Policy',
          trailing: Icon(Icons.chevron_right_rounded, color: t.textFaint),
          onTap: () => LegalSheet.show(context, initial: LegalDoc.privacy),
        ),
      ],
    );
  }
}

class _SupportSection extends ConsumerWidget {
  const _SupportSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SettingsGroupCard(
      children: [
        SettingsRow(
          icon: Icons.bug_report_outlined,
          title: 'Report a bug',
          subtitle: 'Goes to the admin Bug reports console',
          trailing: Icon(Icons.chevron_right_rounded, color: context.tokens.textFaint),
          onTap: () => BugReportSheet.show(context),
        ),
        SettingsRow(
          icon: Icons.logout_rounded,
          title: 'Sign out',
          subtitle: 'Stop syncing on this device',
          onTap: () async {
            final repo = ref.read(authRepositoryProvider);
            await repo?.signOut();
          },
        ),
      ],
    );
  }
}
