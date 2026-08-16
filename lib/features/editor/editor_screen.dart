import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/design.dart';
import '../../core/db/database.dart';
import '../../core/models/enums.dart';
import '../../core/models/outline_entry.dart';
import '../../core/models/page_geometry.dart';
import '../../core/sync/sync_providers.dart';
import '../library/providers.dart';
import 'canvas/continuous_canvas.dart';
import 'pages/page_background_service.dart';
import 'providers.dart';
import 'widgets/editor_prepare_overlay.dart';
import 'widgets/editor_sidebar.dart';
import 'widgets/editor_top_bar.dart';
import 'search/document_search_panel.dart';
import 'widgets/element_actions.dart';
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
          return const Scaffold(
            body: Center(child: Text('Notebook not found')),
          );
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

  /// Pages already offered the file picker on picking the Image tool, so a
  /// cancelled pick doesn't reopen the dialog every time the tool is chosen.
  final _autoImagePrompted = <String>{};

  /// Guards against a second picker while one is already open.
  bool _pickingImage = false;

  /// Text/sticky element currently open for Canva-style inline typing, if any.
  String? _editingElementId;

  /// Bumped after PDF/image assets are fetched so blank page tiles reload.
  int _bgEpoch = 0;

  /// Mobile immersive reader state; a page tap restores annotation chrome.
  bool _readingMode = false;

  /// Blocks the canvas until the file is local and the first pages are
  /// rendered — scrolling a half-loaded textbook is what causes the lag.
  bool _preparing = true;
  String _prepareLabel = 'Opening…';
  double _prepareFraction = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_prepareDocument());
    });
  }

  Future<void> _waitForPages() async {
    while (mounted) {
      final state = ref.read(editorControllerProvider(widget.document.id));
      if (!state.loading) return;
      await Future<void>.delayed(const Duration(milliseconds: 16));
    }
  }

  void _setPrepare(String label, double fraction) {
    if (!mounted) return;
    setState(() {
      _prepareLabel = label;
      _prepareFraction = fraction;
    });
  }

  Future<void> _prepareDocument() async {
    await _waitForPages();
    if (!mounted) return;

    final pages =
        ref.read(editorControllerProvider(widget.document.id)).pages;
    final needsFile = pages.any(
      (p) => p.pdfAssetId != null || p.bgAssetId != null,
    );
    if (!needsFile) {
      _finishPrepare();
      return;
    }

    _setPrepare('Downloading files…', 0.04);
    final engine = ref.read(syncEngineProvider);
    if (engine != null) {
      await engine.ensureDocumentAssets(widget.document.id);
    }
    if (!mounted) return;

    final assetIds = <String>{
      for (final p in pages)
        if (p.pdfAssetId != null) p.pdfAssetId!,
    };
    for (final id in assetIds) {
      final present = await ref.read(assetRepositoryProvider).hasBytes(id);
      if (!present && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'This document’s PDF isn’t on this device. '
              'Re-import the file, or enable file sync so it can download.',
            ),
            duration: Duration(seconds: 6),
          ),
        );
        _finishPrepare();
        return;
      }
    }

    final bg = ref.read(pageBackgroundServiceProvider);
    final controller = ref.read(
      editorControllerProvider(widget.document.id).notifier,
    );
    NotePage? first;
    for (final page in pages) {
      if (bg.hasBackground(page)) {
        first = page;
        break;
      }
    }
    if (first == null) {
      _finishPrepare();
      return;
    }

    _setPrepare('Rendering page…', 0.1);
    await bg.warmPages(
      [first],
      onProgress: (step, count) {
        _setPrepare(
          'Rendering page…',
          0.1 + 0.85 * (step / count),
        );
      },
    );
    if (!mounted) return;
    await controller.ensurePageLoaded(first.id);
    if (!mounted) return;
    final ahead = [
      for (final page in pages.take(PageBackgroundService.prepareWindow))
        if (page.id != first.id && bg.hasBackground(page)) page,
    ];
    if (ahead.isNotEmpty) bg.prefetchAll(ahead);
    _setPrepare('Ready', 1);
    _finishPrepare();
  }

  void _finishPrepare() {
    if (!mounted) return;
    setState(() {
      _preparing = false;
      _bgEpoch++;
    });
    // Find-in-document builds its own index when opened. Starting it here
    // on a multi-thousand-page PDF fights the UI right after first paint.
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
    final controller = ref.read(
      editorControllerProvider(widget.document.id).notifier,
    );

    // Escape closes search first, then ends inline text edit, then selection.
    if (event.logicalKey == LogicalKeyboardKey.escape) {
      if (_searchOpen) {
        setState(() => _searchOpen = false);
        return KeyEventResult.handled;
      }
      if (_editingElementId != null) {
        _endEditElement();
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

    ref.listen(editorControllerProvider(documentId).select((s) => s.tool), (
      prev,
      next,
    ) {
      if (next == ToolType.image && prev != ToolType.image) {
        unawaited(_autoPickImage(documentId));
      }
    });

    final state = ref.watch(editorControllerProvider(documentId));
    final controller = ref.read(editorControllerProvider(documentId).notifier);
    final page = state.currentPage;

    final screenSize = MediaQuery.sizeOf(context);
    final wideScreen = screenSize.width >= AppBreakpoints.editorSidebar;
    final layout = EditorBarLayout.forSize(screenSize);
    final tabletPortrait =
        screenSize.shortestSide >= AppBreakpoints.tabletShortest &&
        screenSize.height > screenSize.width &&
        screenSize.width < AppBreakpoints.desktop;
    // Default open on tablets/desktop, closed on phones; the user's explicit
    // toggle wins once they've set it.
    final sidebarOpen = _sidebarOpen ?? (wideScreen && !tabletPortrait);
    final spreadStart = (state.currentIndex ~/ 2) * 2;
    final spreadEnd = spreadStart + 2 > state.pages.length
        ? state.pages.length
        : spreadStart + 2;
    final subtitle = state.pages.isEmpty
        ? 'No pages'
        : layout.showsSideRail
        ? 'Spread ${spreadStart ~/ 2 + 1} · pages '
              '${spreadStart + 1}–$spreadEnd'
        : 'Page ${state.currentIndex + 1} of ${state.pages.length}';

    return Stack(
      children: [
        Focus(
          focusNode: _shortcutFocus,
      autofocus: true,
      onKeyEvent: _onShortcut,
      child: Scaffold(
        backgroundColor: context.tokens.canvas,
        appBar: _readingMode && layout == EditorBarLayout.phone
            ? null
            : EditorTopBar(
                documentId: documentId,
                title: widget.document.title,
                subtitle: subtitle,
                sidebarOpen: sidebarOpen,
                onToggleSidebar: () =>
                    setState(() => _sidebarOpen = !sidebarOpen),
                currentIndex: state.currentIndex,
                pageCount: state.pages.length,
                canvasController: _canvasController,
                pageSizeFor: _sizeFor,
                onRename: () => _renameDocument(context, ref, widget.document),
                onToggleBookmark: page == null
                    ? () {}
                    : () => _toggleBookmark(context, page),
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
                readingMode: _readingMode,
                onToggleReadingMode: layout == EditorBarLayout.phone
                    ? () {
                        controller.setTool(ToolType.hand);
                        setState(() => _readingMode = !_readingMode);
                      }
                    : null,
              ),
        // On a phone the tools live at the bottom, within thumb reach.
        bottomNavigationBar: _preparing ||
                !layout.showsBottomDock ||
                state.pages.isEmpty ||
                _readingMode
            ? null
            : EditorToolDock(documentId: documentId, pageSizeFor: _sizeFor),
        body: state.loading || _preparing
            ? const SizedBox.expand()
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
                      if (tabletPortrait)
                        _TabletLibraryPane(currentDocumentId: documentId),
                      if (layout.showsSideRail)
                        EditorToolRail(
                          documentId: documentId,
                          pageSizeFor: _sizeFor,
                        ),
                      if (sidebarOpen)
                        EditorSidebar(
                          documentId: documentId,
                          pages: state.pages,
                          currentIndex: state.currentIndex,
                          defaultPageSize: _defaultPageSize,
                          onJumpToPage: _canvasController.jumpToPage,
                          outline: OutlineEntry.decode(widget.document.outline),
                        ),
                      Expanded(
                        child: Listener(
                          onPointerDown: (_) {
                            if (_readingMode) {
                              setState(() => _readingMode = false);
                            }
                          },
                          child: ContinuousCanvas(
                            key: ValueKey('canvas-$_bgEpoch'),
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
                            backgroundLoader: (p, scale) => ref
                                .read(pageBackgroundServiceProvider)
                                .load(p, viewScale: scale),
                            cachedBackground: (p) => ref
                                .read(pageBackgroundServiceProvider)
                                .cachedOrThumb(p),
                            thumbnailLoader: (p) => ref
                                .read(pageBackgroundServiceProvider)
                                .loadThumbnail(p),
                            prefetch: (pages) => ref
                                .read(pageBackgroundServiceProvider)
                                .prefetch(pages),
                            selection: state.selection,
                            onLassoComplete: controller.selectWithLasso,
                            onSelectionDrag: controller.dragSelection,
                            onSelectionDragEnd: controller.commitSelectionMove,
                            onClearSelection: controller.clearSelection,
                            elementsFor: (pageId) =>
                                ref
                                    .read(pageElementsProvider(pageId))
                                    .asData
                                    ?.value ??
                                const [],
                            imageBytesFor: (assetId) => ref
                                .read(elementRepositoryProvider)
                                .imageBytes(assetId),
                            selectedElementId: state.selectedElementId,
                            onSelectElement: (id) {
                              if (id == null || id != _editingElementId) {
                                _endEditElement();
                              }
                              controller.selectElement(id);
                            },
                            onElementRotate: (id, angle, committed) {
                              if (!committed) return;
                              ref
                                  .read(elementRepositoryProvider)
                                  .updateTransform(id, rotation: angle);
                            },
                            onElementTransform:
                                (id, rect, committed, {pageId}) {
                                  if (!committed) return;
                                  ref
                                      .read(elementRepositoryProvider)
                                      .updateTransform(
                                        id,
                                        x: rect.left,
                                        y: rect.top,
                                        width: rect.width,
                                        height: rect.height,
                                        pageId: pageId,
                                      );
                                },
                            onCreateElement: (pageId, at, sticky) =>
                                _createTextElement(pageId, at, sticky),
                            onEditElement: (id) => _beginEditElement(id),
                            onDeleteElement: (id) => _deleteElement(id),
                            onShiftElementZ: (id, forward) => ref
                                .read(elementRepositoryProvider)
                                .shiftZ(id, forward: forward),
                            editingElementId: _editingElementId,
                            onChangeText: (id, data) => ref
                                .read(elementRepositoryProvider)
                                .updateTextData(id, data),
                            onEndEditText: _endEditElement,
                            palmRejection: ref.watch(palmRejectionProvider),
                            twoPageSpread: layout.showsSideRail,
                            onScrollSettled: () => ref
                                .read(pageBackgroundServiceProvider)
                                .notifyScrollSettled(),
                          ),
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
                  // Pinch works directly on the canvas; the slider remains
                  // visible as a precise and accessible alternative.
                  if (!_readingMode)
                    Positioned(
                      right: layout == EditorBarLayout.phone ? 12 : 24,
                      bottom: layout == EditorBarLayout.phone ? 12 : 24,
                      child: ZoomCluster(controller: _canvasController),
                    ),
                  if (_searchOpen)
                    Positioned(
                      top: 12,
                      left: layout == EditorBarLayout.phone ? 12 : null,
                      right: 16,
                      child: DocumentSearchPanel(
                        documentId: documentId,
                        onJumpToPage: _canvasController.jumpToPage,
                        onClose: () => setState(() => _searchOpen = false),
                      ),
                    ),
                  if (_readingMode && layout == EditorBarLayout.phone)
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 24,
                      child: IgnorePointer(
                        child: Center(
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: context.tokens.surface.withValues(
                                alpha: 0.92,
                              ),
                              borderRadius: BorderRadius.circular(18),
                              boxShadow: AppTokens.elevation(
                                context.tokens.shadow,
                                y: 8,
                                blur: 24,
                              ),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 10,
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.touch_app_rounded,
                                    size: 18,
                                    color: context.tokens.accentText,
                                  ),
                                  const SizedBox(width: 8),
                                  const Text('Tap page to show tools'),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  if (state.tool == ToolType.image ||
                      state.selectedElementId != null)
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 18,
                      child: Center(
                        child: ElementActions(
                          documentId: documentId,
                          pageWidth: page == null ? 600 : _sizeFor(page).width,
                          editingElementId: _editingElementId,
                          onBeginEdit: _beginEditElement,
                          onEndEdit: _endEditElement,
                        ),
                      ),
                    ),
                ],
              ),
      ),
        ),
        if (_preparing)
          Positioned.fill(
            child: EditorPrepareOverlay(
              label: _prepareLabel,
              fraction: _prepareFraction,
              pageCount: state.pages.length,
              onClose: () => context.pop(),
            ),
          ),
      ],
    );
  }

  /// Opens the file picker when the Image tool is chosen on a page that has no
  /// picture yet.
  ///
  /// The tool's other actions (crop, delete, move) need an image to act on, so
  /// until one exists the only useful thing it can do is insert one — and the
  /// toolbar icon gives no hint that "Add image" is waiting at the bottom.
  Future<void> _autoPickImage(String documentId) async {
    if (_pickingImage) return;
    final state = ref.read(editorControllerProvider(documentId));
    final pageId = state.currentPageId;
    if (pageId == null || !_autoImagePrompted.add(pageId)) return;

    final repo = ref.read(elementRepositoryProvider);
    final existing = await repo.getElements(pageId);
    if (existing.any((e) => e.type == ElementType.image) || !mounted) return;

    final page = state.currentPage;
    final pageWidth = page == null ? 600.0 : _sizeFor(page).width;
    _pickingImage = true;
    try {
      final element = await repo.pickAndInsertImage(
        pageId: pageId,
        maxWidth: pageWidth * 0.5,
      );
      if (element != null && mounted) {
        ref
            .read(editorControllerProvider(documentId).notifier)
            .selectElement(element.id);
      }
    } finally {
      _pickingImage = false;
    }
  }

  /// Places a fresh text box / sticky note and opens it for inline editing
  /// right away — Canva-style, no modal. An empty box would otherwise be
  /// invisible until the user starts typing.
  Future<void> _createTextElement(String pageId, Offset at, bool sticky) async {
    final repo = ref.read(elementRepositoryProvider);
    final controller = ref.read(
      editorControllerProvider(widget.document.id).notifier,
    );
    final element = await repo.insertText(
      pageId: pageId,
      at: at,
      sticky: sticky,
    );
    if (!mounted) return;
    controller.selectElement(element.id);
    _beginEditElement(element.id);
  }

  /// Starts Canva-style inline typing on [elementId].
  void _beginEditElement(String elementId) {
    setState(() => _editingElementId = elementId);
    ref
        .read(editorControllerProvider(widget.document.id).notifier)
        .selectElement(elementId);
  }

  /// Leaves the inline text field. Content is already persisted as the user
  /// types via [onChangeText].
  void _endEditElement() {
    if (_editingElementId == null) return;
    setState(() => _editingElementId = null);
  }

  /// Removes an image / sticker / text / sticky element and drops selection.
  Future<void> _deleteElement(String elementId) async {
    if (_editingElementId == elementId) {
      setState(() => _editingElementId = null);
    }
    await ref.read(elementRepositoryProvider).deleteElement(elementId);
    if (!mounted) return;
    ref
        .read(editorControllerProvider(widget.document.id).notifier)
        .selectElement(null);
  }

  Future<void> _toggleBookmark(BuildContext context, NotePage page) async {
    final repo = ref.read(pageRepositoryProvider);
    if (page.bookmarkTitle != null) {
      await repo.setBookmark(page.id, null);
      return;
    }
    final controller = TextEditingController(
      text:
          'Page ${ref.read(editorControllerProvider(widget.document.id)).currentIndex + 1}',
    );
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
            child: const Text('Cancel'),
          ),
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

/// iPad portrait split view: a compact live library beside the open document.
class _TabletLibraryPane extends ConsumerWidget {
  const _TabletLibraryPane({required this.currentDocumentId});

  final String currentDocumentId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    final docs =
        (ref.watch(folderChildrenProvider(null)).asData?.value ??
                const <Document>[])
            .where((doc) => doc.type != DocumentType.folder)
            .toList();

    return Container(
      width: 276,
      decoration: BoxDecoration(
        color: t.surfaceAlt,
        border: Border(right: BorderSide(color: t.line)),
      ),
      child: SafeArea(
        right: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 14, 8, 10),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Library',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: t.text,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Open full library',
                    onPressed: () => context.go('/'),
                    icon: const Icon(Icons.open_in_full_rounded, size: 19),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Container(
                height: 36,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: t.fill,
                  borderRadius: BorderRadius.circular(Radii.control),
                ),
                child: Row(
                  children: [
                    Icon(Icons.search_rounded, size: 18, color: t.textMuted),
                    const SizedBox(width: 8),
                    Text(
                      'Recent documents',
                      style: TextStyle(fontSize: 13, color: t.textMuted),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                itemCount: docs.length,
                itemBuilder: (context, index) {
                  final doc = docs[index];
                  return _TabletDocumentRow(
                    document: doc,
                    selected: doc.id == currentDocumentId,
                    onTap: () => context.go('/doc/${doc.id}'),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TabletDocumentRow extends ConsumerWidget {
  const _TabletDocumentRow({
    required this.document,
    required this.selected,
    required this.onTap,
  });

  final Document document;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    final count = ref
        .watch(documentPageCountProvider(document.id))
        .asData
        ?.value;
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Material(
        color: selected ? t.accentSoft : Colors.transparent,
        borderRadius: BorderRadius.circular(Radii.control),
        child: ListTile(
          dense: true,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(Radii.control),
          ),
          leading: Container(
            width: 36,
            height: 44,
            decoration: BoxDecoration(
              color: document.type == DocumentType.pdf
                  ? t.pdfBadge.withValues(alpha: 0.12)
                  : t.accentSoft,
              borderRadius: BorderRadius.circular(7),
              border: Border.all(color: t.line),
            ),
            child: Icon(
              document.type == DocumentType.pdf
                  ? Icons.picture_as_pdf_rounded
                  : Icons.description_outlined,
              size: 18,
              color: document.type == DocumentType.pdf
                  ? t.pdfBadge
                  : t.accentText,
            ),
          ),
          title: Text(
            document.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
              color: t.text,
            ),
          ),
          subtitle: Text(
            count == null ? 'Document' : '$count pp',
            style: AppTokens.mono(size: 10, color: t.textFaint),
          ),
          onTap: onTap,
        ),
      ),
    );
  }
}

/// Stays in sync with Ctrl+wheel zooming via the canvas controller.
Future<void> _renameDocument(
  BuildContext context,
  WidgetRef ref,
  Document document,
) async {
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
          child: const Text('Cancel'),
        ),
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
