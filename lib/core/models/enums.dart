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
}

/// Eraser behaviour.
enum EraserMode { stroke, area, highlighterOnly }

/// Canvas element kinds (non-ink objects).
enum ElementType { text, image, shape }

/// Recognised/target shape kinds for the shapes tool.
enum ShapeKind { line, arrow, rectangle, ellipse, triangle, polygon }

/// How pages are laid out in the editor viewport.
enum PageViewMode { verticalScroll, horizontalPage }
