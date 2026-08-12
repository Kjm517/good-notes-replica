/// Shared enums used across the data model and UI.
library;

/// What kind of item lives in the library.
enum DocumentType { folder, notebook, pdf }

/// Built-in paper templates. The [custom] value is a placeholder for
/// user-imported templates (backed by an asset).
enum PaperTemplate {
  blank,
  lined,
  gridSmall,
  gridLarge,
  dotted,
  cornell,
  music,
  planner,
  custom,
}

/// Paper background tint presets.
enum PaperColor { white, cream, yellow, dark, black }

/// Page orientation.
enum PageOrientation { portrait, landscape }

/// Named page sizes (logical points at 1x). Kept small; more can be added.
enum PageSizePreset { a4, a5, letter, square, reMarkable }

/// Drawing / editing tools available in the editor.
///
/// IMPORTANT: values are persisted by index (drift `intEnum`), so new tools
/// must be appended at the end — never inserted or reordered.
enum ToolType {
  pen,
  pencil,
  highlighter,
  eraser,
  lasso,
  shape,
  text,
  image,
  hand, // pan/zoom only
  fountainPen,
  tape,
}

/// Tools that lay down ink (as opposed to selecting/erasing/navigating).
const Set<ToolType> kInkTools = {
  ToolType.pen,
  ToolType.fountainPen,
  ToolType.pencil,
  ToolType.highlighter,
  ToolType.tape,
  ToolType.shape,
};

/// Eraser behaviour.
enum EraserMode { stroke, area, highlighterOnly }

/// Line style for a stroke. Persisted by index — append only.
enum StrokeStyle { solid, dashed, dotted }

/// Nib shape for broad tools (highlighter, tape). A round tip gives soft,
/// rounded stroke ends; a square (chisel) tip gives flat, blocky ends.
/// Persisted by index — append only.
enum StrokeTip { round, square }

/// How the lasso captures content.
enum LassoMode { freehand, rectangular }

/// Canvas element kinds (non-ink objects).
enum ElementType { text, image, shape }

/// Recognised/target shape kinds for the shapes tool.
enum ShapeKind { line, arrow, rectangle, ellipse, triangle, polygon }

/// How pages are laid out in the editor viewport.
enum PageViewMode { verticalScroll, horizontalPage }
