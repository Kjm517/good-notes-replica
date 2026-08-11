import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/db/database.dart';
import '../../core/models/enums.dart';
import '../../core/models/margin_spec.dart';
import '../../core/models/page_geometry.dart';
import '../library/providers.dart';
import 'canvas/page_canvas.dart';
import 'providers.dart';
import 'widgets/editor_toolbar.dart';
import 'widgets/page_settings_sheet.dart';
import 'widgets/page_thumbnails_drawer.dart';

/// The notebook editor: canvas + tools + pages.
class EditorScreen extends ConsumerWidget {
  const EditorScreen({super.key, required this.documentId});
  final String documentId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final docAsync = ref.watch(documentProvider(documentId));
    return docAsync.when(
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, _) => Scaffold(body: Center(child: Text('Error: $e'))),
      data: (doc) {
        if (doc == null) {
          return const Scaffold(body: Center(child: Text('Notebook not found')));
        }
        return _Editor(document: doc);
      },
    );
  }
}

class _Editor extends ConsumerWidget {
  const _Editor({required this.document});
  final Document document;

  Size get _pageSize {
    return document.pageSize.size(document.orientation);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final documentId = document.id;

    // Feed page-list changes into the editor controller.
    ref.listen(pagesStreamProvider(documentId), (prev, next) {
      final pages = next.asData?.value;
      if (pages != null) {
        ref.read(editorControllerProvider(documentId).notifier)
            .onPagesChanged(pages);
      }
    });

    final state = ref.watch(editorControllerProvider(documentId));
    final controller = ref.read(editorControllerProvider(documentId).notifier);
    final page = state.currentPage;

    return Scaffold(
      backgroundColor: Theme.of(context).canvasColor,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.pop(),
        ),
        title: Text(document.title),
        actions: [
          IconButton(
            tooltip: 'Page settings & margins',
            icon: const Icon(Icons.tune_rounded),
            onPressed: page == null
                ? null
                : () => PageSettingsSheet.show(
                      context,
                      documentId: documentId,
                      pageSize: _pageSize,
                    ),
          ),
          Builder(
            builder: (context) => IconButton(
              tooltip: 'Pages',
              icon: const Icon(Icons.grid_view_rounded),
              onPressed: () => Scaffold.of(context).openEndDrawer(),
            ),
          ),
        ],
      ),
      endDrawer: PageThumbnailsDrawer(documentId: documentId, pageSize: _pageSize),
      bottomNavigationBar: EditorToolbar(documentId: documentId),
      body: state.loading || page == null
          ? _EmptyOrLoading(state: state, documentId: documentId)
          : Column(
              children: [
                Expanded(
                  child: PageCanvas(
                    key: ValueKey(page.id),
                    page: page,
                    pageSize: _pageSize,
                    strokes: state.strokes,
                    tool: state.tool,
                    color: state.activeSettings.color,
                    width: state.activeSettings.width,
                    eraserMode: state.eraserMode,
                    onStrokeCommitted: controller.commitStroke,
                    onErase: controller.eraseStrokes,
                  ),
                ),
                _PageNavBar(
                  documentId: documentId,
                  index: state.currentIndex,
                  total: state.pages.length,
                  pageSize: _pageSize,
                ),
              ],
            ),
    );
  }
}

class _EmptyOrLoading extends ConsumerWidget {
  const _EmptyOrLoading({required this.state, required this.documentId});
  final dynamic state;
  final String documentId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (state.loading) {
      return const Center(child: CircularProgressIndicator());
    }
    // No pages: offer to add one.
    return Center(
      child: FilledButton.icon(
        onPressed: () =>
            ref.read(pageRepositoryProvider).addPage(documentId),
        icon: const Icon(Icons.add),
        label: const Text('Add a page'),
      ),
    );
  }
}

class _PageNavBar extends ConsumerWidget {
  const _PageNavBar({
    required this.documentId,
    required this.index,
    required this.total,
    required this.pageSize,
  });
  final String documentId;
  final int index;
  final int total;
  final Size pageSize;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(editorControllerProvider(documentId).notifier);
    final pageRepo = ref.read(pageRepositoryProvider);
    return Material(
      color: Theme.of(context).colorScheme.surface,
      child: SizedBox(
        height: 44,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconButton(
              icon: const Icon(Icons.chevron_left_rounded),
              onPressed: index > 0 ? () => controller.goToPage(index - 1) : null,
            ),
            Text('${index + 1} / $total'),
            IconButton(
              icon: const Icon(Icons.chevron_right_rounded),
              onPressed: index < total - 1
                  ? () => controller.goToPage(index + 1)
                  : null,
            ),
            const SizedBox(width: 12),
            IconButton(
              tooltip: 'Add page',
              icon: const Icon(Icons.note_add_outlined),
              onPressed: () async {
                final current =
                    ref.read(editorControllerProvider(documentId)).currentPage;
                await pageRepo.addPage(
                  documentId,
                  atIndex: index + 1,
                  template: current?.template ?? PaperTemplate.lined,
                  paperColor: current?.paperColor ?? PaperColor.white,
                  margins: current?.marginSpec ?? MarginSpec.none,
                );
                await controller.goToPage(index + 1);
              },
            ),
          ],
        ),
      ),
    );
  }
}
