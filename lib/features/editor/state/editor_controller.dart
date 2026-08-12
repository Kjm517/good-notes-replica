import 'dart:ui' show Offset;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../app/providers.dart';
import '../../../core/sync/sync_providers.dart';
import '../../../core/db/database.dart';
import '../../../core/ink/ink_stroke.dart';
import '../../../core/models/enums.dart';
import '../../../core/models/margin_spec.dart';
import '../data/page_repository.dart';
import '../data/stroke_repository.dart';
import '../providers.dart';
import 'editor_state.dart';
import 'lasso_selection.dart';
import 'tool_settings.dart';

/// One undoable ink edit on a specific page: strokes added or removed.
class _Edit {
  _Edit.add(this.pageId, this.strokes) : isAdd = true;
  _Edit.remove(this.pageId, this.strokes) : isAdd = false;
  final String pageId;
  final bool isAdd;
  final List<InkStroke> strokes;
}

/// Stateful editor for a single document. Holds strokes for the pages loaded
/// so far (pages load lazily as they scroll into view), persists every edit,
/// and keeps a document-wide undo/redo history.
class EditorController extends FamilyNotifier<EditorState, String> {
  late final PageRepository _pages;
  late final StrokeRepository _strokes;
  late final Uuid _uuid;

  final List<_Edit> _undo = [];
  final List<_Edit> _redo = [];
  final Map<String, int> _seqByPage = {};
  final Set<String> _loading = {};

  @override
  EditorState build(String documentId) {
    _pages = ref.read(pageRepositoryProvider);
    _strokes = ref.read(strokeRepositoryProvider);
    _uuid = ref.read(uuidProvider);
    _bootstrap(documentId);
    return EditorState(toolSettings: defaultToolSettings());
  }

  Future<void> _bootstrap(String documentId) async {
    final pages = await _pages.getPages(documentId);
    state = state.copyWith(pages: pages, currentIndex: 0, loading: false);
    if (pages.isNotEmpty) await ensurePageLoaded(pages.first.id);
  }

  /// Loads a page's strokes if they aren't in memory yet. Safe to call often
  /// (e.g. as pages scroll into view).
  Future<void> ensurePageLoaded(String pageId) async {
    if (state.strokesByPage.containsKey(pageId) || _loading.contains(pageId)) {
      return;
    }
    _loading.add(pageId);
    try {
      final strokes = await _strokes.getStrokes(pageId);
      _seqByPage[pageId] =
          strokes.fold<int>(0, (m, s) => s.seq > m ? s.seq : m);
      state = state.copyWith(
        strokesByPage: {...state.strokesByPage, pageId: strokes},
      );
    } finally {
      _loading.remove(pageId);
    }
  }

  /// Called when the pages list changes (add/delete/reorder).
  void onPagesChanged(List<NotePage> pages) {
    final idx = pages.isEmpty
        ? 0
        : state.currentIndex.clamp(0, pages.length - 1);
    state = state.copyWith(pages: pages, currentIndex: idx);
  }

  /// Updates which page is considered "current" (drives page settings/margins).
  void setCurrentIndex(int index) {
    if (index < 0 || index >= state.pages.length) return;
    if (index == state.currentIndex) return;
    state = state.copyWith(currentIndex: index);
  }

  // ---- Tool state ----------------------------------------------------------

  void setTool(ToolType tool) {
    if (tool == state.tool) return;
    // Leaving a tool abandons whatever it had selected, so a stale lasso box
    // or image handle can't linger over an unrelated tool.
    state = state.copyWith(
      tool: tool,
      clearSelection: true,
      clearElementSelection: true,
    );
  }

  void setEraserMode(EraserMode mode) =>
      state = state.copyWith(eraserMode: mode, tool: ToolType.eraser);

  void setColor(int color) {
    final settings = {...state.toolSettings};
    final current = settings[state.tool];
    if (current == null) return;
    settings[state.tool] = current.copyWith(color: color);
    state = state.copyWith(toolSettings: settings);
  }

  void setWidth(double width) {
    final settings = {...state.toolSettings};
    final current = settings[state.tool];
    if (current == null) return;
    settings[state.tool] = current.copyWith(width: width);
    state = state.copyWith(toolSettings: settings);
  }

