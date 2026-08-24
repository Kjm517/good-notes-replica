import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

import '../../app/design.dart';
import 'billing_helpers.dart';
import 'billing_ladder.dart';
import 'billing_plan.dart';
import 'payment_sheet.dart';
import 'revenuecat_billing.dart';

class PremiumPlanSheet extends ConsumerWidget {
  const PremiumPlanSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      useSafeArea: true,
      builder: (_) => const PremiumPlanSheet(),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    final useStore = ref.watch(revenueCatConfiguredProvider);
    final offeringsAsync = ref.watch(offeringsProvider);

    return Padding(
      padding: EdgeInsets.only(bottom: bottom),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Choose a plan',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(fontSize: 20),
              ),
              const SizedBox(height: 4),
              Text(
                '7-day free trial · cancel anytime',
                style: AppTokens.mono(size: 11, color: t.textFaint),
              ),
              const SizedBox(height: 20),
              _PricingLadder(t: t),
              const SizedBox(height: 16),
              if (useStore && offeringsAsync.isLoading)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Center(child: CircularProgressIndicator()),
                )
              else ...[
                _PlanOption(
                  plan: BillingPlan.yearly,
                  title: 'Yearly',
                  price: _priceFor(
                    useStore: useStore,
                    offerings: offeringsAsync.valueOrNull,
                    plan: BillingPlan.yearly,
                  ),
                  badge: 'Best value',
                  subtitle:
                      '~${formatPhp(kYearlyEffectiveMonthlyPhp)}/mo · ${yearlySavingsLabel()}',
                  package: packageForPlan(
                    offeringsAsync.valueOrNull,
                    BillingPlan.yearly,
                  ),
                ),
                const SizedBox(height: 10),
                _PlanOption(
                  plan: BillingPlan.monthly,
                  title: 'Monthly',
                  price: _priceFor(
                    useStore: useStore,
                    offerings: offeringsAsync.valueOrNull,
                    plan: BillingPlan.monthly,
                  ),
                  subtitle:
                      'Students ${formatPhp(kStudentMonthlyPhp)}/mo · launch ${formatPhp(kLaunchMonthlyPhp)}',
                  package: packageForPlan(
                    offeringsAsync.valueOrNull,
                    BillingPlan.monthly,
                  ),
                ),
              ],
              if (useStore)
                TextButton(
                  onPressed: () => _restorePurchases(context, ref),
                  child: const Text('Restore purchases'),
                ),
              const SizedBox(height: 16),
              Text(
                premiumTierSummary(),
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: t.textMuted),
              ),
              const SizedBox(height: 6),
              Text(
                'Free tier: ${freeTierSummary()}.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 11, color: t.textFaint, height: 1.35),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _priceFor({
    required bool useStore,
    required Offerings? offerings,
    required BillingPlan plan,
  }) {
    if (kIsWeb || !useStore) {
      return plan == BillingPlan.yearly ? yearlyPriceLabel() : monthlyPriceLabel();
    }
    return priceLabelForPackage(packageForPlan(offerings, plan), plan);
  }

  Future<void> _restorePurchases(BuildContext context, WidgetRef ref) async {
    try {
      final info = await restorePurchases();
      ref.read(customerInfoProvider.notifier).apply(info);
      if (!context.mounted) return;
      final active = isPremiumFromCustomerInfo(info);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            active
                ? 'Premium restored.'
                : 'No active subscription found for this account.',
          ),
        ),
      );
      if (active) Navigator.of(context).pop();
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Restore failed: $e')),
      );
    }
  }
}

class _PricingLadder extends StatelessWidget {
  const _PricingLadder({required this.t});

  final AppTokens t;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: t.fill,
        borderRadius: BorderRadius.circular(Radii.inner),
        border: Border.all(color: t.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _LadderRow(
            label: 'Free',
            value: freeTierSummary(),
            muted: true,
          ),
          Divider(height: 16, color: t.line),
          _LadderRow(label: 'Monthly', value: monthlyPriceLabel()),
          _LadderRow(
            label: 'Student',
            value: '${formatPhp(kStudentMonthlyPhp)}/mo',
            hint: '.edu email or $kStudentVoucherCode',
          ),
          _LadderRow(
            label: 'Yearly',
            value: yearlyPriceLabel(),
            hint: '~${formatPhp(kYearlyEffectiveMonthlyPhp)}/mo · ${yearlySavingsLabel()}',
            accent: true,
          ),
          _LadderRow(
            label: 'Launch',
            value: '${formatPhp(kLaunchMonthlyPhp)}/mo',
            hint: '$kLaunchVoucherCode · first month · GCash/Maya',
          ),
        ],
      ),
    );
  }
}

class _LadderRow extends StatelessWidget {
  const _LadderRow({
    required this.label,
    required this.value,
    this.hint,
    this.muted = false,
    this.accent = false,
  });

  final String label;
  final String value;
  final String? hint;
  final bool muted;
  final bool accent;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final valueColor = accent ? t.premiumText : (muted ? t.textMuted : t.text);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 64,
            child: Text(
              label,
              style: AppTokens.mono(
                size: 10,
                weight: FontWeight.w600,
                color: t.textFaint,
              ),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: valueColor,
                  ),
                ),
                if (hint != null)
                  Text(
                    hint!,
                    style: TextStyle(fontSize: 10, color: t.textFaint, height: 1.3),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PlanOption extends StatelessWidget {
  const _PlanOption({
    required this.plan,
    required this.title,
    required this.price,
    required this.subtitle,
    this.badge,
    this.package,
  });

  final BillingPlan plan;
  final String title;
  final String price;
  final String subtitle;
  final String? badge;
  final Package? package;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Material(
      color: t.surface,
      borderRadius: BorderRadius.circular(Radii.card),
      child: InkWell(
        onTap: () => _select(context),
        borderRadius: BorderRadius.circular(Radii.card),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(Radii.card),
            border: Border.all(color: t.line),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          title,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        if (badge != null) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 7,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: t.premiumSoft,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              badge!,
                              style: AppTokens.mono(
                                size: 9,
                                weight: FontWeight.w600,
                                color: t.premiumText,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(subtitle, style: TextStyle(fontSize: 12, color: t.textMuted)),
                  ],
                ),
              ),
              Text(
                price,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: t.premiumText,
                ),
              ),
              const SizedBox(width: 8),
              Icon(Icons.chevron_right_rounded, color: t.textFaint),
            ],
          ),
        ),
      ),
    );
  }

  void _select(BuildContext context) {
    final navigator = Navigator.of(context);
    navigator.pop();
    navigator.push(
      MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (_) => PaymentSheet(plan: plan, package: package),
      ),
    );
  }
}
