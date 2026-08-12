import 'package:flutter/material.dart';

import '../../../core/models/enums.dart';

/// Per-tool colour, width and line style.
@immutable
class ToolSettings {
  const ToolSettings({
    required this.color,
    required this.width,
    this.style = StrokeStyle.solid,
    this.tip = StrokeTip.round,
  });

  final int color; // ARGB
  final double width;
  final StrokeStyle style;

  /// Nib shape, used by the broad tools (highlighter, tape).
  final StrokeTip tip;

  ToolSettings copyWith(
          {int? color, double? width, StrokeStyle? style, StrokeTip? tip}) =>
      ToolSettings(
        color: color ?? this.color,
        width: width ?? this.width,
        style: style ?? this.style,
        tip: tip ?? this.tip,
      );
}

/// Options for the shape tool (mirrors GoodNotes' Draw Shape panel).
@immutable
class ShapeOptions {
  const ShapeOptions({
    this.requireHoldToSnap = false,
    this.snapToOtherShapes = true,
    this.fillColor = false,
  });

  /// Only snap the shape if the pointer is held still before lifting.
  final bool requireHoldToSnap;

  /// Align new shapes to nearby existing ones.
  final bool snapToOtherShapes;

  /// Fill the recognised shape with a wash of the stroke colour.
  final bool fillColor;

  ShapeOptions copyWith({
    bool? requireHoldToSnap,
    bool? snapToOtherShapes,
    bool? fillColor,
  }) =>
      ShapeOptions(
        requireHoldToSnap: requireHoldToSnap ?? this.requireHoldToSnap,
        snapToOtherShapes: snapToOtherShapes ?? this.snapToOtherShapes,
        fillColor: fillColor ?? this.fillColor,
      );
}

/// Options for the lasso tool (mirrors GoodNotes' Lasso Tool panel).
@immutable
class LassoOptions {
  const LassoOptions({
    this.mode = LassoMode.freehand,
    this.includeHandwriting = true,
    this.includeShapes = true,
    this.includeHighlighter = true,
    this.includeTape = true,
  });

  final LassoMode mode;
  final bool includeHandwriting;
  final bool includeShapes;
  final bool includeHighlighter;
  final bool includeTape;

  /// Whether a stroke made with [tool] can be captured by the lasso.
  bool includes(ToolType tool) => switch (tool) {
        ToolType.pen || ToolType.fountainPen || ToolType.pencil =>
          includeHandwriting,
        ToolType.shape => includeShapes,
        ToolType.highlighter => includeHighlighter,
        ToolType.tape => includeTape,
        _ => true,
      };

  LassoOptions copyWith({
    LassoMode? mode,
    bool? includeHandwriting,
    bool? includeShapes,
    bool? includeHighlighter,
    bool? includeTape,
  }) =>
      LassoOptions(
        mode: mode ?? this.mode,
        includeHandwriting: includeHandwriting ?? this.includeHandwriting,
        includeShapes: includeShapes ?? this.includeShapes,
        includeHighlighter: includeHighlighter ?? this.includeHighlighter,
        includeTape: includeTape ?? this.includeTape,
      );
}

/// Default settings for each ink tool.
Map<ToolType, ToolSettings> defaultToolSettings() => {
      ToolType.pen: const ToolSettings(color: 0xFF1A1A1A, width: 3.2),
      ToolType.fountainPen: const ToolSettings(color: 0xFF12275C, width: 4.2),
      ToolType.pencil: const ToolSettings(color: 0xFF444444, width: 2.6),
      ToolType.highlighter: const ToolSettings(color: 0x5AFFC400, width: 20),
      ToolType.tape: const ToolSettings(color: 0xCCFFD54F, width: 26),
      ToolType.shape: const ToolSettings(color: 0xFF1A1A1A, width: 3),
    };

/// Preset thickness options offered per tool (points).
const Map<ToolType, List<double>> kThicknessPresets = {
  ToolType.pen: [1.6, 3.2, 5.0],
  ToolType.fountainPen: [2.2, 4.2, 7.0],
  ToolType.pencil: [1.8, 2.6, 4.0],
  ToolType.highlighter: [14, 20, 30],
  ToolType.tape: [18, 26, 40],
  ToolType.shape: [1.6, 3.0, 5.0],
};

/// Tools whose nib shape (round vs square/chisel) is configurable.
const Set<ToolType> kTipTools = {ToolType.highlighter, ToolType.tape};

/// Continuous width range (min, max) for the fine-adjust slider.
const Map<ToolType, (double, double)> kWidthRange = {
  ToolType.pen: (0.6, 12),
  ToolType.fountainPen: (1.0, 16),
  ToolType.pencil: (0.6, 10),
  ToolType.highlighter: (6, 60),
  ToolType.tape: (8, 80),
  ToolType.shape: (0.8, 12),
};

/// The default swatch palette.
const List<int> kColorPalette = [
  0xFF1A1A1A, // near-black
  0xFF3D6DF0, // blue
  0xFFE2453C, // red
  0xFF2FA84F, // green
  0xFFF5A623, // orange
  0xFF9B51E0, // purple
  0xFF00B8B8, // teal
  0xFFEB5DA0, // pink
  0xFF8B5A2B, // brown
  0xFFFFFFFF, // white (for dark paper)
];

/// Ink colours suited to a fountain pen.
const List<int> kFountainPalette = [
  0xFF12275C, // midnight blue
  0xFF1A1A1A, // black
  0xFF2E4A2E, // forest
  0xFF6B1F1F, // oxblood
  0xFF3F3D8C, // violet ink
  0xFF14595C, // teal ink
];

/// Highlighter-appropriate translucent swatches.
const List<int> kHighlighterPalette = [
  0x5AFFC400,
  0x5A7CF56D,
  0x5A6DC7F5,
  0x5AF56DA0,
  0x5AB06DF5,
  0x5AFF8A5A,
];

/// Washi-tape colours: more opaque than a highlighter.
const List<int> kTapePalette = [
  0xCCFFD54F,
  0xCCFF8A80,
  0xCC80DEEA,
  0xCCA5D6A7,
  0xCCCE93D8,
  0xCCBCAAA4,
  0xCCE0E0E0,
];

/// The palette to show for a given tool.
List<int> paletteFor(ToolType tool) => switch (tool) {
      ToolType.highlighter => kHighlighterPalette,
      ToolType.tape => kTapePalette,
      ToolType.fountainPen => kFountainPalette,
      _ => kColorPalette,
    };
