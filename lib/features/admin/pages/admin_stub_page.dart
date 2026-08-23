import 'package:flutter/material.dart';

import '../../../app/design.dart';

class AdminStubPage extends StatelessWidget {
  const AdminStubPage({
    super.key,
    required this.title,
    required this.description,
    this.dark = false,
  });

  final String title;
  final String description;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    final t = dark ? AppTokens.dark : context.tokens;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.construction_outlined, size: 48, color: t.textFaint),
              const SizedBox(height: 16),
              Text(
                title,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: t.text,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                description,
                textAlign: TextAlign.center,
                style: TextStyle(color: t.textMuted, height: 1.45),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
