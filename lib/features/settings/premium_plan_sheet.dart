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
    final maxHeight = MediaQuery.sizeOf(context).height * 0.92;
    final useStore = ref.watch(revenueCatConfiguredProvider);
    final offeringsAsync = ref.watch(offeringsProvider);

    return Padding(
      padding: EdgeInsets.only(bottom: bottom),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxHeight),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Choose a plan',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 6),
                Text(
                  kIsWeb
                      ? 'Card, GCash, or Maya · not Google Play'
                      : '7-day free trial · cancel anytime',
                  style: AppTokens.mono(size: 11, color: t.textFaint),
                ),
                const SizedBox(height: 20),
                const _FeatureCompare(),
                const SizedBox(height: 18),
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
                    featured: true,
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
                    subtitle: 'Billed monthly · cancel anytime',
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
                const SizedBox(height: 12),
                Text(
                  'Free accounts keep 5 GB of notes. AI quizzes unlock with Premium or during a trial.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12, color: t.textFaint, height: 1.4),
                ),
              ],
            ),
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

class _FeatureCompare extends StatelessWidget {
  const _FeatureCompare();

  static const _rows = [
    ('Storage', '5 GB', '15 GB'),
    ('AI quizzes', 'Trial only', 'Unlimited'),
    ('Quiz history', 'Trial only', 'Included'),
    ('Cloud sync', 'Included', 'Included'),
  ];

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
      decoration: BoxDecoration(
        color: t.fill,
        borderRadius: BorderRadius.circular(Radii.card),
        border: Border.all(color: t.line),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                const Expanded(flex: 5, child: SizedBox.shrink()),
                Expanded(
                  flex: 4,
                  child: Text(
                    'Free',
                    textAlign: TextAlign.center,
                    style: AppTokens.mono(
                      size: 10,
                      weight: FontWeight.w600,
                      color: t.textFaint,
                    ),
                  ),
                ),
                Expanded(
                  flex: 4,
                  child: Text(
                    'Premium',
                    textAlign: TextAlign.center,
                    style: AppTokens.mono(
                      size: 10,
                      weight: FontWeight.w600,
                      color: t.premiumText,
                    ),
                  ),
                ),
              ],
            ),
          ),
          for (var i = 0; i < _rows.length; i++) ...[
            if (i > 0) Divider(height: 1, color: t.line),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 9),
              child: Row(
                children: [
                  Expanded(
                    flex: 5,
                    child: Text(
                      _rows[i].$1,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: t.text,
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 4,
                    child: Text(
                      _rows[i].$2,
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 12, color: t.textMuted),
                    ),
                  ),
                  Expanded(
                    flex: 4,
                    child: Text(
                      _rows[i].$3,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: t.premiumText,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
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
    this.featured = false,
    this.package,
  });

  final BillingPlan plan;
  final String title;
  final String price;
  final String subtitle;
  final String? badge;
  final bool featured;
  final Package? package;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Material(
      color: featured ? t.premiumSoft : t.surface,
      borderRadius: BorderRadius.circular(Radii.card),
      child: InkWell(
        onTap: () => _select(context),
        borderRadius: BorderRadius.circular(Radii.card),
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 16, 12, 16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(Radii.card),
            border: Border.all(
              color: featured ? t.premium.withValues(alpha: 0.45) : t.line,
              width: featured ? 1.4 : 1,
            ),
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
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: featured ? t.premium : t.premiumSoft,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              badge!,
                              style: AppTokens.mono(
                                size: 9,
                                weight: FontWeight.w600,
                                color: featured ? t.premiumOn : t.premiumText,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(fontSize: 12, color: t.textMuted),
                    ),
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
              const SizedBox(width: 4),
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
