import 'package:flutter/material.dart';

import '../../../app/design.dart';

class AdminStatCard extends StatelessWidget {
  const AdminStatCard({
    super.key,
    required this.label,
    required this.value,
    required this.trend,
    required this.icon,
  });

  final String label;
  final String value;
  final String trend;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: t.surface,
        borderRadius: BorderRadius.circular(Radii.card),
        border: Border.all(color: t.line),
        boxShadow: AppTokens.elevation(t.shadow, opacity: 0.06),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 20, color: t.textMuted),
              const Spacer(),
              Icon(Icons.trending_up_rounded, size: 18, color: t.success),
            ],
          ),
          const Spacer(),
          Text(
            label,
            style: AppTokens.mono(size: 11, color: t.textFaint),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w700,
              color: t.text,
              letterSpacing: -0.02,
            ),
          ),
          const SizedBox(height: 4),
          Text(trend, style: TextStyle(fontSize: 12, color: t.textMuted)),
        ],
      ),
    );
  }
}