  void setViewMode(PageViewMode mode) => state = state.copyWith(viewMode: mode);

  void setStrokeStyle(StrokeStyle style) {
    final settings = {...state.toolSettings};
    final current = settings[state.tool];
    if (current == null) return;
    settings[state.tool] = current.copyWith(style: style);
    state = state.copyWith(toolSettings: settings);
  }

  void setStrokeTip(StrokeTip tip) {
    final settings = {...state.toolSettings};
    final current = settings[state.tool];
    if (current == null) return;
    settings[state.tool] = current.copyWith(tip: tip);
    state = state.copyWith(toolSettings: settings);
  }

  void setShapeOptions(ShapeOptions options) =>
      state = state.copyWith(shapeOptions: options);

  void setLassoOptions(LassoOptions options) =>
      state = state.copyWith(lassoOptions: options);

  void selectElement(String? id) => state = id == null
      ? state.copyWith(clearElementSelection: true)
      : state.copyWith(selectedElementId: id);

  // ---- Ink edits -----------------------------------------------------------

  Future<void> commitStroke(String pageId, InkStroke stroke) async {
    if (stroke.points.isEmpty) return;
    final seq = (_seqByPage[pageId] ?? 0) + 1;
    _seqByPage[pageId] = seq;
    final s = stroke.copyWith(id: _uuid.v4(), seq: seq);
    _setStrokes(pageId, [...state.strokesFor(pageId), s]);
    _pushUndo(_Edit.add(pageId, [s]));
    await _strokes.insertStroke(pageId, s);
  }

  Future<void> eraseStrokes(String pageId, Set<String> ids) async {
    if (ids.isEmpty) return;
    final current = state.strokesFor(pageId);
    final removed =
        current.where((s) => ids.contains(s.id)).toList(growable: false);
    if (removed.isEmpty) return;
    _setStrokes(pageId, current.where((s) => !ids.contains(s.id)).toList());
    _pushUndo(_Edit.remove(pageId, removed));
    await _strokes.deleteStrokes(ids);
  }

  Future<void> undo() async {
    if (_undo.isEmpty) return;
    final e = _undo.removeLast();
    e.isAdd ? await _delete(e) : await _insert(e);
    _redo.add(e);
    _refreshHistoryFlags();
  }

  Future<void> redo() async {
    if (_redo.isEmpty) return;
    final e = _redo.removeLast();
    e.isAdd ? await _insert(e) : await _delete(e);
    _undo.add(e);
    _refreshHistoryFlags();
  }

  Future<void> _insert(_Edit e) async {
    final merged = [...state.strokesFor(e.pageId), ...e.strokes]
      ..sort((a, b) => a.seq.compareTo(b.seq));
    _setStrokes(e.pageId, merged);
    for (final s in e.strokes) {
      await _strokes.insertStroke(e.pageId, s);
    }
  }

  Future<void> _delete(_Edit e) async {
    final ids = e.strokes.map((s) => s.id).toSet();
    _setStrokes(
      e.pageId,
      state.strokesFor(e.pageId).where((s) => !ids.contains(s.id)).toList(),
    );
    await _strokes.deleteStrokes(ids);
  }

  void _setStrokes(String pageId, List<InkStroke> strokes) {
    state = state.copyWith(
      strokesByPage: {...state.strokesByPage, pageId: strokes},
    );
  }

  void _pushUndo(_Edit e) {
    _undo.add(e);
    _redo.clear();
    _refreshHistoryFlags();
    _requestSync();
  }

  /// Nudges the sync engine after an edit. Debounced inside the engine, so a
  /// burst of strokes results in a single upload.
  void _requestSync() => ref.read(syncEngineProvider)?.scheduleSync();

  void _refreshHistoryFlags() => state =
      state.copyWith(canUndo: _undo.isNotEmpty, canRedo: _redo.isNotEmpty);

  // ---- Lasso selection -----------------------------------------------------

