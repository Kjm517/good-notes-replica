import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

/// Hit-tests overflowing children, not just the layout box.
///
/// Corner resize grips and the text format bar sit slightly outside the
/// element rectangle. A normal [RenderBox] rejects those taps because they
/// miss `size.contains`.
class HitOverflow extends SingleChildRenderObjectWidget {
  const HitOverflow({super.key, super.child});

  @override
  RenderObject createRenderObject(BuildContext context) => _RenderHitOverflow();
}

class _RenderHitOverflow extends RenderProxyBox {
  @override
  bool hitTest(BoxHitTestResult result, {required Offset position}) {
    if (hitTestChildren(result, position: position)) {
      result.add(BoxHitTestEntry(this, position));
      return true;
    }
    if (size.contains(position) && hitTestSelf(position)) {
      result.add(BoxHitTestEntry(this, position));
      return true;
    }
    return false;
  }
}
