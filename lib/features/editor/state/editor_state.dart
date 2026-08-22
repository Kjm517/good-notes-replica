import 'package:flutter/foundation.dart';

import '../../../core/db/database.dart';
import '../../../core/ink/ink_stroke.dart';
import '../../../core/models/enums.dart';
import '../../../core/models/margin_spec.dart';
import 'lasso_selection.dart';
import 'tool_settings.dart';

/// Tool selected whenever a document is opened (pan/zoom, not ink).
const kDefaultEditorTool = ToolType.hand;

/// Immutable snapshot of the editor for the current document.
@immutable
class EditorState {
  const EditorState({
    this.pages = const [],
    this.currentIndex = 0,
    this.strokesByPage = const {},
    this.tool = kDefaultEditorTool,
    this.eraserMode = EraserMode.stroke,
    required this.toolSettings,
    this.loading = true,
    this.canUndo = false,
    this.canRedo = false,
    this.viewMode = PageViewMode.verticalScroll,
    this.previewMargins,
    this.previewPageId,
    this.selection,
    this.shapeOptions = const ShapeOptions(),
    this.lassoOptions = const LassoOptions(),
    this.selectedElementId,
  });

  final List<NotePage> pages;

  /// Index of the page currently in view (drives the toolbar's page context).
  final int currentIndex;

  /// Strokes for every page loaded so far, keyed by page id. Pages are loaded
  /// lazily as they scroll into view.
  final Map<String, List<InkStroke>> strokesByPage;

  final ToolType tool;
  final EraserMode eraserMode;
  final Map<ToolType, ToolSettings> toolSettings;
  final bool loading;
  final bool canUndo;
  final bool canRedo;
  final PageViewMode viewMode;

  /// Live margin values while the user drags the margin sliders. Held in
  /// memory so the canvas updates at 60fps without a database write per tick;
  /// persisted once on release.
  final MarginSpec? previewMargins;
  final String? previewPageId;

  /// Active lasso selection, if any.
  final LassoSelection? selection;

  /// Draw Shape panel settings.
  final ShapeOptions shapeOptions;

  /// Lasso Tool panel settings.
  final LassoOptions lassoOptions;

  /// Currently selected image/text element, if any.
  final String? selectedElementId;

  /// Pages as they should be rendered, with any in-progress margin preview
  /// applied to the page being edited.
  List<NotePage> get pagesForRender {
    final preview = previewMargins;
    final id = previewPageId;
    if (preview == null || id == null) return pages;
    return [
      for (final p in pages)
        if (p.id == id) p.copyWith(marginSpec: preview) else p,
    ];
  }

  /// The current page's margins, including any live preview.
  MarginSpec? get effectiveMargins {
    final page = currentPage;
    if (page == null) return null;
    if (previewMargins != null && previewPageId == page.id) {
      return previewMargins;
    }
    return page.marginSpec;
  }

  NotePage? get currentPage =>
      (currentIndex >= 0 && currentIndex < pages.length)
          ? pages[currentIndex]
          : null;

  String? get currentPageId => currentPage?.id;

  List<InkStroke> strokesFor(String pageId) =>
      strokesByPage[pageId] ?? const [];

  ToolSettings get activeSettings =>
      toolSettings[tool] ?? const ToolSettings(color: 0xFF1A1A1A, width: 3);

  /// True for tools that lay down ink, i.e. the colour/thickness row applies.
  bool get isDrawingTool => kInkTools.contains(tool);

  /// True when the active tool draws or erases (i.e. one-pointer input should
  /// mark the page rather than scroll it).
  bool get isMarkingTool => isDrawingTool || tool == ToolType.eraser;

  EditorState copyWith({
    List<NotePage>? pages,
    int? currentIndex,
    Map<String, List<InkStroke>>? strokesByPage,
    ToolType? tool,
    EraserMode? eraserMode,
    Map<ToolType, ToolSettings>? toolSettings,
    bool? loading,
    bool? canUndo,
    bool? canRedo,
    PageViewMode? viewMode,
    MarginSpec? previewMargins,
    String? previewPageId,
    bool clearPreview = false,
    LassoSelection? selection,
    bool clearSelection = false,
    ShapeOptions? shapeOptions,
    LassoOptions? lassoOptions,
    String? selectedElementId,
    bool clearElementSelection = false,
  }) {
    return EditorState(
      previewMargins: clearPreview ? null : (previewMargins ?? this.previewMargins),
      previewPageId: clearPreview ? null : (previewPageId ?? this.previewPageId),
      selection: clearSelection ? null : (selection ?? this.selection),
      shapeOptions: shapeOptions ?? this.shapeOptions,
      lassoOptions: lassoOptions ?? this.lassoOptions,
      selectedElementId: clearElementSelection
          ? null
          : (selectedElementId ?? this.selectedElementId),
      pages: pages ?? this.pages,
      currentIndex: currentIndex ?? this.currentIndex,
      strokesByPage: strokesByPage ?? this.strokesByPage,
      tool: tool ?? this.tool,
      eraserMode: eraserMode ?? this.eraserMode,
      toolSettings: toolSettings ?? this.toolSettings,
      loading: loading ?? this.loading,
      canUndo: canUndo ?? this.canUndo,
      canRedo: canRedo ?? this.canRedo,
      viewMode: viewMode ?? this.viewMode,
    );
  }
}

/// Merges a Drift [watch] emission with in-memory pages.
///
/// Apply-to-all used to write every page one-by-one, flooding the watch. A
/// late snapshot with the previously applied spec would replace [local] after
/// the user had already started a new drag, and [EditorController.setMargins]
/// clearing the preview then snapped the sliders back. Prefer the local
/// [NotePage.marginSpec] when it is at least as new as the incoming row, and
/// keep any live preview on top.
List<NotePage> mergeWatchedPages({
  required List<NotePage> local,
  required List<NotePage> incoming,
  MarginSpec? previewMargins,
  String? previewPageId,
}) {
  if (local.isEmpty) return incoming;
  final localById = {for (final page in local) page.id: page};
  return [
    for (final page in incoming)
      _mergeWatchedPage(
        local: localById[page.id],
        incoming: page,
        previewMargins: previewMargins,
        previewPageId: previewPageId,
      ),
  ];
}

NotePage _mergeWatchedPage({
  required NotePage? local,
  required NotePage incoming,
  required MarginSpec? previewMargins,
  required String? previewPageId,
}) {
  var result = incoming;
  if (local != null &&
      !incoming.updatedAt.isAfter(local.updatedAt) &&
      local.marginSpec != incoming.marginSpec) {
    result = incoming.copyWith(
      marginSpec: local.marginSpec,
      updatedAt: local.updatedAt,
    );
  }
  if (previewMargins != null && previewPageId == result.id) {
    result = result.copyWith(marginSpec: previewMargins);
  }
  return result;
}
