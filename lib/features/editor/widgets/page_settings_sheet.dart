import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/enums.dart';
import '../../../core/models/margin_spec.dart';
import '../../../core/models/page_geometry.dart';
import '../providers.dart';

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
      showDragHandle: true,
      builder: (_) =>
          PageSettingsSheet(documentId: documentId, pageSize: pageSize),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(editorControllerProvider(documentId));
    final controller = ref.read(editorControllerProvider(documentId).notifier);
    final page = state.currentPage;
    if (page == null) return const SizedBox.shrink();
    final margins = page.marginSpec;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('Page', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 16),
          _label(context, 'Template'),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final t in const [
                PaperTemplate.blank,
                PaperTemplate.lined,
                PaperTemplate.gridSmall,
                PaperTemplate.gridLarge,
                PaperTemplate.dotted,
                PaperTemplate.cornell,
                PaperTemplate.music,
                PaperTemplate.planner,
              ])
                ChoiceChip(
                  label: Text(t.label),
                  selected: page.template == t,
                  onSelected: (_) => controller.setTemplate(t),
                ),
            ],
          ),
          const SizedBox(height: 16),
          _label(context, 'Paper colour'),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final c in PaperColor.values)
                ChoiceChip(
                  label: Text(c.label),
                  selected: page.paperColor == c,
                  onSelected: (_) => controller.setPaperColor(c),
                ),
            ],
          ),
          const Divider(height: 32),
          Row(
            children: [
              Text('Margins',
                  style: Theme.of(context).textTheme.titleMedium),
              const Spacer(),
              Switch(
                value: margins.enabled,
                onChanged: (v) =>
                    controller.setMargins(margins.copyWith(enabled: v)),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Wrap(
            spacing: 8,
            children: [
              ActionChip(
                label: const Text('Left rule'),
                onPressed: () =>
                    controller.setMargins(MarginSpec.leftRule()),
              ),
              ActionChip(
                label: const Text('Uniform'),
                onPressed: () => controller.setMargins(MarginSpec.uniform(48)),
              ),
              ActionChip(
                label: const Text('None'),
                onPressed: () => controller.setMargins(MarginSpec.none),
              ),
            ],
          ),
          if (margins.enabled) ...[
            _MarginSlider(
              label: 'Left',
              value: margins.left,
              max: pageSize.width / 2,
              onChanged: (v) =>
                  controller.setMargins(margins.copyWith(left: v)),
            ),
            _MarginSlider(
              label: 'Right',
              value: margins.right,
              max: pageSize.width / 2,
              onChanged: (v) =>
                  controller.setMargins(margins.copyWith(right: v)),
            ),
            _MarginSlider(
              label: 'Top',
              value: margins.top,
              max: pageSize.height / 2,
              onChanged: (v) => controller.setMargins(margins.copyWith(top: v)),
            ),
            _MarginSlider(
              label: 'Bottom',
              value: margins.bottom,
              max: pageSize.height / 2,
              onChanged: (v) =>
                  controller.setMargins(margins.copyWith(bottom: v)),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: margins.showGuides,
              onChanged: (v) =>
                  controller.setMargins(margins.copyWith(showGuides: v)),
              title: const Text('Show guide lines'),
            ),
          ],
        ],
      ),
    );
  }

  Widget _label(BuildContext context, String text) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(text,
            style: Theme.of(context)
                .textTheme
                .labelLarge
                ?.copyWith(color: Theme.of(context).hintColor)),
      );
}

class _MarginSlider extends StatelessWidget {
  const _MarginSlider({
    required this.label,
    required this.value,
    required this.max,
    required this.onChanged,
  });

  final String label;
  final double value;
  final double max;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(width: 64, child: Text(label)),
        Expanded(
          child: Slider(
            value: value.clamp(0, max),
            max: max,
            onChanged: onChanged,
          ),
        ),
        SizedBox(
          width: 42,
          child: Text('${value.round()}',
              textAlign: TextAlign.end),
        ),
      ],
    );
  }
}
