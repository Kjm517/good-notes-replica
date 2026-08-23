import 'package:flutter/material.dart';

import '../../app/design.dart';

/// Space Mono section caption + content below.
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
          padding: const EdgeInsets.fromLTRB(6, 22, 6, 10),
          child: Text(label.toUpperCase(), style: AppTokens.sectionLabel(t.textFaint)),
        ),
        child,
      ],
    );
  }
}

/// Bordered surface card used for grouped rows.
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
    final muted = dimmed ? 0.55 : 1.0;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: t.fill,
                borderRadius: BorderRadius.circular(11),
              ),
              child: Icon(
                icon,
                size: 19,
                color: (iconColor ?? t.textSecondary).withValues(alpha: muted),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: t.text.withValues(alpha: muted),
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle!,
                      style: AppTokens.mono(
                        size: 10,
                        color: t.textFaint.withValues(alpha: muted),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (trailing != null) trailing!,
          ],
        ),
      ),
    );
  }
}

class TierBadge extends StatelessWidget {
  const TierBadge({super.key, required this.label, this.premium = false});

  final String label;
  final bool premium;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: premium ? t.premiumSoft : t.fill,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: premium ? t.premium.withValues(alpha: 0.35) : t.line,
        ),
      ),
      child: Text(
        label.toUpperCase(),
        style: AppTokens.mono(
          size: 9,
          weight: FontWeight.w600,
          color: premium ? t.premiumText : t.textMuted,
          letterSpacing: 0.8,
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
    return Material(
      color: t.premiumSoft,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.lock_open_rounded, size: 14, color: t.premiumText),
              const SizedBox(width: 4),
              Text(
                'Unlock',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: t.premiumText,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class AccentSwitch extends StatelessWidget {
  const AccentSwitch({
    super.key,
    required this.value,
    required this.onChanged,
  });

  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Switch.adaptive(
      value: value,
      activeTrackColor: t.accentText,
      onChanged: onChanged,
    );
  }
}

/// Recessed track with raised active pill — section 12 appearance row.
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
        color: t.fill,
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
                    color: mode == opt.$1 ? t.surface : Colors.transparent,
                    borderRadius: BorderRadius.circular(Radii.inner),
                    boxShadow: mode == opt.$1
                        ? AppTokens.elevation(t.shadow, y: 2, blur: 8, opacity: 0.08)
                        : null,
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

/// Gold gradient card for premium upsell and plan summary.
class PremiumGradientCard extends StatelessWidget {
  const PremiumGradientCard({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            t.premiumSoft,
            t.surface,
          ],
        ),
        borderRadius: BorderRadius.circular(Radii.card),
        border: Border.all(color: t.premium.withValues(alpha: 0.35)),
        boxShadow: AppTokens.elevation(t.shadow, y: 12, blur: 28, opacity: 0.1),
      ),
      child: child,
    );
  }
}
