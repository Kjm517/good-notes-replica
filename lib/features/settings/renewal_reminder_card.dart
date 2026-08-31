import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/design.dart';
import 'billing_plan.dart';
import 'payment_sheet.dart';
import 'premium_providers.dart';

/// Nudge shown while a one-time Premium term is about to lapse.
///
/// Wallet and QR Ph payments cannot be auto-debited, so without this the term
/// just ends silently. Tapping through opens checkout with the same plan
/// already selected, which is the closest thing to one-tap renewal that
/// PayMongo's e-wallet rails allow.
class RenewalReminderCard extends ConsumerWidget {
  const RenewalReminderCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final daysLeft = ref.watch(premiumExpiringSoonProvider);
    if (daysLeft == null) return const SizedBox.shrink();

    final t = context.tokens;
    final plan = ref.watch(billingPlanProvider);
    final expired = daysLeft <= 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: t.premiumSoft,
        borderRadius: BorderRadius.circular(Radii.card),
        border: Border.all(color: t.premium.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.schedule_rounded, size: 20, color: t.premiumText),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      expired
                          ? 'Premium ends today'
                          : daysLeft == 1
                              ? 'Premium ends tomorrow'
                              : 'Premium ends in $daysLeft days',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: t.text,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Wallet payments do not renew on their own. Extend now '
                      'to keep unlimited quizzes and 15 GB storage.',
                      style: TextStyle(
                        fontSize: 12,
                        height: 1.4,
                        color: t.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: FilledButton(
                  onPressed: () => PaymentSheet.show(
                    context,
                    plan: plan == BillingPlan.yearly
                        ? BillingPlan.yearly
                        : BillingPlan.monthly,
                  ),
                  style: FilledButton.styleFrom(
                    backgroundColor: t.premium,
                    foregroundColor: t.premiumOn,
                    minimumSize: const Size.fromHeight(42),
                  ),
                  child: Text(
                    plan == BillingPlan.yearly
                        ? 'Extend · ${yearlyPriceLabel()}'
                        : 'Extend · ${monthlyPriceLabel()}',
                  ),
                ),
              ),
              const SizedBox(width: 8),
              TextButton(
                onPressed: () => setRenewalReminder(ref, false),
                style: TextButton.styleFrom(foregroundColor: t.textMuted),
                child: const Text('Not now'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
