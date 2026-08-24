import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
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
import '../library/document_transfer.dart';
import '../library/open_document.dart';
import '../library/providers.dart';
import 'canvas/continuous_canvas.dart';
import 'pages/page_background_service.dart';
import 'providers.dart';
import 'widgets/editor_prepare_overlay.dart';
import 'widgets/editor_sidebar.dart';
import 'widgets/editor_top_bar.dart';
import 'search/document_search_panel.dart';
import 'quiz/quiz_flow.dart';
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
    final pageCount =
        ref.watch(documentPageCountProvider(documentId)).asData?.value;
    final doc = docAsync.asData?.value;
    final transfer = documentTransferState(
      documentId: documentId,
      pendingUpload:
          ref.watch(pendingUploadDocumentsProvider).asData?.value ?? const {},
      missingLocal:
          ref.watch(missingLocalFileDocumentsProvider).asData?.value ??
              const {},
      status: ref.watch(syncStatusProvider),
      paused: ref.watch(syncPausedProvider),
      documentType: doc?.type ?? DocumentType.notebook,
      pageCount: pageCount,
      hasCoverPreview: (doc?.coverThumb ?? '').isNotEmpty,
    );
    if (transfer.locked) {
      return DocumentTransferGate(
        key: ValueKey(documentId),
        documentId: documentId,
        transfer: transfer,
      );
    }

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

  /// Explicit jumps (outline, find, quiz, page field) so Back can return.
  final List<int> _pageHistory = [];
  var _restoringPage = false;

  /// Blocks the canvas until the file is local and the first pages are
  /// rendered — scrolling a half-loaded textbook is what causes the lag.
  bool _preparing = true;
  String _prepareLabel = 'Opening…';
  double _prepareFraction = 0;

  @override
  void initState() {
    super.initState();
    _canvasController.onJumpToPage = _recordPageJump;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref
          .read(editorControllerProvider(widget.document.id).notifier)
          .resetDefaultTool();
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
    _setPrepare('Opening…', 0.08);
    final engine = ref.read(syncEngineProvider);
    if (engine != null) {
      await engine.ensureDocumentContent(widget.document.id);
    }
    if (!mounted) return;
    if (widget.document.type == DocumentType.pdf) {
      unawaited(
        ref
            .read(documentTextServiceProvider)
            .ensureOutline(widget.document.id),
      );
    }

    if (!needsFile) {
      _finishPrepare();
      return;
    }

    final assetIds = <String>{
      for (final p in pages)
        if (p.pdfAssetId != null) p.pdfAssetId!,
    };
    for (final id in assetIds) {
      final assets = ref.read(assetRepositoryProvider);
      if (await assets.hasBytes(id)) continue;
      if (!mounted) return;

      // The cloud holds the file, so this device fetches it rather than asking
      // for it back. ensureDocumentContent has already tried, so arriving here
      // with a remote copy on record means the download has not finished —
      // almost always because there is no connection.
      final record = await assets.get(id);
      if (!mounted) return;
      if (record?.remoteKey != null) {
        _setPrepare('Downloading file…', 0.04);
        await _waitForLocalFile();
        if (!mounted) return;
        if (await assets.hasBytes(id)) continue;
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'This PDF is saved to your account but has not finished '
              'downloading. Check your connection and try again.',
            ),
            duration: Duration(seconds: 6),
          ),
        );
        _leaveDocument();
        return;
      }

      // No copy in the cloud: it was imported before file sync reached it, or
      // the device that imported it has not managed to upload yet. Only then
      // is the original file worth asking for.
      final attached = await _attachMissingFile(id);
      if (!attached) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'This PDF has not reached your account yet. Open it on the '
                'device you imported it on to finish uploading, or choose the '
                'original file here.',
              ),
              duration: Duration(seconds: 6),
            ),
          );
        }
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

  Future<void> _waitForLocalFile() async {
    while (mounted) {
      final missing =
          ref.read(missingLocalFileDocumentsProvider).value ?? const {};
      if (!missing.containsKey(widget.document.id)) return;

      final status = ref.read(syncStatusProvider);
      final transfer = documentTransferState(
        documentId: widget.document.id,
        pendingUpload:
            ref.read(pendingUploadDocumentsProvider).value ?? const {},
        missingLocal: missing,
        status: status,
        paused: ref.read(syncPausedProvider),
        documentType: widget.document.type,
        pageCount: ref
            .read(documentPageCountProvider(widget.document.id))
            .asData
            ?.value,
        hasCoverPreview: (widget.document.coverThumb ?? '').isNotEmpty,
      );
      final pct = transfer.percent(status);
      final progress = transfer.progressFraction(status);
      final label = switch (transfer.kind) {
        DocumentTransferKind.syncingPages =>
          pct != null ? 'Syncing pages… $pct%' : 'Syncing pages…',
        _ => pct != null ? 'Downloading file… $pct%' : 'Downloading file…',
      };
      _setPrepare(
        label,
        progress != null ? 0.04 + progress * 0.06 : 0.04,
      );
      await Future<void>.delayed(const Duration(milliseconds: 250));
    }
  }

  /// Lets this device supply the original PDF when sync only brought metadata.
  Future<bool> _attachMissingFile(String assetId) async {
    final go = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final t = ctx.tokens;
        return AlertDialog(
          title: const Text('PDF isn’t on this device'),
          content: const Text(
            'The notes synced, but the source file did not. '
            'Choose the original PDF to render these pages.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text('Later', style: TextStyle(color: t.textMuted)),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Choose file'),
            ),
          ],
        );
      },
    );
    if (go != true || !mounted) return false;

    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['pdf'],
      withData: kIsWeb,
    );
    if (result == null || result.files.isEmpty || !mounted) return false;
    final file = result.files.first;
    final assets = ref.read(assetRepositoryProvider);
    try {
      if (!kIsWeb && file.path != null) {
        await assets.replaceFromFile(
          id: assetId,
          sourcePath: file.path!,
          kind: 1,
          filename: file.name,
          mime: 'application/pdf',
        );
      } else {
        final bytes = file.bytes;
        if (bytes == null) return false;
        await assets.replaceBytes(
          id: assetId,
          bytes: Uint8List.fromList(bytes),
          kind: 1,
          filename: file.name,
          mime: 'application/pdf',
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Couldn’t attach the file: $e')),
        );
      }
      return false;
    }
    ref.read(pageBackgroundServiceProvider).forgetAsset(assetId);
    return true;
  }

  void _finishPrepare() {
    if (!mounted) return;
    setState(() {
      _preparing = false;
      _bgEpoch++;
    });
    // Find-in-document builds its own index when opened. Starting it here
    // on a multi-thousand-page PDF fights the UI right after first paint.
    // Bookmarks are cheap (catalog objects, not a page loop) so the Outline
    // tab can fill in after this frame.
    if (widget.document.type == DocumentType.pdf &&
        widget.document.outline == null) {
      unawaited(
        ref.read(documentTextServiceProvider).ensureOutline(widget.document.id),
      );
    }
  }

  @override
  void dispose() {
    _canvasController.onJumpToPage = null;
    _canvasController.dispose();
    _shortcutFocus.dispose();
    super.dispose();
  }

  void _recordPageJump(int index) {
    if (_restoringPage) return;
    final from =
        ref.read(editorControllerProvider(widget.document.id)).currentIndex;
    if (from == index) return;
    _pageHistory.add(from);
    if (_pageHistory.length > 50) _pageHistory.removeAt(0);
  }

  bool _usesOverlaySidebar(Size screenSize) {
    final chrome = EditorBarLayout.chromeForSize(screenSize);
    final wideScreen = screenSize.width >= AppBreakpoints.editorSidebar;
    final tabletPortrait =
        screenSize.shortestSide >= AppBreakpoints.tabletShortest &&
            screenSize.height > screenSize.width &&
            screenSize.width < AppBreakpoints.desktop;
    return chrome == EditorBarLayout.phone || tabletPortrait || !wideScreen;
  }

  bool _isSidebarOpen(Size screenSize) {
    if (_sidebarOpen != null) return _sidebarOpen!;
    final tablet = screenSize.shortestSide >= AppBreakpoints.tabletShortest;
    final tabletPortrait =
        screenSize.shortestSide >= AppBreakpoints.tabletShortest &&
            screenSize.height > screenSize.width &&
            screenSize.width < AppBreakpoints.desktop;
    final wideScreen = screenSize.width >= AppBreakpoints.editorSidebar;
    return tablet || (wideScreen && !tabletPortrait);
  }

  bool _overlayDrawerOpen() {
    final size = MediaQuery.sizeOf(context);
    return _isSidebarOpen(size) && _usesOverlaySidebar(size);
  }

  bool _canHandleBackLocally() {
    if (_searchOpen || _editingElementId != null || _readingMode) {
      return true;
    }
    if (_overlayDrawerOpen()) {
      return true;
    }
    final state = ref.read(editorControllerProvider(widget.document.id));
    if (state.selection != null || state.selectedElementId != null) {
      return true;
    }
    return _pageHistory.isNotEmpty;
  }

  /// Toolbar ← restores the last page jumped to (thumbnail, outline, find,
  /// page field). It does not undo ink, dismiss the sidebar, or clear a
  /// selection — those are activities, not navigation.
  void _handleToolbarBack() {
    if (_pageHistory.isNotEmpty) {
      final index = _pageHistory.removeLast();
      _restoringPage = true;
      _canvasController.jumpToPage(index);
      _restoringPage = false;
      return;
    }
    _leaveDocument();
  }

  /// Unwinds the last overlay, page jump, or route — same as the system back.
  void _handleBack() {
    if (_searchOpen) {
      setState(() => _searchOpen = false);
      return;
    }
    if (_editingElementId != null) {
      _endEditElement();
      return;
    }
    final controller =
        ref.read(editorControllerProvider(widget.document.id).notifier);
    final state = ref.read(editorControllerProvider(widget.document.id));
    if (state.selection != null || state.selectedElementId != null) {
      controller.clearSelection();
      controller.selectElement(null);
      return;
    }
    if (_readingMode) {
      setState(() => _readingMode = false);
      return;
    }
    if (_overlayDrawerOpen()) {
      setState(() => _sidebarOpen = false);
      return;
    }
    if (_pageHistory.isNotEmpty) {
      final index = _pageHistory.removeLast();
      _restoringPage = true;
      _canvasController.jumpToPage(index);
      _restoringPage = false;
      return;
    }
    _leaveDocument();
  }

  void _leaveDocument() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/');
    }
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
    // iPhone + portrait iPad (and Android tablets) share phone dock chrome.
    final chrome = EditorBarLayout.chromeForSize(screenSize);
    final tabletPortrait =
        screenSize.shortestSide >= AppBreakpoints.tabletShortest &&
        screenSize.height > screenSize.width &&
        screenSize.width < AppBreakpoints.desktop;
    final tablet =
        screenSize.shortestSide >= AppBreakpoints.tabletShortest;
    // Phones and portrait tablets overlay the Edge-style pages/outline
    // drawer so it doesn't crush the canvas. Landscape tablets/desktop keep
    // the persistent rail.
    final overlaySidebar =
        chrome == EditorBarLayout.phone || tabletPortrait || !wideScreen;
    final drawerWidth = (screenSize.width * 0.86).clamp(240.0, 320.0);
    // Default open on tablet/desktop; phones start closed so the PDF is full
    // width until the user taps Pages & outline.
    final sidebarOpen = _sidebarOpen ?? (tablet || (wideScreen && !tabletPortrait));
    final subtitle = state.pages.isEmpty
        ? 'No pages'
        : 'Page ${state.currentIndex + 1} of ${state.pages.length}';

    return PopScope(
      canPop: !_canHandleBackLocally(),
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _handleBack();
      },
      child: Stack(
      children: [
        Focus(
          focusNode: _shortcutFocus,
      autofocus: true,
      onKeyEvent: _onShortcut,
      child: Scaffold(
        backgroundColor: context.tokens.canvas,
        appBar: _readingMode && chrome == EditorBarLayout.phone
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
                layout: chrome,
                onFind: () => setState(() => _searchOpen = !_searchOpen),
                onQuiz: () => QuizFlow.open(
                  context,
                  documentId: documentId,
                  title: widget.document.title,
                  pageCount: state.pages.length,
                  onJumpToPage: _canvasController.jumpToPage,
                ),
                onBack: _handleToolbarBack,
                readingMode: _readingMode,
                onToggleReadingMode: chrome == EditorBarLayout.phone
                    ? () {
                        controller.setTool(ToolType.hand);
                        setState(() => _readingMode = !_readingMode);
                      }
                    : null,
              ),
        // iPhone, Android phones, and portrait iPad/tablets — thumb-reach dock.
        bottomNavigationBar: _preparing ||
                !chrome.showsBottomDock ||
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
                      if (sidebarOpen && !overlaySidebar)
                        _pagesOutlineSidebar(
                          width: 240,
                          closeOnJump: false,
                        ),
                      Expanded(
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
                            twoPageSpread: false,
                            onScrollSettled: () => ref
                                .read(pageBackgroundServiceProvider)
                                .notifyScrollSettled(),
                          ),
                      ),
                    ],
                  ),
                  if (sidebarOpen && overlaySidebar)
                    Positioned.fill(
                      child: _PagesOutlineDrawer(
                        width: drawerWidth,
                        onDismiss: () =>
                            setState(() => _sidebarOpen = false),
                        child: _pagesOutlineSidebar(
                          width: drawerWidth,
                          closeOnJump: true,
                        ),
                      ),
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
                  // visible as a precise and accessible alternative. Keep it
                  // clear of the colour strip above the phone/iPad tool dock.
                  if (!_readingMode)
                    Positioned(
                      right: chrome.showsBottomDock ? 12 : 24,
                      bottom: chrome.showsBottomDock
                          ? (state.isDrawingTool ? 72 : 12)
                          : 24,
                      child: ZoomCluster(controller: _canvasController),
                    ),
                  if (_searchOpen)
                    Positioned(
                      top: 12,
                      left: chrome.showsBottomDock ? 12 : null,
                      right: 16,
                      child: DocumentSearchPanel(
                        documentId: documentId,
                        onJumpToPage: _canvasController.jumpToPage,
                        onClose: () => setState(() => _searchOpen = false),
                      ),
                    ),
                  if (_readingMode)
                    Positioned(
                      right: 18,
                      bottom: 30,
                      child: SafeArea(
                        top: false,
                        child: Material(
                          color: context.tokens.accent,
                          borderRadius: BorderRadius.circular(16),
                          elevation: 0,
                          child: InkWell(
                            onTap: () =>
                                setState(() => _readingMode = false),
                            borderRadius: BorderRadius.circular(16),
                            child: Container(
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: [
                                  BoxShadow(
                                    color: context.tokens.accent.withValues(
                                      alpha: 0.55,
                                    ),
                                    blurRadius: 30,
                                    offset: const Offset(0, 14),
                                    spreadRadius: -10,
                                  ),
                                ],
                              ),
                              child: const Icon(
                                Icons.edit_rounded,
                                color: Colors.white,
                                size: 24,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  if (_readingMode && state.pages.isNotEmpty)
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      child: ColoredBox(
                        color: context.tokens.fill,
                        child: SizedBox(
                          height: 3,
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: FractionallySizedBox(
                              widthFactor: (state.currentIndex + 1) /
                                  state.pages.length,
                              child: ColoredBox(
                                color: context.tokens.accent,
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
              onClose: _leaveDocument,
            ),
          ),
      ],
    ),
    );
  }

  Widget _pagesOutlineSidebar({
    required double width,
    required bool closeOnJump,
  }) {
    final doc =
        ref.watch(documentStreamProvider(widget.document.id)).asData?.value ??
            widget.document;
    final state = ref.watch(editorControllerProvider(widget.document.id));
    return EditorSidebar(
      documentId: widget.document.id,
      pages: state.pages,
      currentIndex: state.currentIndex,
      defaultPageSize: _defaultPageSize,
      width: width,
      onJumpToPage: (index) {
        _canvasController.jumpToPage(index);
        if (closeOnJump) setState(() => _sidebarOpen = false);
      },
      outline: OutlineEntry.decode(doc.outline),
      outlinePending:
          doc.type == DocumentType.pdf && doc.outline == null,
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
                    onTap: () => tryOpenDocument(
                      context,
                      doc,
                      container: ProviderScope.containerOf(context),
                      replace: true,
                    ),
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
    final pendingUpload =
        ref.watch(pendingUploadDocumentsProvider).asData?.value ?? const {};
    final missingLocal =
        ref.watch(missingLocalFileDocumentsProvider).asData?.value ?? const {};
    final paused = ref.watch(syncPausedProvider);
    final status = ref.watch(syncStatusProvider);
    final count = ref
        .watch(documentPageCountProvider(document.id))
        .asData
        ?.value;
    final transfer = documentTransferState(
      documentId: document.id,
      pendingUpload: pendingUpload,
      missingLocal: missingLocal,
      status: status,
      paused: paused,
      documentType: document.type,
      pageCount: count,
      hasCoverPreview: (document.coverThumb ?? '').isNotEmpty,
    );
    final locked = transfer.locked;
    final badgeLabel = transfer.listBadgeLabel(status);
    return Opacity(
      opacity: locked ? 0.45 : 1,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Material(
          color: selected ? t.accentSoft : Colors.transparent,
          borderRadius: BorderRadius.circular(Radii.control),
          child: ListTile(
            dense: true,
            enabled: !locked,
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
                locked
                    ? switch (transfer.kind) {
                        DocumentTransferKind.downloading =>
                          Icons.cloud_download_outlined,
                        DocumentTransferKind.uploading =>
                          Icons.cloud_upload_outlined,
                        DocumentTransferKind.syncingPages =>
                          Icons.cloud_sync_outlined,
                        DocumentTransferKind.none => Icons.cloud_outlined,
                      }
                    : document.type == DocumentType.pdf
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
              badgeLabel ??
                  (count == null ? 'Document' : '$count pp'),
              style: AppTokens.mono(size: 10, color: t.textFaint),
            ),
            onTap: locked ? null : onTap,
          ),
        ),
      ),
    );
  }
}

/// Edge-style pages/outline drawer: the panel on the left, tap the dimmed
/// remainder to close. Used on phones and portrait tablets where an inline
/// rail would leave no room for the page.
class _PagesOutlineDrawer extends StatelessWidget {
  const _PagesOutlineDrawer({
    required this.width,
    required this.onDismiss,
    required this.child,
  });

  final double width;
  final VoidCallback onDismiss;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Material(
          color: t.surfaceAlt,
          elevation: 12,
          shadowColor: t.shadow,
          child: SizedBox(width: width, child: child),
        ),
        Expanded(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onDismiss,
            child: ColoredBox(
              color: t.shadow.withValues(alpha: 0.28),
            ),
          ),
        ),
      ],
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
