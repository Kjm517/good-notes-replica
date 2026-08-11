import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/enums.dart';
import '../../../core/models/margin_spec.dart';
import '../../../core/models/page_geometry.dart';
import '../providers.dart';
import 'cover_styles.dart';

/// Result of the new-notebook flow.
class NewNotebookResult {
  const NewNotebookResult(this.documentId);
  final String documentId;
}

/// Bottom sheet to configure and create a new notebook.
class NewNotebookSheet extends ConsumerStatefulWidget {
  const NewNotebookSheet({super.key, required this.parentId});
  final String? parentId;

  static Future<void> show(BuildContext context, {String? parentId}) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => NewNotebookSheet(parentId: parentId),
    );
  }

  @override
  ConsumerState<NewNotebookSheet> createState() => _NewNotebookSheetState();
}

class _NewNotebookSheetState extends ConsumerState<NewNotebookSheet> {
  final _title = TextEditingController(text: 'Untitled Notebook');
  int _cover = 0;
  PaperTemplate _template = PaperTemplate.lined;
  PaperColor _paper = PaperColor.white;
  PageSizePreset _size = PageSizePreset.a4;
  PageOrientation _orientation = PageOrientation.portrait;
  bool _marginRule = false;
  bool _busy = false;

  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    setState(() => _busy = true);
    final repo = ref.read(libraryRepositoryProvider);
    final doc = await repo.createNotebook(
      parentId: widget.parentId,
      title: _title.text.trim().isEmpty ? 'Untitled Notebook' : _title.text.trim(),
      coverStyle: _cover,
      orientation: _orientation,
      pageSize: _size,
      template: _template,
      paperColor: _paper,
      margins: _marginRule ? MarginSpec.leftRule() : MarginSpec.none,
    );
    if (mounted) Navigator.of(context).pop(NewNotebookResult(doc.id));
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('New Notebook',
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            _CoverPreview(cover: _cover, template: _template, paper: _paper),
            const SizedBox(height: 16),
            TextField(
              controller: _title,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Title',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 20),
            _sectionLabel(context, 'Cover'),
            _CoverPicker(
              selected: _cover,
              onSelected: (i) => setState(() => _cover = i),
            ),
            const SizedBox(height: 16),
            _sectionLabel(context, 'Paper template'),
            _ChoiceWrap<PaperTemplate>(
              values: const [
                PaperTemplate.blank,
                PaperTemplate.lined,
                PaperTemplate.gridSmall,
                PaperTemplate.gridLarge,
                PaperTemplate.dotted,
                PaperTemplate.cornell,
                PaperTemplate.music,
                PaperTemplate.planner,
              ],
              selected: _template,
              label: (t) => t.label,
              onSelected: (t) => setState(() => _template = t),
            ),
            const SizedBox(height: 16),
            _sectionLabel(context, 'Paper colour'),
            _ChoiceWrap<PaperColor>(
              values: PaperColor.values,
              selected: _paper,
              label: (c) => c.label,
              onSelected: (c) => setState(() => _paper = c),
            ),
            const SizedBox(height: 16),
            _sectionLabel(context, 'Size'),
            _ChoiceWrap<PageSizePreset>(
              values: PageSizePreset.values,
              selected: _size,
              label: (s) => s.label,
              onSelected: (s) => setState(() => _size = s),
            ),
            const SizedBox(height: 16),
            _sectionLabel(context, 'Orientation'),
            _ChoiceWrap<PageOrientation>(
              values: PageOrientation.values,
              selected: _orientation,
              label: (o) =>
                  o == PageOrientation.portrait ? 'Portrait' : 'Landscape',
              onSelected: (o) => setState(() => _orientation = o),
            ),
            const SizedBox(height: 8),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: _marginRule,
              onChanged: (v) => setState(() => _marginRule = v),
              title: const Text('Add margin line'),
              subtitle: const Text('Classic left margin (adjustable later)'),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _busy ? null : _create,
                child: _busy
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text('Create'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionLabel(BuildContext context, String text) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(text,
            style: Theme.of(context)
                .textTheme
                .labelLarge
                ?.copyWith(color: Theme.of(context).hintColor)),
      );
}

class _CoverPreview extends StatelessWidget {
  const _CoverPreview(
      {required this.cover, required this.template, required this.paper});
  final int cover;
  final PaperTemplate template;
  final PaperColor paper;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        height: 150,
        width: 110,
        decoration: BoxDecoration(
          gradient: coverStyleAt(cover).gradient,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.18),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        alignment: Alignment.bottomCenter,
        child: Container(
          margin: const EdgeInsets.all(8),
          height: 34,
          decoration: BoxDecoration(
            color: paper.color,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
      ),
    );
  }
}

class _CoverPicker extends StatelessWidget {
  const _CoverPicker({required this.selected, required this.onSelected});
  final int selected;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: kCoverStyles.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (context, i) {
          final isSel = i == selected;
          return GestureDetector(
            onTap: () => onSelected(i),
            child: Container(
              width: 44,
              decoration: BoxDecoration(
                gradient: kCoverStyles[i].gradient,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isSel
                      ? Theme.of(context).colorScheme.primary
                      : Colors.transparent,
                  width: 3,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _ChoiceWrap<T> extends StatelessWidget {
  const _ChoiceWrap({
    required this.values,
    required this.selected,
    required this.label,
    required this.onSelected,
  });

  final List<T> values;
  final T selected;
  final String Function(T) label;
  final ValueChanged<T> onSelected;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final v in values)
          ChoiceChip(
            label: Text(label(v)),
            selected: v == selected,
            onSelected: (_) => onSelected(v),
          ),
      ],
    );
  }
}
