import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/design.dart';
import 'payment_sheet.dart';
import 'premium_providers.dart';

class PremiumPlanSheet extends ConsumerStatefulWidget {
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
  ConsumerState<PremiumPlanSheet> createState() => _PremiumPlanSheetState();
}

class _PremiumPlanSheetState extends ConsumerState<PremiumPlanSheet> {
  BillingPlan _selected = BillingPlan.yearly;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 0, 20, 20 + bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Spacer(),
              TextButton(
                onPressed: () async {
                  await ref.read(billingPlanProvider.notifier).restore();
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('No purchases to restore yet.')),
                  );
                },
                child: Text('Restore', style: TextStyle(color: t.textMuted)),
              ),
            ],
          ),
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              gradient: const LinearGradient(
                colors: [Color(0xFFF4D58A), Color(0xFFD9A94E)],
              ),
            ),
            child: Icon(Icons.workspace_premium_rounded, color: t.premiumOn, size: 29),
          ),
          const SizedBox(height: 14),
          Text(
            'Notably Premium',
            style: TextStyle(
              fontSize: 23,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.02,
              color: t.text,
            ),
          ),
          const SizedBox(height: 7),
          Text(
            'Unlimited AI quizzes from your books, full history and retakes.',
            style: TextStyle(fontSize: 13, height: 1.55, color: t.textMuted),
          ),
          const SizedBox(height: 18),
          _PlanOption(
            title: 'Yearly',
            subtitle: '\$39.99 billed once a year',
            price: '\$3.33',
            unit: '/month',
            badge: 'SAVE 33%',
            selected: _selected == BillingPlan.yearly,
            onTap: () => setState(() => _selected = BillingPlan.yearly),
          ),
          const SizedBox(height: 10),
          _PlanOption(
            title: 'Monthly',
            subtitle: 'Billed every month',
            price: '\$4.99',
            unit: '/month',
            selected: _selected == BillingPlan.monthly,
            onTap: () => setState(() => _selected = BillingPlan.monthly),
          ),
          const SizedBox(height: 16),
          for (final line in const [
            'Unlimited AI quizzes — 20 to 100 items',
            'Full quiz history and retakes',
            'Answer explanations with source pages',
            'Priority support',
          ])
            Padding(
              padding: const EdgeInsets.only(bottom: 11),
              child: Row(
                children: [
                  Icon(Icons.check_circle_rounded, size: 18, color: t.premiumText),
                  const SizedBox(width: 11),
                  Expanded(
                    child: Text(line, style: TextStyle(fontSize: 12.5, color: t.textSecondary)),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 8),
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              PaymentSheet.show(context, plan: _selected);
            },
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(52),
              backgroundColor: t.premium,
              foregroundColor: t.premiumOn,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
            ),
            child: Text(
              _selected == BillingPlan.yearly
                  ? 'Continue — \$39.99/yr'
                  : 'Continue — \$4.99/mo',
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15.5),
            ),
          ),
          const SizedBox(height: 11),
          Text(
            '7-day free trial · cancel anytime',
            textAlign: TextAlign.center,
            style: AppTokens.mono(size: 11, color: t.textFaint),
          ),
        ],
      ),
    );
  }
}

class _PlanOption extends StatelessWidget {
  const _PlanOption({
    required this.title,
    required this.subtitle,
    required this.price,
    required this.unit,
    required this.selected,
    required this.onTap,
    this.badge,
  });

  final String title;
  final String subtitle;
  final String price;
  final String unit;
  final bool selected;
  final VoidCallback onTap;
  final String? badge;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(Radii.card),
          border: Border.all(
            color: selected ? t.premium : t.lineStrong,
            width: selected ? 1.5 : 1,
          ),
          gradient: selected
              ? LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    t.premium.withValues(alpha: 0.16),
                    t.premium.withValues(alpha: 0.04),
                  ],
                )
              : null,
          color: selected ? null : t.surface,
        ),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            if (badge != null)
              Positioned(
                top: -22,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFF4D58A), Color(0xFFD9A94E)],
                    ),
                    borderRadius: BorderRadius.circular(100),
                  ),
                  child: Text(
                    badge!,
                    style: TextStyle(
                      fontSize: 9.5,
                      fontWeight: FontWeight.w700,
                      color: t.premiumOn,
                    ),
                  ),
                ),
              ),
            Row(
              children: [
                Container(
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: selected ? t.premium : t.lineStrong,
                      width: 2,
                    ),
                  ),
                  child: selected
                      ? Center(
                          child: Container(
                            width: 10,
                            height: 10,
                            decoration: BoxDecoration(
                              color: t.premium,
                              shape: BoxShape.circle,
                            ),
                          ),
                        )
                      : null,
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w700,
                          color: selected ? t.premiumText : t.text,
                        ),
                      ),
                      Text(subtitle, style: TextStyle(fontSize: 11, color: t.textFaint)),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(price, style: AppTokens.mono(size: 17, color: selected ? t.premiumText : t.text)),
                    Text(unit, style: TextStyle(fontSize: 10, color: t.textFaint)),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
