import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/margin_spec.dart';
import '../providers.dart';

/// Dedicated editor for the page's adjustable / extendable margins — this
/// app's custom feature. Opened from the Margins button in the toolbar.
///
/// Dragging a slider updates an in-memory preview so the page follows the
/// gesture smoothly; the value is written to the database once on release.
class MarginsSheet extends ConsumerWidget {
  const MarginsSheet({
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
      builder: (_) => MarginsSheet(documentId: documentId, pageSize: pageSize),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(editorControllerProvider(documentId));
    final controller = ref.read(editorControllerProvider(documentId).notifier);
    final page = state.currentPage;
    final margins = state.effectiveMargins;
    if (page == null || margins == null) return const SizedBox.shrink();

    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
          20, 0, 20, 28 + MediaQuery.of(context).viewInsets.bottom),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              const Icon(Icons.straighten_rounded),
              const SizedBox(width: 8),
              Text('Margins', style: Theme.of(context).textTheme.titleLarge),
              const Spacer(),
              Switch(
                value: margins.enabled,
                onChanged: (v) =>
                    controller.setMargins(margins.copyWith(enabled: v)),
              ),
            ],
          ),
          Text('Page ${state.currentIndex + 1}',
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: Theme.of(context).hintColor)),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ActionChip(
                avatar: const Icon(Icons.border_left_rounded, size: 18),
                label: const Text('Left rule'),
                onPressed: () => controller.setMargins(MarginSpec.leftRule()),
              ),
              ActionChip(
                avatar: const Icon(Icons.crop_free_rounded, size: 18),
                label: const Text('Uniform'),
                onPressed: () => controller.setMargins(MarginSpec.uniform(48)),
              ),
              ActionChip(
                avatar: const Icon(Icons.close_rounded, size: 18),
                label: const Text('None'),
                onPressed: () => controller.setMargins(MarginSpec.none),
              ),
            ],
          ),
          if (margins.enabled) ...[
            const SizedBox(height: 4),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: margins.extend,
              onChanged: (v) =>
                  controller.setMargins(margins.copyWith(extend: v)),
              title: const Text('Extend the page'),
              subtitle: Text(margins.extend
                  ? 'Adds blank space around the content to write in'
                  : 'Insets the content within the existing page'),
            ),
            _MarginRow(
              label: 'Left',
              value: margins.left,
              max: pageSize.width,
              onPreview: (v) =>
                  controller.previewMargins(margins.copyWith(left: v)),
              onCommit: (v) => controller.setMargins(margins.copyWith(left: v)),
            ),
            _MarginRow(
              label: 'Right',
              value: margins.right,
              max: pageSize.width,
              onPreview: (v) =>
                  controller.previewMargins(margins.copyWith(right: v)),
              onCommit: (v) => controller.setMargins(margins.copyWith(right: v)),
            ),
            _MarginRow(
              label: 'Top',
              value: margins.top,
              max: pageSize.height,
              onPreview: (v) =>
                  controller.previewMargins(margins.copyWith(top: v)),
              onCommit: (v) => controller.setMargins(margins.copyWith(top: v)),
            ),
            _MarginRow(
              label: 'Bottom',
              value: margins.bottom,
              max: pageSize.height,
              onPreview: (v) =>
                  controller.previewMargins(margins.copyWith(bottom: v)),
              onCommit: (v) =>
                  controller.setMargins(margins.copyWith(bottom: v)),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: margins.showGuides,
              onChanged: (v) =>
                  controller.setMargins(margins.copyWith(showGuides: v)),
              title: const Text('Show guide lines'),
            ),
            const Divider(),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                icon: const Icon(Icons.done_all_rounded),
                label: const Text('Apply to all pages'),
                onPressed: () async {
                  await controller.applyMarginsToAllPages(margins);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content: Text('Margins applied to all pages')),
                    );
                  }
                },
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// One margin edge: a slider for coarse adjustment plus an editable number
/// field for an exact value.
class _MarginRow extends StatefulWidget {
  const _MarginRow({
    required this.label,
    required this.value,
    required this.max,
    required this.onPreview,
    required this.onCommit,
  });

  final String label;
  final double value;
  final double max;

  /// Called continuously while dragging (in-memory only).
  final ValueChanged<double> onPreview;

  /// Called once when the gesture ends or a number is typed (persists).
  final ValueChanged<double> onCommit;

  @override
  State<_MarginRow> createState() => _MarginRowState();
}

class _MarginRowState extends State<_MarginRow> {
  late final TextEditingController _field =
      TextEditingController(text: widget.value.round().toString());
  final _focus = FocusNode();
  double? _dragValue;

  @override
  void initState() {
    super.initState();
    _focus.addListener(() {
      if (!_focus.hasFocus) _submit(_field.text);
    });
  }

  @override
  void didUpdateWidget(covariant _MarginRow old) {
    super.didUpdateWidget(old);
    // Hold the gesture's value until the controller catches up, so a stale
    // watch snapshot cannot snap the slider back on release.
    if (_dragValue != null && (widget.value - _dragValue!).abs() < 0.51) {
      _dragValue = null;
    }
    if (!_focus.hasFocus && widget.value != old.value) {
      _field.text = widget.value.round().toString();
    }
  }

  @override
  void dispose() {
    _field.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _submit(String text) {
    final parsed = double.tryParse(text.trim());
    if (parsed == null) {
      _field.text = widget.value.round().toString();
      return;
    }
    final clamped = parsed.clamp(0.0, widget.max).toDouble();
    _field.text = clamped.round().toString();
    widget.onCommit(clamped);
  }

  @override
  Widget build(BuildContext context) {
    final shown = _dragValue ?? widget.value;
    return Row(
      children: [
        SizedBox(width: 62, child: Text(widget.label)),
        Expanded(
          child: Slider(
            value: shown.clamp(0, widget.max),
            max: widget.max,
            onChanged: (v) {
              setState(() => _dragValue = v);
              widget.onPreview(v);
            },
            onChangeEnd: (v) {
              setState(() => _dragValue = v);
              widget.onCommit(v);
            },
          ),
        ),
        // Editable exact value.
        SizedBox(
          width: 56,
          child: TextField(
            controller: _field,
            focusNode: _focus,
            textAlign: TextAlign.end,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
            ],
            decoration: const InputDecoration(
              isDense: true,
              contentPadding: EdgeInsets.symmetric(vertical: 8, horizontal: 6),
              border: OutlineInputBorder(),
            ),
            onSubmitted: _submit,
          ),
        ),
      ],
    );
  }
}
