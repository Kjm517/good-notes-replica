import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../../core/db/database.dart';
import '../../../core/models/image_element.dart';
import 'hit_overflow.dart';

/// Which corner is being dragged.
enum _Corner { topLeft, topRight, bottomLeft, bottomRight }

/// Renders a page's image elements and lets the active one be dragged and
/// resized. Positions are in content coordinates.
class ImageLayer extends StatelessWidget {
  const ImageLayer({
    super.key,
    required this.elements,
    required this.bytesFor,
    required this.dragScale,
    required this.offset,
    required this.interactive,
    required this.selectedId,
    required this.onSelect,
    required this.onTransform,
    required this.onTransformEnd,
    this.previewRect,
    this.previewRotation,
  });

  final List<CanvasElement> elements;
  final Future<Uint8List?> Function(String assetId) bytesFor;

  /// On-screen pixels per content point. Pointer deltas arrive in screen
  /// pixels, so they must be divided by this to become content units —
  /// otherwise the image drifts away from the cursor when zoomed.
  final double dragScale;

  /// Content origin within the sheet (extendable margins).
  final Offset offset;

  /// Whether images respond to touch (only for the Image tool).
  final bool interactive;

  final String? selectedId;
  final ValueChanged<String?> onSelect;

  /// Live transform while dragging/resizing (content coordinates).
  final void Function(String id, Rect rect) onTransform;
  final void Function(String id, Rect rect) onTransformEnd;

  /// Live two-finger transform driven by the canvas (content coordinates).
  final Rect? previewRect;
  final double? previewRotation;

  @override
  Widget build(BuildContext context) {
    if (elements.isEmpty) return const SizedBox.shrink();
    final element = elements.first;
    return _ImageItem(
      key: ValueKey(element.id),
      element: element,
      bytesFor: bytesFor,
      dragScale: dragScale,
      offset: offset,
      interactive: interactive,
      selected: element.id == selectedId,
      onSelect: () => onSelect(element.id),
      onTransform: (r) => onTransform(element.id, r),
      onTransformEnd: (r) => onTransformEnd(element.id, r),
      previewRect: element.id == selectedId ? previewRect : null,
      previewRotation: element.id == selectedId ? previewRotation : null,
    );
  }
}

class _ImageItem extends StatefulWidget {
  const _ImageItem({
    super.key,
    required this.element,
    required this.bytesFor,
    required this.dragScale,
    required this.offset,
    required this.interactive,
    required this.selected,
    required this.onSelect,
    required this.onTransform,
    required this.onTransformEnd,
    this.previewRect,
    this.previewRotation,
  });

  final CanvasElement element;
  final Future<Uint8List?> Function(String assetId) bytesFor;
  final double dragScale;
  final Offset offset;
  final bool interactive;
  final bool selected;
  final VoidCallback onSelect;
  final ValueChanged<Rect> onTransform;
  final ValueChanged<Rect> onTransformEnd;
  final Rect? previewRect;
  final double? previewRotation;

  @override
  State<_ImageItem> createState() => _ImageItemState();
}

class _ImageItemState extends State<_ImageItem> {
  Uint8List? _bytes;
  Rect? _live; // in-progress drag/resize, content coordinates
  Rect? _gestureStart;
  bool _canvasOwnsPinch = false;

  double get _rotation => widget.previewRotation ?? widget.element.rotation;

  static const double _minSize = 24;

  ImageElementData? _parsedData;
  String? _parsedJson;

  ImageElementData get _data {
    final json = widget.element.data;
    if (json != _parsedJson) {
      _parsedJson = json;
      _parsedData = ImageElementData.fromJson(json);
    }
    return _parsedData!;
  }

  Rect get _stored => Rect.fromLTWH(
    widget.element.x,
    widget.element.y,
    widget.element.width,
    widget.element.height,
  );

