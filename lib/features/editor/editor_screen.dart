import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/design.dart';
import '../../core/db/database.dart';
import '../../core/models/enums.dart';
import '../../core/models/page_geometry.dart';
import '../library/providers.dart';
import 'canvas/continuous_canvas.dart';
import 'providers.dart';
import 'widgets/editor_sidebar.dart';
import 'widgets/editor_top_bar.dart';
import 'search/document_search_panel.dart';
import 'widgets/image_actions.dart';
import 'widgets/page_settings_sheet.dart';
import 'widgets/selection_actions.dart';
import 'widgets/zoom_cluster.dart';

/// The notebook / PDF editor: a continuously scrolling page view plus tools.
class EditorScreen extends ConsumerWidget {
  const EditorScreen({super.key, required this.documentId});
  final String documentId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final docAsync = ref.watch(documentStreamProvider(documentId));
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

class _Editor extends ConsumerStatefulWidget {
  const _Editor({required this.document});
  final Document document;

  @override
  ConsumerState<_Editor> createState() => _EditorState();
}

class _EditorState extends ConsumerState<_Editor> {
  final _canvasController = ContinuousCanvasController();
  final _shortcutFocus = FocusNode(debugLabel: 'editor-shortcuts');

  /// Null until the first layout decides a default based on screen width.
  bool? _sidebarOpen;

  /// Whether the "find in document" panel is showing.
  bool _searchOpen = false;

  /// Phones don't have room for a persistent sidebar; tablets/desktops do.
  static const double _kSidebarBreakpoint = 820;

