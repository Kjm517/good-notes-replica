import 'package:flutter/material.dart';

import '../../app/design.dart';
import '../settings/billing_plan.dart';
import '../settings/premium_plan_sheet.dart';

/// Premium upsell when a free user tries to generate an AI quiz.
///
/// Matches the Annotate redesign “Turn this into a quiz” sheet; colours follow
/// [AppTokens] so light and dark themes both read correctly. Prices are always
/// shown in PHP (PayMongo / PH launch pricing).
class QuizUpgradeSheet extends StatelessWidget {
  const QuizUpgradeSheet({super.key, this.subtitle});

  /// Optional override under the headline (trial exhausted, etc.).
  final String? subtitle;

  static Future<void> show(BuildContext context, {String? subtitle}) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.55),
      // iPad: keep the sheet readable instead of edge-to-edge stretched.
      constraints: BoxConstraints(
        maxWidth: MediaQuery.sizeOf(context).shortestSide >= 600
            ? 480
            : double.infinity,
      ),
      builder: (_) => QuizUpgradeSheet(subtitle: subtitle),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final bottom = MediaQuery.paddingOf(context).bottom;
    final body = subtitle ??
        'Notably reads your PDF and writes a practice quiz from it — '
            'multiple choice, true/false and short answer, graded instantly.';

    final gold = t.premium;
    final goldDeep = Color.lerp(gold, const Color(0xFF8A6A1B), 0.25)!;
    final goldLight = Color.lerp(gold, Colors.white, 0.35)!;

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: Container(
        decoration: BoxDecoration(
          color: t.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: EdgeInsets.fromLTRB(22, 10, 22, 16 + bottom),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: t.lineStrong,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 22),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: gold,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(
                      Icons.quiz_outlined,
                      color: t.premiumOn,
                      size: 28,
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 10,
                  runSpacing: 8,
                  children: [
                    Text(
                      'Turn this into a quiz',
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            color: t.text,
                            fontWeight: FontWeight.w700,
                            fontSize: 22,
                            height: 1.2,
                          ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 9,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: gold,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.lock_rounded, size: 12, color: t.premiumOn),
                          const SizedBox(width: 4),
                          Text(
                            'PREMIUM',
                            style: AppTokens.mono(
                              size: 10,
                              weight: FontWeight.w700,
                              color: t.premiumOn,
                              letterSpacing: 0.6,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  body,
                  style: TextStyle(
                    color: t.textSecondary,
                    fontSize: 14,
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: 22),
                _FeatureRow(
                  icon: Icons.auto_awesome_rounded,
                  label: 'Questions written from your source pages',
                  iconColor: t.premiumText,
                  labelColor: t.text,
                ),
                const SizedBox(height: 14),
                _FeatureRow(
                  icon: Icons.tune_rounded,
                  label: 'Pick 20, 25, 50 or 100 items',
                  iconColor: t.premiumText,
                  labelColor: t.text,
                ),
                const SizedBox(height: 14),
                _FeatureRow(
                  icon: Icons.auto_awesome_motion_rounded,
                  label: 'Instant scoring and explanations',
                  iconColor: t.premiumText,
                  labelColor: t.text,
                ),
                const SizedBox(height: 26),
                DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    gradient: LinearGradient(
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                      colors: [goldDeep, gold, goldLight],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: gold.withValues(alpha: 0.35),
                        blurRadius: 24,
                        offset: const Offset(0, 10),
                        spreadRadius: -8,
                      ),
                    ],
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: () {
                        Navigator.of(context).pop();
                        PremiumPlanSheet.show(context);
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.workspace_premium_rounded,
                              color: t.premiumOn,
                              size: 22,
                            ),
                            const SizedBox(width: 10),
                            Text(
                              'Upgrade to create quizzes',
                              style: TextStyle(
                                color: t.premiumOn,
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  '${monthlyPriceLabel()} · cancel anytime',
                  textAlign: TextAlign.center,
                  style: AppTokens.mono(size: 12, color: t.textMuted),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _FeatureRow extends StatelessWidget {
  const _FeatureRow({
    required this.icon,
    required this.label,
    required this.iconColor,
    required this.labelColor,
  });

  final IconData icon;
  final String label;
  final Color iconColor;
  final Color labelColor;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 20, color: iconColor),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              color: labelColor,
              fontSize: 15,
              fontWeight: FontWeight.w500,
              height: 1.3,
            ),
          ),
        ),
      ],
    );
  }
}
