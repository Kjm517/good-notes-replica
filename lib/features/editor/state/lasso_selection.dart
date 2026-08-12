import 'dart:ui';

import '../../../core/ink/ink_stroke.dart';

/// A completed lasso selection: which strokes are captured, the lasso outline
/// (in content coordinates) and the drag offset applied so far.
class LassoSelection {
  const LassoSelection({
    required this.pageId,
    required this.strokeIds,
    required this.path,
    required this.bounds,
    this.offset = Offset.zero,
  });

  final String pageId;
  final Set<String> strokeIds;
  final List<Offset> path;
  final Rect bounds;

  /// Live translation while dragging the selection.
  final Offset offset;

  bool get isEmpty => strokeIds.isEmpty;

  Rect get movedBounds => bounds.shift(offset);

  LassoSelection copyWith({Offset? offset}) => LassoSelection(
        pageId: pageId,
        strokeIds: strokeIds,
        path: path,
        bounds: bounds,
        offset: offset ?? this.offset,
      );

  /// True when [point] (content coordinates) is inside the moved selection.
  bool hitTest(Offset point) => movedBounds.inflate(6).contains(point);

  /// Builds a selection from a lasso outline and the page's strokes.
  static LassoSelection? fromLasso({
    required String pageId,
    required List<Offset> lasso,
    required List<InkStroke> strokes,
  }) {
    if (lasso.length < 3) return null;
    final path = Path()..addPolygon(lasso, true);
    final lassoBounds = path.getBounds();

    final ids = <String>{};
    Rect? union;
    for (final stroke in strokes) {
      if (!stroke.bounds.overlaps(lassoBounds)) continue;
      // A stroke is selected when most of its points fall inside the lasso.
      var inside = 0;
      for (final p in stroke.points) {
        if (path.contains(p.offset)) inside++;
      }
      if (inside == 0) continue;
      if (inside / stroke.points.length < 0.55) continue;
      ids.add(stroke.id);
      union = union == null ? stroke.bounds : union.expandToInclude(stroke.bounds);
    }
    if (ids.isEmpty || union == null) return null;
    return LassoSelection(
      pageId: pageId,
      strokeIds: ids,
      path: lasso,
      bounds: union,
    );
  }
}
