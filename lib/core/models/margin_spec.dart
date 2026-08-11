import 'dart:convert';

import 'package:flutter/material.dart';

/// First-class, adjustable page margins.
///
/// This is the extension seam for the app's custom "adjustable / extendable
/// margins" feature. Every [PageData] carries a [MarginSpec]; the paper
/// renderer draws its guides and the ink/element layers can (optionally) clip
/// or snap to it. Keeping it a rich value object here means the custom feature
/// is an additive change to the UI + this model, not a rewrite of the canvas.
@immutable
class MarginSpec {
  const MarginSpec({
    this.enabled = false,
    this.left = 0,
    this.top = 0,
    this.right = 0,
    this.bottom = 0,
    this.showGuides = true,
    this.guideColorValue = 0x33FF3B30, // faint red, GoodNotes-style margin line
    this.clipInk = false,
  });

  /// Whether margins are active for the page.
  final bool enabled;

  /// Inset from each edge, in logical page points.
  final double left;
  final double top;
  final double right;
  final double bottom;

  /// Whether to paint the margin guide lines.
  final bool showGuides;

  /// ARGB colour used for the guide lines.
  final int guideColorValue;

  /// If true, ink strokes are clipped to the content rect (advanced; off by
  /// default so it behaves like a visual guide only).
  final bool clipInk;

  Color get guideColor => Color(guideColorValue);

  /// The writable content rectangle inside [pageSize] given these margins.
  Rect contentRect(Size pageSize) {
    if (!enabled) return Offset.zero & pageSize;
    return Rect.fromLTRB(
      left.clamp(0, pageSize.width),
      top.clamp(0, pageSize.height),
      (pageSize.width - right).clamp(0, pageSize.width),
      (pageSize.height - bottom).clamp(0, pageSize.height),
    );
  }

  static const MarginSpec none = MarginSpec();

  /// A classic single vertical left margin line (like ruled notebook paper).
  factory MarginSpec.leftRule({double inset = 72}) =>
      MarginSpec(enabled: true, left: inset, showGuides: true);

  /// Uniform margins on all four sides.
  factory MarginSpec.uniform(double inset) => MarginSpec(
        enabled: true,
        left: inset,
        top: inset,
        right: inset,
        bottom: inset,
      );

  MarginSpec copyWith({
    bool? enabled,
    double? left,
    double? top,
    double? right,
    double? bottom,
    bool? showGuides,
    int? guideColorValue,
    bool? clipInk,
  }) {
    return MarginSpec(
      enabled: enabled ?? this.enabled,
      left: left ?? this.left,
      top: top ?? this.top,
      right: right ?? this.right,
      bottom: bottom ?? this.bottom,
      showGuides: showGuides ?? this.showGuides,
      guideColorValue: guideColorValue ?? this.guideColorValue,
      clipInk: clipInk ?? this.clipInk,
    );
  }

  Map<String, dynamic> toMap() => {
        'enabled': enabled,
        'left': left,
        'top': top,
        'right': right,
        'bottom': bottom,
        'showGuides': showGuides,
        'guideColor': guideColorValue,
        'clipInk': clipInk,
      };

  factory MarginSpec.fromMap(Map<String, dynamic> map) => MarginSpec(
        enabled: map['enabled'] as bool? ?? false,
        left: (map['left'] as num?)?.toDouble() ?? 0,
        top: (map['top'] as num?)?.toDouble() ?? 0,
        right: (map['right'] as num?)?.toDouble() ?? 0,
        bottom: (map['bottom'] as num?)?.toDouble() ?? 0,
        showGuides: map['showGuides'] as bool? ?? true,
        guideColorValue: (map['guideColor'] as num?)?.toInt() ?? 0x33FF3B30,
        clipInk: map['clipInk'] as bool? ?? false,
      );

  String toJson() => jsonEncode(toMap());

  factory MarginSpec.fromJson(String source) =>
      MarginSpec.fromMap(jsonDecode(source) as Map<String, dynamic>);

  @override
  bool operator ==(Object other) =>
      other is MarginSpec &&
      other.enabled == enabled &&
      other.left == left &&
      other.top == top &&
      other.right == right &&
      other.bottom == bottom &&
      other.showGuides == showGuides &&
      other.guideColorValue == guideColorValue &&
      other.clipInk == clipInk;

  @override
  int get hashCode => Object.hash(
      enabled, left, top, right, bottom, showGuides, guideColorValue, clipInk);
}
