import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/design.dart';
import '../../app/firebase_bootstrap.dart';
import '../../app/providers.dart';
import '../auth/providers.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    final mode = ref.watch(themeModeProvider);
    final controller = ref.read(themeModeProvider.notifier);

    return Scaffold(
      backgroundColor: t.canvas,
      appBar: AppBar(
        backgroundColor: t.canvas,
        title: const Text('Settings'),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 620),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
            children: [
              const SettingsSection(
                label: 'Account',
                children: [_AccountTile()],
              ),
              SettingsSection(
                label: 'Appearance',
                children: [
                  for (final option in const [
                    (ThemeMode.system, 'System default', Icons.brightness_auto_rounded),
                    (ThemeMode.light, 'Light', Icons.light_mode_rounded),
                    (ThemeMode.dark, 'Dark', Icons.dark_mode_rounded),
                  ])
                    _ChoiceRow(
                      icon: option.$3,
                      label: option.$2,
                      selected: mode == option.$1,
                      onTap: () => controller.set(option.$1),
                    ),
                ],
              ),
              SettingsSection(
                label: 'About',
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Notably',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: t.text,
                            )),
                        const SizedBox(height: 3),
                        Text('A GoodNotes-style note-taking app',
                            style:
                                TextStyle(fontSize: 13, color: t.textMuted)),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A titled card of rows — the grouping used across settings and the document
/// sheet, with a Space Mono caption above a bordered surface.
class SettingsSection extends StatelessWidget {
  const SettingsSection({
    super.key,
    required this.label,
    required this.children,
  });

  final String label;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(6, 22, 6, 10),
          child: Text(label.toUpperCase(),
              style: AppTokens.sectionLabel(t.textFaint)),
        ),
        Container(
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
        ),
      ],
    );
  }
}

/// A single-select row with a check on the active option.
class _ChoiceRow extends StatelessWidget {
  const _ChoiceRow({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Icon(icon,
                size: 20, color: selected ? t.accentText : t.textMuted),
            const SizedBox(width: 14),
            Expanded(
              child: Text(label,
                  style: TextStyle(
                    fontSize: 14.5,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                    color: t.text,
                  )),
            ),
            if (selected)
              Icon(Icons.check_rounded, size: 19, color: t.accentText),
          ],
        ),
      ),
    );
  }
}

/// Shows who's signed in, or invites the user to sign in for sync.
class _AccountTile extends ConsumerWidget {
  const _AccountTile();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    final user = ref.watch(authStateProvider).asData?.value;

    if (user == null) {
      return ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        leading: Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: t.fill,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(Icons.cloud_off_rounded, size: 21, color: t.textMuted),
        ),
        title: const Text('Not signed in',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
        subtitle: Text(
          firebaseReady
              ? 'Sign in to sync your notes across devices'
              : 'Sync is not set up yet — notes are stored on this device',
          style: TextStyle(fontSize: 12.5, color: t.textMuted),
        ),
        trailing: Icon(Icons.chevron_right_rounded, color: t.textFaint),
        onTap: () => context.push('/sign-in'),
      );
    }

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      leading: CircleAvatar(
        radius: 21,
        backgroundColor: t.accentSoft,
        foregroundColor: t.accentText,
        backgroundImage:
            user.photoUrl == null ? null : NetworkImage(user.photoUrl!),
        child: user.photoUrl == null
            ? Text(user.label.characters.first.toUpperCase(),
                style: const TextStyle(fontWeight: FontWeight.w700))
            : null,
      ),
      title: Text(user.label,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
      subtitle: Text(user.email ?? 'Signed in',
          style: AppTokens.mono(size: 11.5, color: t.textMuted)),
      trailing: TextButton(
        onPressed: () async {
          final repo = ref.read(authRepositoryProvider);
          await repo?.signOut();
        },
        child: const Text('Sign out'),
      ),
    );
  }
}
