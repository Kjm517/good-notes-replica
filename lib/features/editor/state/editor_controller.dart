import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../app/providers.dart';
import '../../../core/db/database.dart';
import '../../../core/ink/ink_stroke.dart';
import '../../../core/models/enums.dart';
import '../../../core/models/margin_spec.dart';
import '../data/page_repository.dart';
import '../data/stroke_repository.dart';
import '../providers.dart';
import 'editor_state.dart';
import 'tool_settings.dart';

/// Represents one undoable ink edit: either strokes added or strokes removed.
class _Edit {
  _Edit.add(this.strokes) : isAdd = true;
  _Edit.remove(this.strokes) : isAdd = false;
  final bool isAdd;
  final List<InkStroke> strokes;
}

/// Stateful editor for a single document. Owns the current page's in-memory
/// strokes plus a per-page undo/redo history, and persists every edit.
class EditorController extends FamilyNotifier<EditorState, String> {
  late final PageRepository _pages;
  late final StrokeRepository _strokes;
  late final Uuid _uuid;

  final List<_Edit> _undo = [];
  final List<_Edit> _redo = [];
  int _seqCounter = 0;

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
    final strokes =
        pages.isEmpty ? <InkStroke>[] : await _strokes.getStrokes(pages.first.id);
    _seqCounter = _maxSeq(strokes);
    state = state.copyWith(
      pages: pages,
      currentIndex: 0,
      strokes: strokes,
      loading: false,
    );
  }

  int _maxSeq(List<InkStroke> strokes) =>
      strokes.fold<int>(0, (m, s) => s.seq > m ? s.seq : m);

  /// Called by the screen when the pages stream changes (add/delete/reorder).
  Future<void> onPagesChanged(List<NotePage> pages) async {
    if (pages.isEmpty) {
      state = state.copyWith(pages: pages, strokes: const []);
      return;
    }
    final idx = state.currentIndex.clamp(0, pages.length - 1);
    final prevId = state.currentPageId;
    final newId = pages[idx].id;
    if (prevId != newId) {
      await _loadPage(pages, idx);
    } else {
      state = state.copyWith(pages: pages, currentIndex: idx);
    }
  }

  Future<void> goToPage(int index) async {
    if (index < 0 || index >= state.pages.length) return;
    await _loadPage(state.pages, index);
  }

  Future<void> _loadPage(List<NotePage> pages, int index) async {
    final strokes = await _strokes.getStrokes(pages[index].id);
    _seqCounter = _maxSeq(strokes);
    _undo.clear();
    _redo.clear();
    state = state.copyWith(
      pages: pages,
      currentIndex: index,
      strokes: strokes,
      canUndo: false,
      canRedo: false,
    );
  }

  // ---- Tool state ----------------------------------------------------------

  void setTool(ToolType tool) => state = state.copyWith(tool: tool);

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

  void setViewMode(PageViewMode mode) =>
      state = state.copyWith(viewMode: mode);

  // ---- Ink edits -----------------------------------------------------------

  Future<void> commitStroke(InkStroke stroke) async {
    final pageId = state.currentPageId;
    if (pageId == null || stroke.points.isEmpty) return;
    final s = stroke.copyWith(id: _uuid.v4(), seq: ++_seqCounter);
    state = state.copyWith(strokes: [...state.strokes, s]);
    _pushUndo(_Edit.add([s]));
    await _strokes.insertStroke(pageId, s);
  }

  Future<void> eraseStrokes(Set<String> ids) async {
    if (ids.isEmpty) return;
    final removed =
        state.strokes.where((s) => ids.contains(s.id)).toList(growable: false);
    if (removed.isEmpty) return;
    state = state.copyWith(
      strokes: state.strokes.where((s) => !ids.contains(s.id)).toList(),
    );
    _pushUndo(_Edit.remove(removed));
    await _strokes.deleteStrokes(ids);
  }

  Future<void> undo() async {
    if (_undo.isEmpty) return;
    final e = _undo.removeLast();
    e.isAdd ? await _delete(e.strokes) : await _insert(e.strokes);
    _redo.add(e);
    _refreshHistoryFlags();
  }

  Future<void> redo() async {
    if (_redo.isEmpty) return;
    final e = _redo.removeLast();
    e.isAdd ? await _insert(e.strokes) : await _delete(e.strokes);
    _undo.add(e);
    _refreshHistoryFlags();
  }

  Future<void> _insert(List<InkStroke> strokes) async {
    final pageId = state.currentPageId;
    if (pageId == null) return;
    final merged = [...state.strokes, ...strokes]
      ..sort((a, b) => a.seq.compareTo(b.seq));
    state = state.copyWith(strokes: merged);
    for (final s in strokes) {
      await _strokes.insertStroke(pageId, s);
    }
  }

  Future<void> _delete(List<InkStroke> strokes) async {
    final ids = strokes.map((s) => s.id).toSet();
    state = state.copyWith(
      strokes: state.strokes.where((s) => !ids.contains(s.id)).toList(),
    );
    await _strokes.deleteStrokes(ids);
  }

  void _pushUndo(_Edit e) {
    _undo.add(e);
    _redo.clear();
    _refreshHistoryFlags();
  }

  void _refreshHistoryFlags() =>
      state = state.copyWith(canUndo: _undo.isNotEmpty, canRedo: _redo.isNotEmpty);

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
    if (id != null) await _pages.updateMargins(id, margins);
  }
}
