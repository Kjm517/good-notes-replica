import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../app/design.dart';
import 'billing_plan.dart';
import 'premium_providers.dart';
import 'premium_plan_sheet.dart';
import 'settings_widgets.dart';

/// Where Apple and Google send people to cancel a subscription. Neither
/// platform allows cancelling from inside the app — this is the only route.
const _appleSubscriptions = 'https://apps.apple.com/account/subscriptions';
const _googleSubscriptions =
    'https://play.google.com/store/account/subscriptions';

/// Details of an active Premium plan: what was bought, how it was paid for,
/// when it ends, and whether it renews on its own.
class ManagePlanSheet extends ConsumerWidget {
  const ManagePlanSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      useSafeArea: true,
      builder: (_) => const ManagePlanSheet(),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    final plan = ref.watch(billingPlanProvider);
    final renewsAt = ref.watch(premiumRenewsAtProvider);
    final autoRenews = ref.watch(premiumAutoRenewsProvider);
    final paidWith = ref.watch(premiumPaidWithProvider);
    final cancelled = ref.watch(premiumCancelledProvider);
    final lifetime = plan == BillingPlan.lifetime;
    final error = Theme.of(context).colorScheme.error;

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Your Premium',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const SizedBox(height: 6),
              Text(
                _statusLine(
                  lifetime: lifetime,
                  autoRenews: autoRenews,
                  cancelled: cancelled,
                ),
                style: AppTokens.mono(size: 11, color: t.textFaint),
              ),
              const SizedBox(height: 18),
              SettingsGroupCard(
                children: [
                  _DetailRow(
                    label: 'Plan',
                    value: billingPlanLabel(plan),
                  ),
                  if (!lifetime)
                    _DetailRow(
                      label: 'Price',
                      value: plan == BillingPlan.yearly
                          ? yearlyPriceLabel()
                          : monthlyPriceLabel(),
                    ),
                  _DetailRow(
                    label: 'Paid with',
                    value: _methodLabel(paidWith, autoRenews),
                  ),
                  _DetailRow(
                    label: lifetime
                        ? 'Expires'
                        : (autoRenews && !cancelled)
                            ? 'Renews'
                            : 'Access until',
                    value: lifetime
                        ? 'Never'
                        : renewsAt == null
                            ? '—'
                            : DateFormat.yMMMd().format(renewsAt),
                    emphasis: true,
                  ),
                  if (!lifetime && renewsAt != null)
                    _DetailRow(
                      label: 'Time left',
                      value: _timeLeft(renewsAt),
                    ),
                ],
              ),
              if (!lifetime && !autoRenews && !cancelled) ...[
                const SizedBox(height: 10),
                SettingsGroupCard(
                  children: [
                    SwitchListTile.adaptive(
                      value: ref.watch(renewalReminderEnabledProvider),
                      onChanged: (v) => setRenewalReminder(ref, v),
                      title: const Text(
                        'Remind me before it ends',
                        style: TextStyle(fontSize: 13),
                      ),
                      subtitle: Text(
                        'Shows a reminder in Settings 3 days before expiry.',
                        style: AppTokens.mono(size: 10, color: t.textFaint),
                      ),
                      contentPadding:
                          const EdgeInsets.symmetric(horizontal: 14),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 14),
              _RenewalNotice(
                autoRenews: autoRenews,
                lifetime: lifetime,
                cancelled: cancelled,
                renewsAt: renewsAt,
              ),
              const SizedBox(height: 18),
              if (!lifetime) ...[
                if (cancelled)
                  // Nothing was taken away — offer the way back.
                  OutlinedButton(
                    onPressed: () => resumePremiumRenewal(ref),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(48),
                      foregroundColor: t.premiumText,
                      side: BorderSide(
                        color: t.premium.withValues(alpha: 0.4),
                      ),
                    ),
                    child: const Text('Keep Premium'),
                  )
                else ...[
                  FilledButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                      PremiumPlanSheet.show(context);
                    },
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(48),
                      backgroundColor: t.premium,
                      foregroundColor: t.premiumOn,
                    ),
                    child: Text(
                      autoRenews ? 'Change plan' : 'Extend Premium',
                    ),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton(
                    onPressed: () => _confirmCancel(
                      context,
                      ref,
                      autoRenews: autoRenews,
                      renewsAt: renewsAt,
                    ),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(48),
                      foregroundColor: error,
                      side: BorderSide(color: error.withValues(alpha: 0.4)),
                    ),
                    child: Text(
                      autoRenews ? 'Cancel subscription' : 'Cancel Premium',
                    ),
                  ),
                ],
                const SizedBox(height: 10),
              ],
              Text(
                _footnote(autoRenews: autoRenews, lifetime: lifetime),
                textAlign: TextAlign.center,
                style: AppTokens.mono(size: 10, color: t.textFaint),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _statusLine({
    required bool lifetime,
    required bool autoRenews,
    required bool cancelled,
  }) {
    if (lifetime) return 'Lifetime access · never expires';
    if (cancelled) return 'Cancelled · active until it ends';
    if (autoRenews) return 'Active · renews automatically';
    return 'Active · one-time term';
  }

  String _methodLabel(String? paidWith, bool autoRenews) {
    if (autoRenews) {
      if (kIsWeb) return 'App store';
      return Platform.isIOS ? 'App Store' : 'Google Play';
    }
    return switch (paidWith) {
      'card' => 'Card',
      'gcash' => 'GCash',
      'paymaya' => 'Maya',
      'qrph' => 'QR Ph',
      _ => 'Granted',
    };
  }

  String _timeLeft(DateTime renewsAt) {
    final left = renewsAt.difference(DateTime.now());
    if (left.isNegative) return 'Expired';
    if (left.inDays >= 1) {
      return '${left.inDays} ${left.inDays == 1 ? 'day' : 'days'}';
    }
    if (left.inHours >= 1) return '${left.inHours}h';
    return 'Less than an hour';
  }

  /// Confirms before cancelling, and is explicit that access is not lost now.
  Future<void> _confirmCancel(
    BuildContext context,
    WidgetRef ref, {
    required bool autoRenews,
    required DateTime? renewsAt,
  }) async {
    final until = renewsAt == null
        ? 'the end of your current term'
        : DateFormat.yMMMd().format(renewsAt);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Cancel Premium?'),
        content: Text(
          autoRenews
              ? 'You will keep Premium until $until, and will not be charged '
                  'again. Cancelling happens in your app store account — we '
                  'will take you there next.'
              : 'You will keep Premium until $until. Nothing is refunded and '
                  'nothing further is charged.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Keep Premium'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(dialogContext).colorScheme.error,
            ),
            child: const Text('Cancel Premium'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    await cancelPremiumRenewal(ref);

    // Apple and Google own the actual subscription; the local flag alone would
    // not stop their billing, so send the user where it can be stopped.
    if (autoRenews && context.mounted) {
      await _openStoreSubscriptions(context);
    }
  }

  String _footnote({required bool autoRenews, required bool lifetime}) {
    if (lifetime) return 'Nothing to renew — this account keeps Premium.';
    if (autoRenews) {
      return 'Billing is handled by the app store. Cancelling there keeps '
          'Premium until the current period ends.';
    }
    return 'This term will not renew by itself. Extend any time before it '
        'ends to keep Premium without a gap.';
  }

  Future<void> _openStoreSubscriptions(BuildContext context) async {
    final url = !kIsWeb && Platform.isIOS
        ? _appleSubscriptions
        : _googleSubscriptions;
    final ok = await launchUrl(
      Uri.parse(url),
      mode: LaunchMode.externalApplication,
    );
    if (!ok && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Open your store account to cancel: $url')),
      );
    }
  }
}

