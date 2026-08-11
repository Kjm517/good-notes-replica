import 'package:flutter/material.dart';

import '../../../core/models/enums.dart';

/// Per-tool colour + width, plus the palette shown in the toolbar.
@immutable
class ToolSettings {
  const ToolSettings({required this.color, required this.width});
  final int color; // ARGB
  final double width;

  ToolSettings copyWith({int? color, double? width}) =>
      ToolSettings(color: color ?? this.color, width: width ?? this.width);
}

/// Default settings for each tool.
Map<ToolType, ToolSettings> defaultToolSettings() => {
      ToolType.pen: const ToolSettings(color: 0xFF1A1A1A, width: 3.2),
      ToolType.pencil: const ToolSettings(color: 0xFF444444, width: 2.6),
      ToolType.highlighter: const ToolSettings(color: 0x5AFFC400, width: 20),
    };

/// Preset thickness options offered per tool (points).
const Map<ToolType, List<double>> kThicknessPresets = {
  ToolType.pen: [1.6, 3.2, 5.0],
  ToolType.pencil: [1.8, 2.6, 4.0],
  ToolType.highlighter: [14, 20, 30],
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

/// Highlighter-appropriate translucent swatches.
const List<int> kHighlighterPalette = [
  0x5AFFC400,
  0x5A7CF56D,
  0x5A6DC7F5,
  0x5AF56DA0,
  0x5AB06DF5,
  0x5AFF8A5A,
];