  /// Builds a selection from a finished lasso outline.
  void selectWithLasso(String pageId, List<Offset> lasso) {
    final options = state.lassoOptions;
    final selection = LassoSelection.fromLasso(
      pageId: pageId,
      lasso: lasso,
      // Honour the "Included in Selection" filters.
      strokes: state
          .strokesFor(pageId)
          .where((s) => options.includes(s.tool))
          .toList(),
    );
    state = selection == null
        ? state.copyWith(clearSelection: true)
        : state.copyWith(selection: selection);
  }

  void clearSelection() => state = state.copyWith(clearSelection: true);

  /// Live drag of the selection (in-memory until [commitSelectionMove]).
  void dragSelection(Offset offset) {
    final sel = state.selection;
    if (sel == null) return;
    state = state.copyWith(selection: sel.copyWith(offset: offset));
  }

  /// Writes the dragged position into the strokes themselves.
  Future<void> commitSelectionMove() async {
    final sel = state.selection;
    if (sel == null || sel.offset == Offset.zero) return;
    final dx = sel.offset.dx, dy = sel.offset.dy;
    final current = state.strokesFor(sel.pageId);
    final moved = <InkStroke>[];
    final updated = [
      for (final s in current)
        if (sel.strokeIds.contains(s.id))
          () {
            final shifted = s.copyWith(points: [
              for (final p in s.points) StrokePoint(p.x + dx, p.y + dy, p.pressure),
            ]);
            moved.add(shifted);
            return shifted;
          }()
        else
          s,
    ];
    _setStrokes(sel.pageId, updated);
    state = state.copyWith(
      selection: sel.copyWith(offset: Offset.zero),
    );
    // Persist: replace the moved strokes.
    await _strokes.deleteStrokes(sel.strokeIds);
    for (final s in moved) {
      await _strokes.insertStroke(sel.pageId, s);
    }
  }

  Future<void> deleteSelection() async {
    final sel = state.selection;
    if (sel == null) return;
    await eraseStrokes(sel.pageId, sel.strokeIds);
    state = state.copyWith(clearSelection: true);
  }

  /// Recolours every stroke in the selection.
  Future<void> recolorSelection(int color) async {
    final sel = state.selection;
    if (sel == null) return;
    final current = state.strokesFor(sel.pageId);
    final changed = <InkStroke>[];
    final updated = [
      for (final s in current)
        if (sel.strokeIds.contains(s.id))
          () {
            final c = s.copyWith(color: color);
            changed.add(c);
            return c;
          }()
        else
          s,
    ];
    _setStrokes(sel.pageId, updated);
    await _strokes.deleteStrokes(sel.strokeIds);
    for (final s in changed) {
      await _strokes.insertStroke(sel.pageId, s);
    }
  }

  /// The strokes currently selected (for snapshot export).
  List<InkStroke> selectedStrokes() {
    final sel = state.selection;
    if (sel == null) return const [];
    return state
        .strokesFor(sel.pageId)
        .where((s) => sel.strokeIds.contains(s.id))
        .toList();
  }

  // ---- Page settings (paper + adjustable margins) --------------------------

  Future<void> setTemplate(PaperTemplate template) async {
    final id = state.currentPageId;
    if (id != null) await _pages.updateTemplate(id, template);
  }

  Future<void> setPaperColor(PaperColor color) async {
    final id = state.currentPageId;
    if (id != null) await _pages.updatePaperColor(id, color);
  }

  /// Custom-feature hook: update the adjustable margins for the current page.
  Future<void> setMargins(MarginSpec margins) async {
    final id = state.currentPageId;
    if (id == null) return;
    _requestSync();
    // Show it immediately, then persist; clearing the preview once the write
    // lands avoids a flicker back to the old value.
    state = state.copyWith(previewMargins: margins, previewPageId: id);
    await _pages.updateMargins(id, margins);
    state = state.copyWith(clearPreview: true);
  }

  /// Live margin update while dragging: in-memory only, so the canvas can
  /// follow the slider smoothly without a database write per frame.
  void previewMargins(MarginSpec margins) {
    final id = state.currentPageId;
    if (id == null) return;
    state = state.copyWith(previewMargins: margins, previewPageId: id);
  }

  /// Applies the current page's margins to every page in the document.
  Future<void> applyMarginsToAllPages(MarginSpec margins) async {
    for (final page in state.pages) {
      await _pages.updateMargins(page.id, margins);
    }
  }
}