  Rect get _rect => widget.previewRect ?? _live ?? _stored;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant _ImageItem old) {
    super.didUpdateWidget(old);
    if (old.element.data != widget.element.data) _load();
  }

  Future<void> _load() async {
    final bytes = await widget.bytesFor(_data.assetId);
    if (mounted) setState(() => _bytes = bytes);
  }

  /// Screen-pixel delta -> content-unit delta.
  Offset _toContent(Offset delta) =>
      widget.dragScale <= 0 ? delta : delta / widget.dragScale;

  void _move(Offset screenDelta) {
    final next = _rect.shift(_toContent(screenDelta));
    setState(() => _live = next);
    widget.onTransform(next);
  }

  /// Resizes from a corner, keeping the opposite corner anchored and the
  /// aspect ratio locked (the usual behaviour for photos).
  void _resize(_Corner corner, Offset screenDelta) {
    final d = _toContent(screenDelta);
    final r = _rect;
    final aspect = r.height == 0 ? 1.0 : r.width / r.height;

    // Signed growth along x for this corner.
    final growX = switch (corner) {
      _Corner.topRight || _Corner.bottomRight => d.dx,
      _Corner.topLeft || _Corner.bottomLeft => -d.dx,
    };
    var width = (r.width + growX).clamp(_minSize, 100000.0);
    var height = (width / aspect).clamp(_minSize, 100000.0);
    width = height * aspect;

    final next = switch (corner) {
      _Corner.bottomRight => Rect.fromLTWH(r.left, r.top, width, height),
      _Corner.bottomLeft => Rect.fromLTWH(
        r.right - width,
        r.top,
        width,
        height,
      ),
      _Corner.topRight => Rect.fromLTWH(
        r.left,
        r.bottom - height,
        width,
        height,
      ),
      _Corner.topLeft => Rect.fromLTWH(
        r.right - width,
        r.bottom - height,
        width,
        height,
      ),
    };
    setState(() => _live = next);
    widget.onTransform(next);
  }

  void _commit() {
    final r = _rect;
    setState(() {
      _live = null;
      _gestureStart = null;
    });
    widget.onTransformEnd(r);
  }

  void _onScaleStart(ScaleStartDetails d) {
    widget.onSelect();
    _canvasOwnsPinch = d.pointerCount >= 2;
    if (_canvasOwnsPinch) return;
    _gestureStart = _rect;
  }

  void _onScaleUpdate(ScaleUpdateDetails d) {
    // Two-finger resize/rotate is handled by the canvas so it still works
    // when one finger sits on a grip or slightly off the picture.
    if (d.pointerCount >= 2) {
      _canvasOwnsPinch = true;
      return;
    }
    _move(d.focalPointDelta);
  }

  void _onScaleEnd(ScaleEndDetails _) {
    if (_canvasOwnsPinch) {
      _canvasOwnsPinch = false;
      setState(() {
        _live = null;
        _gestureStart = null;
      });
      return;
    }
    if (_live == null && _gestureStart == null) return;
    _commit();
  }

  @override
  Widget build(BuildContext context) {
    final rect = _rect;
    final s = widget.dragScale <= 0 ? 1.0 : widget.dragScale;
    // Corner grips sit half-outside the image; pad just enough that they
    // still receive taps.
    final chrome = widget.selected ? 12 / s : 0.0;
    final rotation = _rotation;
    final dpr = MediaQuery.devicePixelRatioOf(context);
    final cacheW = (rect.width * s * dpr).round().clamp(32, 2048);
    final cacheH = (rect.height * s * dpr).round().clamp(32, 2048);

    Widget painted = Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned(
          left: chrome,
          top: chrome,
          right: chrome,
          bottom: chrome,
          child: widget.interactive || widget.selected
              ? MouseRegion(
                  cursor: SystemMouseCursors.move,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: widget.onSelect,
                    onScaleStart: _onScaleStart,
                    onScaleUpdate: _onScaleUpdate,
                    onScaleEnd: _onScaleEnd,
                    child: _bytes == null
                        ? const ColoredBox(color: Color(0x11000000))
                        : ClipRect(
                            child: _CroppedImage(
                              bytes: _bytes!,
                              data: _data,
                              cacheWidth: cacheW,
                              cacheHeight: cacheH,
                            ),
                          ),
                  ),
                )
              : (_bytes == null
                    ? const ColoredBox(color: Color(0x11000000))
                    : ClipRect(
                        child: _CroppedImage(
                          bytes: _bytes!,
                          data: _data,
                          cacheWidth: cacheW,
                          cacheHeight: cacheH,
                        ),
                      )),
        ),
        if (widget.selected) ...[
          Positioned(
            left: chrome,
            top: chrome,
            right: chrome,
            bottom: chrome,
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  border: Border.all(
                    color: Theme.of(context).colorScheme.primary,
                    width: 2 / s,
                  ),
                ),
              ),
            ),
          ),
          for (final corner in _Corner.values)
            _Handle(
              corner: corner,
              scale: s,
              chrome: chrome,
              onDrag: (delta) => _resize(corner, delta),
              onEnd: _commit,
            ),
        ],
      ],
    );
    if (rotation.abs() > 0.0001) {
      painted = Transform.rotate(angle: rotation, child: painted);
    }
    if (widget.selected) painted = HitOverflow(child: painted);
    painted = IgnorePointer(
      ignoring: !widget.interactive && !widget.selected,
      child: painted,
    );

    return Positioned(
      left: rect.left + widget.offset.dx - chrome,
      top: rect.top + widget.offset.dy - chrome,
      width: rect.width + chrome * 2,
      height: rect.height + chrome * 2,
      child: RepaintBoundary(child: painted),
    );
  }
}

