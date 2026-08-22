import 'package:flutter/material.dart';

import '../../app/design.dart';

/// Space Mono caption + bordered surface — section 12 grouping.
class SettingsSection extends StatelessWidget {
  const SettingsSection({
    super.key,
    required this.label,
    required this.child,
  });

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 20, 4, 8),
          child: Text(label.toUpperCase(), style: AppTokens.sectionLabel(t.textFaint)),
        ),
        child,
      ],
    );
  }
}

class SettingsGroupCard extends StatelessWidget {
  const SettingsGroupCard({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Container(
      decoration: BoxDecoration(
        color: t.surface,
        borderRadius: BorderRadius.circular(Radii.card),
        border: Border.all(color: t.line),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) Divider(height: 1, color: t.line),
            children[i],
          ],
        ],
      ),
    );
  }
}

class SettingsRow extends StatelessWidget {
  const SettingsRow({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.iconColor,
    this.trailing,
    this.onTap,
    this.dimmed = false,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final Color? iconColor;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool dimmed;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Opacity(
      opacity: dimmed ? 0.72 : 1,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 11),
            child: Row(
              children: [
                Icon(icon, size: 21, color: iconColor ?? t.textSecondary),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w600,
                          color: dimmed ? t.textSecondary : t.text,
                        ),
                      ),
                      if (subtitle != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          subtitle!,
                          style: AppTokens.mono(size: 10.5, color: t.textFaint),
                        ),
                      ],
                    ],
                  ),
                ),
                if (trailing != null) trailing!,
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class TierBadge extends StatelessWidget {
  const TierBadge({super.key, required this.premium});

  final bool premium;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    if (premium) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFFF4D58A), Color(0xFFD9A94E)],
          ),
          borderRadius: BorderRadius.circular(100),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.workspace_premium_rounded, size: 10, color: t.premiumOn),
            const SizedBox(width: 2),
            Text(
              'PRO',
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w700,
                color: t.premiumOn,
              ),
            ),
          ],
        ),
      );
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: t.fill,
        borderRadius: BorderRadius.circular(100),
        border: Border.all(color: t.lineStrong),
      ),
      child: Text(
        'FREE',
        style: TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.03,
          color: t.textMuted,
        ),
      ),
    );
  }
}

class UnlockChip extends StatelessWidget {
  const UnlockChip({super.key, required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
        decoration: BoxDecoration(
          color: t.premiumSoft.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(100),
        ),
        child: Text(
          'Unlock',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: t.premiumText,
          ),
        ),
      ),
    );
  }
}

/// Recessed track with raised active pill — matches section 12 appearance row.
class AppearancePicker extends StatelessWidget {
  const AppearancePicker({
    super.key,
    required this.mode,
    required this.onChanged,
  });

  final ThemeMode mode;
  final ValueChanged<ThemeMode> onChanged;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    const options = [
      (ThemeMode.system, Icons.brightness_auto_rounded, 'System'),
      (ThemeMode.light, Icons.light_mode_rounded, 'Light'),
      (ThemeMode.dark, Icons.dark_mode_rounded, 'Dark'),
    ];
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: t.surface,
        borderRadius: BorderRadius.circular(Radii.control),
        border: Border.all(color: t.line),
      ),
      child: Row(
        children: [
          for (final opt in options)
            Expanded(
              child: GestureDetector(
                onTap: () => onChanged(opt.$1),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 140),
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    color: mode == opt.$1 ? t.fill : Colors.transparent,
                    borderRadius: BorderRadius.circular(Radii.inner),
                  ),
                  child: Column(
                    children: [
                      Icon(
                        opt.$2,
                        size: 20,
                        color: mode == opt.$1 ? t.text : t.textMuted,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        opt.$3,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight:
                              mode == opt.$1 ? FontWeight.w600 : FontWeight.w500,
                          color: mode == opt.$1 ? t.text : t.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class PremiumGradientCard extends StatelessWidget {
  const PremiumGradientCard({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(Radii.card),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            t.premium.withValues(alpha: 0.18),
            t.premium.withValues(alpha: 0.05),
          ],
        ),
        border: Border.all(color: t.premium.withValues(alpha: 0.34)),
      ),
      child: child,
    );
  }
}