/// Explains what happens at the end of the term, which differs per platform.
class _RenewalNotice extends StatelessWidget {
  const _RenewalNotice({
    required this.autoRenews,
    required this.lifetime,
    required this.cancelled,
    required this.renewsAt,
  });

  final bool autoRenews;
  final bool lifetime;
  final bool cancelled;
  final DateTime? renewsAt;

  @override
  Widget build(BuildContext context) {
    if (lifetime) return const SizedBox.shrink();
    final t = context.tokens;
    final until =
        renewsAt == null ? null : DateFormat.yMMMd().format(renewsAt!);

    final (IconData icon, String message) = cancelled
        ? (
            Icons.check_circle_outline_rounded,
            until == null
                ? 'Cancelled. Premium stays active until the end of your '
                    'current term.'
                : 'Cancelled. Premium stays fully active until $until — '
                    'nothing changes before then.',
          )
        : autoRenews
            ? (
                Icons.autorenew_rounded,
                'Renews automatically. You will be charged again on the date '
                    'above unless you cancel.',
              )
            : (
                Icons.event_busy_outlined,
                'Premium ends on the date above. Wallet payments (GCash, '
                    'Maya, QR Ph) are one-time — nothing is charged again.',
              );

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: t.fill,
        borderRadius: BorderRadius.circular(Radii.control),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: t.textMuted),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: TextStyle(fontSize: 12, height: 1.4, color: t.textMuted),
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.label,
    required this.value,
    this.emphasis = false,
  });

  final String label;
  final String value;
  final bool emphasis;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(fontSize: 13, color: t.textSecondary),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: emphasis ? FontWeight.w700 : FontWeight.w600,
              color: emphasis ? t.text : t.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
