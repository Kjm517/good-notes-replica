import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(themeModeProvider);
    final controller = ref.read(themeModeProvider.notifier);

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          const _SectionHeader('Appearance'),
          RadioListTile<ThemeMode>(
            value: ThemeMode.system,
            groupValue: mode,
            onChanged: (m) => controller.set(m!),
            title: const Text('System default'),
          ),
          RadioListTile<ThemeMode>(
            value: ThemeMode.light,
            groupValue: mode,
            onChanged: (m) => controller.set(m!),
            title: const Text('Light'),
          ),
          RadioListTile<ThemeMode>(
            value: ThemeMode.dark,
            groupValue: mode,
            onChanged: (m) => controller.set(m!),
            title: const Text('Dark'),
          ),
          const Divider(),
          const _SectionHeader('About'),
          const ListTile(
            title: Text('Notably'),
            subtitle: Text('A GoodNotes-style note-taking app'),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
      child: Text(
        text.toUpperCase(),
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: Theme.of(context).colorScheme.primary,
              letterSpacing: 1,
              fontWeight: FontWeight.w700,
            ),
      ),
    );
  }
}
