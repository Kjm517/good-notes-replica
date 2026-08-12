import 'dart:convert';

import 'package:flutter/widgets.dart';

/// An image placed on a page: position/size in content coordinates plus a
/// non-destructive crop expressed as fractions of the source image.
@immutable
class ImageElementData {
  const ImageElementData({
    required this.assetId,
    this.cropLeft = 0,
    this.cropTop = 0,
    this.cropRight = 1,
    this.cropBottom = 1,
    this.opacity = 1,
  });

  final String assetId;

  /// Crop window as fractions (0..1) of the source image.
  final double cropLeft;
  final double cropTop;
  final double cropRight;
  final double cropBottom;

  final double opacity;

  /// The visible source rectangle for an image of [imageSize].
  Rect sourceRect(Size imageSize) => Rect.fromLTRB(
        cropLeft * imageSize.width,
        cropTop * imageSize.height,
        cropRight * imageSize.width,
        cropBottom * imageSize.height,
      );

  /// Aspect ratio (w/h) of the cropped region.
  double croppedAspect(Size imageSize) {
    final r = sourceRect(imageSize);
    if (r.height <= 0) return 1;
    return r.width / r.height;
  }

  ImageElementData copyWith({
    double? cropLeft,
    double? cropTop,
    double? cropRight,
    double? cropBottom,
    double? opacity,
  }) =>
      ImageElementData(
        assetId: assetId,
        cropLeft: cropLeft ?? this.cropLeft,
        cropTop: cropTop ?? this.cropTop,
        cropRight: cropRight ?? this.cropRight,
        cropBottom: cropBottom ?? this.cropBottom,
        opacity: opacity ?? this.opacity,
      );

  Map<String, dynamic> toMap() => {
        'assetId': assetId,
        'cropLeft': cropLeft,
        'cropTop': cropTop,
        'cropRight': cropRight,
        'cropBottom': cropBottom,
        'opacity': opacity,
      };

  factory ImageElementData.fromMap(Map<String, dynamic> map) =>
      ImageElementData(
        assetId: map['assetId'] as String? ?? '',
        cropLeft: (map['cropLeft'] as num?)?.toDouble() ?? 0,
        cropTop: (map['cropTop'] as num?)?.toDouble() ?? 0,
        cropRight: (map['cropRight'] as num?)?.toDouble() ?? 1,
        cropBottom: (map['cropBottom'] as num?)?.toDouble() ?? 1,
        opacity: (map['opacity'] as num?)?.toDouble() ?? 1,
      );

  String toJson() => jsonEncode(toMap());

  factory ImageElementData.fromJson(String source) =>
      ImageElementData.fromMap(jsonDecode(source) as Map<String, dynamic>);

  @override
  bool operator ==(Object other) =>
      other is ImageElementData &&
      other.assetId == assetId &&
      other.cropLeft == cropLeft &&
      other.cropTop == cropTop &&
      other.cropRight == cropRight &&
      other.cropBottom == cropBottom &&
      other.opacity == opacity;

  @override
  int get hashCode => Object.hash(
      assetId, cropLeft, cropTop, cropRight, cropBottom, opacity);
}