  @override
  void initState() {
    super.initState();
    // Warm the text index quietly so the first Ctrl+F doesn't have to wait
    // for the whole document to be parsed.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final service = ref.read(documentTextServiceProvider);
      unawaited(service.index(widget.document.id));
    });
  }

  @override
  void dispose() {
    _canvasController.dispose();
    _shortcutFocus.dispose();
    super.dispose();
  }

  /// Ctrl/Cmd+Z to undo, Ctrl+Shift+Z or Ctrl+Y to redo.
  KeyEventResult _onShortcut(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    final keys = HardwareKeyboard.instance;
    final controller =
        ref.read(editorControllerProvider(widget.document.id).notifier);

    // Escape closes search first, then dismisses any selection.
    if (event.logicalKey == LogicalKeyboardKey.escape) {
      if (_searchOpen) {
        setState(() => _searchOpen = false);
        return KeyEventResult.handled;
      }
      controller.clearSelection();
      controller.selectElement(null);
      return KeyEventResult.handled;
    }

    final mod = keys.isControlPressed || keys.isMetaPressed;
    if (!mod) return KeyEventResult.ignored;

    final key = event.logicalKey;

    // Ctrl/Cmd+F — find in document.
    if (key == LogicalKeyboardKey.keyF) {
      setState(() => _searchOpen = true);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.keyZ) {
      keys.isShiftPressed ? controller.redo() : controller.undo();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.keyY) {
      controller.redo();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  Size get _defaultPageSize =>
      widget.document.pageSize.size(widget.document.orientation);

  Size _sizeFor(NotePage page) {
    final w = page.pageW;
    final h = page.pageH;
    if (w != null && h != null) return Size(w, h);
    return _defaultPageSize;
  }

  @override
  Widget build(BuildContext context) {
    final documentId = widget.document.id;

    ref.listen(pagesStreamProvider(documentId), (prev, next) {
      final pages = next.asData?.value;
      if (pages != null) {
        ref
            .read(editorControllerProvider(documentId).notifier)
            .onPagesChanged(pages);
      }
    });

    final state = ref.watch(editorControllerProvider(documentId));
    final controller = ref.read(editorControllerProvider(documentId).notifier);
    final page = state.currentPage;

    final screenWidth = MediaQuery.of(context).size.width;
    final wideScreen = screenWidth >= _kSidebarBreakpoint;
    final layout = EditorBarLayout.forWidth(screenWidth);
    // Default open on tablets/desktop, closed on phones; the user's explicit
    // toggle wins once they've set it.
    final sidebarOpen = _sidebarOpen ?? wideScreen;

    return Focus(
      focusNode: _shortcutFocus,
      autofocus: true,
      onKeyEvent: _onShortcut,
      child: Scaffold(
        backgroundColor: context.tokens.canvas,
        appBar: EditorTopBar(
          documentId: documentId,
          title: widget.document.title,
          subtitle: state.pages.isEmpty
              ? 'No pages'
              : 'Page ${state.currentIndex + 1} of ${state.pages.length}',
          sidebarOpen: sidebarOpen,
          onToggleSidebar: () => setState(() => _sidebarOpen = !sidebarOpen),
          currentIndex: state.currentIndex,
          pageCount: state.pages.length,
          canvasController: _canvasController,
          pageSizeFor: _sizeFor,
          onRename: () => _renameDocument(context, ref, widget.document),
          onToggleBookmark:
              page == null ? () {} : () => _toggleBookmark(context, page),
          bookmarked: page?.bookmarkTitle != null,
          onOpenPageSettings: page == null
              ? () {}
              : () => PageSettingsSheet.show(
                    context,
                    documentId: documentId,
                    pageSize: _sizeFor(page),
                  ),
          layout: layout,
          onFind: () => setState(() => _searchOpen = !_searchOpen),
          onBack: () => context.pop(),
        ),
        // On a phone the tools live at the bottom, within thumb reach.
        bottomNavigationBar: layout.showsTools || state.pages.isEmpty
            ? null
            : EditorToolDock(documentId: documentId, pageSizeFor: _sizeFor),
        body: state.loading
            ? const Center(child: CircularProgressIndicator())
            : state.pages.isEmpty
                ? Center(
                    child: FilledButton.icon(
                      onPressed: () =>
                          ref.read(pageRepositoryProvider).addPage(documentId),
                      icon: const Icon(Icons.add),
                      label: const Text('Add a page'),
                    ),
                  )
                : Stack(
                  children: [
                  Row(
                    children: [
                      if (sidebarOpen)
                        EditorSidebar(
                          documentId: documentId,
                          pages: state.pages,
                          currentIndex: state.currentIndex,
                          defaultPageSize: _defaultPageSize,
                          onJumpToPage: _canvasController.jumpToPage,
                        ),
                      Expanded(
                        child: ContinuousCanvas(
                          controller: _canvasController,
                          pages: state.pagesForRender,
                          sizeFor: _sizeFor,
                          strokesByPage: state.strokesByPage,
                          tool: state.tool,
                          color: state.activeSettings.color,
                          width: state.activeSettings.width,
                          strokeStyle: state.activeSettings.style,
                          strokeTip: state.activeSettings.tip,
                          shapeOptions: state.shapeOptions,
                          lassoOptions: state.lassoOptions,
                          eraserMode: state.eraserMode,
                          onStrokeCommitted: controller.commitStroke,
                          onErase: controller.eraseStrokes,
                          onPageVisible: controller.ensurePageLoaded,
                          onCurrentPageChanged: controller.setCurrentIndex,
                          backgroundLoader: (p) =>
                              ref.read(pageBackgroundServiceProvider).load(p),
                          cachedBackground: (p) => ref
                              .read(pageBackgroundServiceProvider)
                              .cachedOrThumb(p),
                          prefetch: (pages) => ref
                              .read(pageBackgroundServiceProvider)
                              .prefetch(pages),
                          selection: state.selection,
                          onLassoComplete: controller.selectWithLasso,
                          onSelectionDrag: controller.dragSelection,
                          onSelectionDragEnd: controller.commitSelectionMove,
                          onClearSelection: controller.clearSelection,
                          elementsFor: (pageId) =>
                              ref.watch(pageElementsProvider(pageId)).asData
                                  ?.value ??
                              const [],
                          imageBytesFor: (assetId) => ref
                              .read(elementRepositoryProvider)
                              .imageBytes(assetId),
                          selectedElementId: state.selectedElementId,
                          onSelectElement: controller.selectElement,
                          onElementRotate: (id, angle, committed) {
                            if (!committed) return;
                            ref
                                .read(elementRepositoryProvider)
                                .updateTransform(id, rotation: angle);
                          },
                          onElementTransform: (id, rect, committed) {
                            if (!committed) return;
                            ref.read(elementRepositoryProvider).updateTransform(
                                  id,
                                  x: rect.left,
                                  y: rect.top,
                                  width: rect.width,
                                  height: rect.height,
                                );
                          },
                        ),
                      ),
                    ],
                  ),
                  if (state.selection != null)
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 18,
                      child: Center(
                        child: SelectionActions(documentId: documentId),
                      ),
                    ),
                  // Bottom-right zoom, where the pointer already is. Phones
                  // pinch instead, and the tool dock owns their bottom edge.
                  if (layout.showsTools)
                    Positioned(
                      right: 24,
                      bottom: 24,
                      child: ZoomCluster(controller: _canvasController),
                    ),
                  if (_searchOpen)
                    Positioned(
                      top: 12,
                      right: 16,
                      child: DocumentSearchPanel(
                        documentId: documentId,
                        onJumpToPage: _canvasController.jumpToPage,
                        onClose: () => setState(() => _searchOpen = false),
                      ),
                    ),
                  if (state.tool == ToolType.image)
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 18,
                      child: Center(
                        child: ImageActions(
                          documentId: documentId,
                          pageWidth:
                              page == null ? 600 : _sizeFor(page).width,
                        ),
                      ),
                    ),
                  ],
                ),
      ),
    );
  }

  Future<void> _toggleBookmark(BuildContext context, NotePage page) async {
    final repo = ref.read(pageRepositoryProvider);
    if (page.bookmarkTitle != null) {
      await repo.setBookmark(page.id, null);
      return;
    }
    final controller = TextEditingController(
        text: 'Page ${ref.read(editorControllerProvider(widget.document.id)).currentIndex + 1}');
    final title = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add to outline'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Title'),
          onSubmitted: (v) => Navigator.pop(context, v.trim()),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Add'),
          ),
        ],
      ),
    );
    if (title != null && title.isNotEmpty) {
      await repo.setBookmark(page.id, title);
    }
  }
}

/// Stays in sync with Ctrl+wheel zooming via the canvas controller.
Future<void> _renameDocument(
    BuildContext context, WidgetRef ref, Document document) async {
  final controller = TextEditingController(text: document.title);
  final name = await showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Rename'),
      content: TextField(
        controller: controller,
        autofocus: true,
        textCapitalization: TextCapitalization.sentences,
        onSubmitted: (v) => Navigator.pop(context, v.trim()),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel')),
        FilledButton(
          onPressed: () => Navigator.pop(context, controller.text.trim()),
          child: const Text('Save'),
        ),
      ],
    ),
  );
  if (name != null && name.isNotEmpty) {
    await ref.read(libraryRepositoryProvider).rename(document.id, name);
  }
}
