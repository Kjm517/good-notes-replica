import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/db/database.dart';
import '../pages/paper_painter.dart';
import '../providers.dart';

/// End-drawer showing page thumbnails with add / duplicate / delete / reorder.
class PageThumbnailsDrawer extends ConsumerWidget {
  const PageThumbnailsDrawer({
    super.key,
    required this.documentId,
    required this.pageSize,
  });

  final String documentId;
  final Size pageSize;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pagesAsync = ref.watch(pagesStreamProvider(documentId));
    final pageRepo = ref.read(pageRepositoryProvider);
    final controller = ref.read(editorControllerProvider(documentId).notifier);
    final currentIndex =
        ref.watch(editorControllerProvider(documentId)).currentIndex;

    return Drawer(
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Text('Pages',
                      style: Theme.of(context).textTheme.titleLarge),
                  const Spacer(),
                  IconButton(
                    tooltip: 'Add page',
                    icon: const Icon(Icons.add),
                    onPressed: () => pageRepo.addPage(documentId),
                  ),
                ],
              ),
            ),
            Expanded(
              child: pagesAsync.when(
                loading: () =>
                    const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(child: Text('Error: $e')),
                data: (pages) => ReorderableListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: pages.length,
                  onReorder: (oldIndex, newIndex) {
                    if (newIndex > oldIndex) newIndex -= 1;
                    pageRepo.reorderPage(documentId, oldIndex, newIndex);
                  },
                  itemBuilder: (context, i) {
                    final page = pages[i];
                    return _PageTile(
                      key: ValueKey(page.id),
                      page: page,
                      pageSize: pageSize,
                      index: i,
                      selected: i == currentIndex,
                      onTap: () {
                        controller.goToPage(i);
                        Navigator.of(context).pop();
                      },
                      onDuplicate: () => pageRepo.duplicatePage(page.id),
                      onDelete: pages.length > 1
                          ? () => pageRepo.deletePage(page.id)
                          : null,
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PageTile extends StatelessWidget {
  const _PageTile({
    super.key,
    required this.page,
    required this.pageSize,
    required this.index,
    required this.selected,
    required this.onTap,
    required this.onDuplicate,
    required this.onDelete,
  });

  final NotePage page;
  final Size pageSize;
  final int index;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback onDuplicate;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          GestureDetector(
            onTap: onTap,
            child: Container(
              width: 60,
              height: 60 * pageSize.height / pageSize.width,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: selected ? scheme.primary : Colors.black26,
                  width: selected ? 2.5 : 1,
                ),
              ),
              clipBehavior: Clip.antiAlias,
              child: FittedBox(
                fit: BoxFit.fill,
                child: SizedBox(
                  width: pageSize.width,
                  height: pageSize.height,
                  child: CustomPaint(
                    painter: PaperPainter(
                      template: page.template,
                      paperColor: page.paperColor,
                      margins: page.marginSpec,
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(child: Text('Page ${index + 1}')),
          IconButton(
            tooltip: 'Duplicate',
            icon: const Icon(Icons.copy_rounded, size: 20),
            onPressed: onDuplicate,
          ),
          IconButton(
            tooltip: 'Delete',
            icon: const Icon(Icons.delete_outline_rounded, size: 20),
            onPressed: onDelete,
          ),
        ],
      ),
    );
  }
}
