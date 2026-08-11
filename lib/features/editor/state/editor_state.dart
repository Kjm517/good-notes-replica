import 'package:flutter/foundation.dart';

import '../../../core/db/database.dart';
import '../../../core/ink/ink_stroke.dart';
import '../../../core/models/enums.dart';
import 'tool_settings.dart';

/// Immutable snapshot of the editor for the current document.
@immutable
class EditorState {
  const EditorState({
    this.pages = const [],
    this.currentIndex = 0,
    this.strokes = const [],
    this.tool = ToolType.pen,
    this.eraserMode = EraserMode.stroke,
    required this.toolSettings,
    this.loading = true,
    this.canUndo = false,
    this.canRedo = false,
    this.viewMode = PageViewMode.verticalScroll,
  });

  final List<NotePage> pages;
  final int currentIndex;
  final List<InkStroke> strokes;
  final ToolType tool;
  final EraserMode eraserMode;
  final Map<ToolType, ToolSettings> toolSettings;
  final bool loading;
  final bool canUndo;
  final bool canRedo;
  final PageViewMode viewMode;

  NotePage? get currentPage =>
      (currentIndex >= 0 && currentIndex < pages.length)
          ? pages[currentIndex]
          : null;

  String? get currentPageId => currentPage?.id;

  ToolSettings get activeSettings =>
      toolSettings[tool] ?? const ToolSettings(color: 0xFF1A1A1A, width: 3);

  bool get isDrawingTool =>
      tool == ToolType.pen ||
      tool == ToolType.pencil ||
      tool == ToolType.highlighter;

  EditorState copyWith({
    List<NotePage>? pages,
    int? currentIndex,
    List<InkStroke>? strokes,
    ToolType? tool,
    EraserMode? eraserMode,
    Map<ToolType, ToolSettings>? toolSettings,
    bool? loading,
    bool? canUndo,
    bool? canRedo,
    PageViewMode? viewMode,
  }) {
    return EditorState(
      pages: pages ?? this.pages,
      currentIndex: currentIndex ?? this.currentIndex,
      strokes: strokes ?? this.strokes,
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