/// A corner resize grip. Sized in content units so it stays a constant size
/// on screen regardless of zoom.
class _Handle extends StatelessWidget {
  const _Handle({
    required this.corner,
    required this.scale,
    required this.chrome,
    required this.onDrag,
    required this.onEnd,
  });

  final _Corner corner;
  final double scale;
  final double chrome;
  final ValueChanged<Offset> onDrag;
  final VoidCallback onEnd;

  @override
  Widget build(BuildContext context) {
    final s = scale <= 0 ? 1.0 : scale;
    final size = 18 / s; // ~18 screen px
    final inset = chrome - size / 2;
    final isLeft = corner == _Corner.topLeft || corner == _Corner.bottomLeft;
    final isTop = corner == _Corner.topLeft || corner == _Corner.topRight;

    return Positioned(
      left: isLeft ? inset : null,
      right: isLeft ? null : inset,
      top: isTop ? inset : null,
      bottom: isTop ? null : inset,
      width: size,
      height: size,
      child: MouseRegion(
        cursor: isLeft == isTop
            ? SystemMouseCursors.resizeUpLeftDownRight
            : SystemMouseCursors.resizeUpRightDownLeft,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onPanUpdate: (d) => onDrag(d.delta),
          onPanEnd: (_) => onEnd(),
          child: Container(
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2 / s),
            ),
          ),
        ),
      ),
    );
  }
}

/// Draws the visible (cropped) portion of the source image.
class _CroppedImage extends StatelessWidget {
  const _CroppedImage({
    required this.bytes,
    required this.data,
    this.cacheWidth,
    this.cacheHeight,
  });
  final Uint8List bytes;
  final ImageElementData data;
  final int? cacheWidth;
  final int? cacheHeight;

  @override
  Widget build(BuildContext context) {
    final full =
        data.cropLeft == 0 &&
        data.cropTop == 0 &&
        data.cropRight == 1 &&
        data.cropBottom == 1;

    if (full) {
      return Opacity(
        opacity: data.opacity,
        child: Image.memory(
          bytes,
          fit: BoxFit.fill,
          gaplessPlayback: true,
          cacheWidth: cacheWidth,
          cacheHeight: cacheHeight,
          filterQuality: FilterQuality.medium,
        ),
      );
    }

    // Scale the source up so the crop window fills the element box, then
    // translate so the requested region is what shows through.
    final cw = (data.cropRight - data.cropLeft).clamp(0.01, 1.0);
    final ch = (data.cropBottom - data.cropTop).clamp(0.01, 1.0);
    return Opacity(
      opacity: data.opacity,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final w = constraints.maxWidth / cw;
          final h = constraints.maxHeight / ch;
          return Stack(
            clipBehavior: Clip.hardEdge,
            children: [
              Positioned(
                left: -data.cropLeft * w,
                top: -data.cropTop * h,
                width: w,
                height: h,
                child: Image.memory(
                  bytes,
                  fit: BoxFit.fill,
                  gaplessPlayback: true,
                  cacheWidth: cacheWidth,
                  cacheHeight: cacheHeight,
                  filterQuality: FilterQuality.medium,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
