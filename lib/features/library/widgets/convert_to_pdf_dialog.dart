import 'package:flutter/material.dart';

import '../data/import_service.dart';

/// Explains how to turn a PowerPoint/Word/Keynote file into a PDF the app can
/// annotate.
///
/// Rather than failing silently, this names the file, says why, and gives the
/// exact menu path — the conversion takes one step in the app that made it,
/// and produces better fidelity than any converter we could ship.
class ConvertToPdfDialog extends StatelessWidget {
  const ConvertToPdfDialog({super.key, required this.failure});

  final UnsupportedImportFormat failure;

  static Future<void> show(
      BuildContext context, UnsupportedImportFormat failure) {
    return showDialog<void>(
      context: context,
      builder: (_) => ConvertToPdfDialog(failure: failure),
    );
  }

  @override
  Widget build(BuildContext context) {
    final kind = failure.isPresentation ? 'presentation' : 'document';
    return AlertDialog(
      icon: const Icon(Icons.picture_as_pdf_outlined, size: 32),
      title: const Text('Save it as a PDF first'),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '“${failure.filename}” is a ${failure.appName} $kind. '
              'Import it as a PDF to annotate and to generate quizzes from it.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 14),
            _Step(
              number: 1,
              text: 'Open the file in ${failure.appName}.',
            ),
            _Step(
              number: 2,
              text: failure.isPresentation
                  ? 'Choose File → Save As (or Export) and pick PDF.'
                  : 'Choose File → Save As (or Export) and pick PDF.',
            ),
            const _Step(
              number: 3,
              text: 'Come back here and import that PDF.',
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.lightbulb_outline_rounded, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Google Slides and Docs can do this too: '
                      'File → Download → PDF Document.',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Every slide keeps its exact layout and fonts this way, because '
              '${failure.appName} does the rendering.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).hintColor,
                  ),
            ),
          ],
        ),
      ),
      actions: [
        FilledButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Got it'),
        ),
      ],
    );
  }
}

class _Step extends StatelessWidget {
  const _Step({required this.number, required this.text});
  final int number;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 11,
            backgroundColor: Theme.of(context).colorScheme.primaryContainer,
            child: Text(
              '$number',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: Theme.of(context).colorScheme.onPrimaryContainer,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(text, style: Theme.of(context).textTheme.bodyMedium),
          ),
        ],
      ),
    );
  }
}
