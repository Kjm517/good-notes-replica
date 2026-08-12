import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/design.dart';
import '../../../core/models/enums.dart';
import '../../../core/models/page_geometry.dart';
import '../providers.dart';
import 'margins_sheet.dart';

/// Bottom sheet to change the current page's template, paper colour and the
/// adjustable margins. The margins editor is the UI seam for the custom
/// "adjustable / extendable margins" feature.
class PageSettingsSheet extends ConsumerWidget {
  const PageSettingsSheet({
    super.key,
    required this.documentId,
    required this.pageSize,
  });

  final String documentId;
  final Size pageSize;

  static Future<void> show(
    BuildContext context, {
    required String documentId,
    required Size pageSize,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) =>
          PageSettingsSheet(documentId: documentId, pageSize: pageSize),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    final state = ref.watch(editorControllerProvider(documentId));
    final controller = ref.read(editorControllerProvider(documentId).notifier);
    final page = state.currentPage;
    if (page == null) return const SizedBox.shrink();
    final margins = page.marginSpec;

    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.82,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 16, 14),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Page settings',
                            style: Theme.of(context)
                                .textTheme
                                .titleLarge
                                ?.copyWith(fontSize: 18)),
                        const SizedBox(height: 3),
                        Text(
                          'Page ${state.currentIndex + 1}',
                          style:
                              AppTokens.mono(size: 11, color: t.textFaint),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    color: t.textFaint,
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            Divider(height: 1, color: t.line),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                padding: const EdgeInsets.fromLTRB(24, 4, 24, 24),
                children: [
                  _Caption(label: 'Page setup'),
                  _Row(
                    label: 'Template',
                    child: Wrap(
                      alignment: WrapAlignment.end,
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final template in const [
                          PaperTemplate.blank,
                          PaperTemplate.lined,
                          PaperTemplate.gridSmall,
                          PaperTemplate.gridLarge,
                          PaperTemplate.dotted,
                          PaperTemplate.cornell,
                          PaperTemplate.music,
                          PaperTemplate.planner,
                        ])
                          _Pill(
                            label: template.label,
                            selected: page.template == template,
                            onTap: () => controller.setTemplate(template),
                          ),
                      ],
                    ),
                  ),
                  _Row(
                    label: 'Paper colour',
                    child: Wrap(
                      alignment: WrapAlignment.end,
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final c in PaperColor.values)
                          _Pill(
                            label: c.label,
                            selected: page.paperColor == c,
                            onTap: () => controller.setPaperColor(c),
                          ),
                      ],
                    ),
                  ),
                  _Caption(label: 'Layout'),
                  // Margins live in their own panel — see the Margins toolbar
                  // button.
                  InkWell(
                    borderRadius: BorderRadius.circular(Radii.control),
                    onTap: () {
                      Navigator.of(context).pop();
                      MarginsSheet.show(context,
                          documentId: documentId, pageSize: pageSize);
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Row(
                        children: [
                          Icon(Icons.straighten_rounded,
                              size: 20, color: t.textSecondary),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Margins',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                      color: t.text,
                                    )),
                                const SizedBox(height: 2),
                                Text(
                                  margins.enabled
                                      ? 'On — extends the page around your notes'
                                      : 'Off',
                                  style: TextStyle(
                                      fontSize: 12, color: t.textMuted),
                                ),
                              ],
                            ),
                          ),
                          Icon(Icons.chevron_right_rounded,
                              size: 20, color: t.textFaint),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The Space Mono uppercase caption that heads each group of settings.
class _Caption extends StatelessWidget {
  const _Caption({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Padding(
      padding: const EdgeInsets.only(top: 18, bottom: 10),
      child: Text(label.toUpperCase(),
          style: AppTokens.sectionLabel(t.textFaint)),
    );
  }
}

/// Label on the left, control on the right — the settings row shape used
/// throughout the design.
class _Row extends StatelessWidget {
  const _Row({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 11),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: t.text,
                )),
          ),
          const SizedBox(width: 16),
          Expanded(child: Align(alignment: Alignment.centerRight, child: child)),
        ],
      ),
    );
  }
}

/// Compact selectable pill, replacing Material's chunkier ChoiceChip.
class _Pill extends StatelessWidget {
  const _Pill({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Material(
      color: selected ? t.accentSoft : t.fill,
      borderRadius: BorderRadius.circular(9),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(9),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(9),
            border: Border.all(color: selected ? t.accent : t.line),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
              color: selected ? t.accentText : t.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}
