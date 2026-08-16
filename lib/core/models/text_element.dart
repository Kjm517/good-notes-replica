import 'dart:convert';

import 'package:flutter/widgets.dart';

/// How a text/sticky element's contents are aligned.
enum TextAlignKind { left, center, right }

/// A text box or sticky note placed on a page.
///
/// Shared by [ElementType.text] (plain text drawn straight on the page) and
/// [ElementType.sticky] (the same text on a paper-note card, GoodNotes-style).
/// Position and size live on the [CanvasElement] row; this is just the payload
/// stored in its `data` JSON.
@immutable
class TextElementData {
  const TextElementData({
    this.text = '',
    this.colorValue = 0xFF1C1E26,
    this.fontSize = 16,
    this.bold = false,
    this.align = TextAlignKind.left,
  });

  static const double minFontSize = 8;
  static const double maxFontSize = 96;

  static double clampFontSize(double size) =>
      size.clamp(minFontSize, maxFontSize).toDouble();

  final String text;

  /// ARGB colour of the text.
  final int colorValue;

  final double fontSize;
  final bool bold;
  final TextAlignKind align;

  TextAlign get textAlign => switch (align) {
    TextAlignKind.left => TextAlign.left,
    TextAlignKind.center => TextAlign.center,
    TextAlignKind.right => TextAlign.right,
  };

  TextElementData copyWith({
    String? text,
    int? colorValue,
    double? fontSize,
    bool? bold,
    TextAlignKind? align,
  }) => TextElementData(
    text: text ?? this.text,
    colorValue: colorValue ?? this.colorValue,
    fontSize: fontSize == null
        ? this.fontSize
        : TextElementData.clampFontSize(fontSize),
    bold: bold ?? this.bold,
    align: align ?? this.align,
  );

  Map<String, dynamic> toMap() => {
    'text': text,
    'colorValue': colorValue,
    'fontSize': fontSize,
    'bold': bold,
    'align': align.index,
  };

  factory TextElementData.fromMap(Map<String, dynamic> map) => TextElementData(
    text: map['text'] as String? ?? '',
    colorValue: (map['colorValue'] as num?)?.toInt() ?? 0xFF1C1E26,
    fontSize: (map['fontSize'] as num?)?.toDouble() ?? 16,
    bold: map['bold'] as bool? ?? false,
    align: TextAlignKind.values[(map['align'] as num?)?.toInt() ?? 0],
  );

  String toJson() => jsonEncode(toMap());

  factory TextElementData.fromJson(String source) => source.isEmpty
      ? const TextElementData()
      : TextElementData.fromMap(jsonDecode(source) as Map<String, dynamic>);
}
