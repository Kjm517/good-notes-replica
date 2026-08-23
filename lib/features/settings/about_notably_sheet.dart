import 'package:flutter/material.dart';

import '../../app/app_version.dart';
import '../../app/design.dart';
import 'settings_widgets.dart';

class AboutNotablySheet extends StatelessWidget {
  const AboutNotablySheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      useSafeArea: true,
      builder: (_) => const AboutNotablySheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final bottom = MediaQuery.viewInsetsOf(context).bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottom),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 4, 24, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const AppMark(size: 72),
              const SizedBox(height: 16),
              Text(
                'Notably',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const SizedBox(height: 6),
              Text(
                'Version $kAppVersion',
                style: AppTokens.mono(size: 12, color: t.textFaint),
              ),
              const SizedBox(height: 16),
              Text(
                'A GoodNotes-style notebook for Android, iOS, and web — '
                'handwriting, PDFs, AI quizzes, and cloud sync.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  height: 1.45,
                  color: t.textSecondary,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                '© ${DateTime.now().year} Notably',
                style: AppTokens.mono(size: 10, color: t.textFaint),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
