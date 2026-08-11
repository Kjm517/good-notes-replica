import 'package:flutter/widgets.dart';

import 'enums.dart';

/// Logical page dimensions (points) for each preset in portrait orientation.
/// These are canvas coordinates, independent of screen density.
const Map<PageSizePreset, Size> _portraitSizes = {
  PageSizePreset.a4: Size(794, 1123), // 210x297mm @ ~96dpi
  PageSizePreset.a5: Size(559, 794),
  PageSizePreset.letter: Size(816, 1056), // 8.5x11in @ 96dpi
  PageSizePreset.square: Size(900, 900),
  PageSizePreset.reMarkable: Size(702, 936),
};

extension PageSizePresetX on PageSizePreset {
  /// Returns the logical size for this preset in the given [orientation].
  Size size(PageOrientation orientation) {
    final s = _portraitSizes[this]!;
    return orientation == PageOrientation.portrait
        ? s
        : Size(s.height, s.width);
  }

  String get label => switch (this) {
        PageSizePreset.a4 => 'A4',
        PageSizePreset.a5 => 'A5',
        PageSizePreset.letter => 'Letter',
        PageSizePreset.square => 'Square',
        PageSizePreset.reMarkable => 'reMarkable',
      };
}

extension PaperColorX on PaperColor {
  Color get color => switch (this) {
        PaperColor.white => const Color(0xFFFFFFFF),
        PaperColor.cream => const Color(0xFFFBF3E0),
        PaperColor.yellow => const Color(0xFFFCF7C5),
        PaperColor.dark => const Color(0xFF2B2B2E),
        PaperColor.black => const Color(0xFF121212),
      };

  /// Line/grid colour that reads well on this paper.
  Color get lineColor => switch (this) {
        PaperColor.white => const Color(0xFFC9D4E3),
        PaperColor.cream => const Color(0xFFD8CBA8),
        PaperColor.yellow => const Color(0xFFD9CE8A),
        PaperColor.dark => const Color(0xFF3D3D42),
        PaperColor.black => const Color(0xFF2A2A2A),
      };

  /// Whether ink defaults to a light colour on this paper.
  bool get isDark => this == PaperColor.dark || this == PaperColor.black;

  String get label => switch (this) {
        PaperColor.white => 'White',
        PaperColor.cream => 'Cream',
        PaperColor.yellow => 'Yellow',
        PaperColor.dark => 'Dark',
        PaperColor.black => 'Black',
      };
}

extension PaperTemplateX on PaperTemplate {
  String get label => switch (this) {
        PaperTemplate.blank => 'Blank',
        PaperTemplate.lined => 'Lined',
        PaperTemplate.gridSmall => 'Grid (small)',
        PaperTemplate.gridLarge => 'Grid (large)',
        PaperTemplate.dotted => 'Dotted',
        PaperTemplate.cornell => 'Cornell',
        PaperTemplate.music => 'Music',
        PaperTemplate.planner => 'Planner',
        PaperTemplate.custom => 'Custom',
      };
}
