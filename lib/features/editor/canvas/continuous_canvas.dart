import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/db/database.dart';
import '../../../core/ink/ink_stroke.dart';
import '../../../core/models/enums.dart';
import '../ink/shape_recognizer.dart';
import '../pages/background_painter.dart';
import '../pages/paper_painter.dart';
import '../state/lasso_selection.dart';
import '../state/tool_settings.dart';
import 'image_layer.dart';
import 'ink_painters.dart';
import 'lasso_painter.dart';

const double _kPageGap = 16;

/// Continuously scrolling page view — scroll up/down through pages like a PDF
/// reader, with a shared zoom level. Drawing happens directly on whichever
/// page is under the pointer.
class ContinuousCanvas extends StatefulWidget {
  const ContinuousCanvas({
    super.key,
    required this.pages,
    required this.sizeFor,
    required this.strokesByPage,
    required this.tool,
    required this.color,
    required this.width,
    required this.eraserMode,
    required this.onStrokeCommitted,
    this.strokeStyle = StrokeStyle.solid,
    this.strokeTip = StrokeTip.round,
    this.shapeOptions = const ShapeOptions(),
    this.lassoOptions = const LassoOptions(),
    required this.onErase,
    required this.onPageVisible,
    required this.onCurrentPageChanged,
    required this.backgroundLoader,
    required this.onLassoComplete,
    required this.onSelectionDrag,
    required this.onSelectionDragEnd,
    required this.onClearSelection,
    this.selection,
    this.controller,
    this.eraserRadius = 12,
    this.cachedBackground,
    this.prefetch,
    this.elementsFor,
    this.imageBytesFor,
    this.selectedElementId,
    this.onSelectElement,
    this.onElementTransform,
    this.onElementRotate,
  });

  final List<NotePage> pages;
  final Size Function(NotePage) sizeFor;
  final Map<String, List<InkStroke>> strokesByPage;
  final ToolType tool;
  final int color;
  final double width;
  final StrokeStyle strokeStyle;
  final StrokeTip strokeTip;
  final ShapeOptions shapeOptions;
  final LassoOptions lassoOptions;
  final EraserMode eraserMode;
  final void Function(String pageId, InkStroke stroke) onStrokeCommitted;
  final void Function(String pageId, Set<String> ids) onErase;
  final void Function(String pageId) onPageVisible;
  final ValueChanged<int> onCurrentPageChanged;
  final Future<ui.Image?> Function(NotePage page) backgroundLoader;

  /// Returns an already-cached image for a page (no work), so a tile can paint
  /// something immediately instead of flashing white while it renders.
  final ui.Image? Function(NotePage page)? cachedBackground;

  /// Asked to render upcoming pages ahead of the scroll position.
  final void Function(List<NotePage> pages)? prefetch;

  /// Lasso finished: the outline in content coordinates for that page.
  final void Function(String pageId, List<Offset> lasso) onLassoComplete;
  final void Function(Offset offset) onSelectionDrag;
  final VoidCallback onSelectionDragEnd;
  final VoidCallback onClearSelection;
  final LassoSelection? selection;

  final ContinuousCanvasController? controller;
  final double eraserRadius;

  /// Image/text elements for a page, and their bytes.
  final List<CanvasElement> Function(String pageId)? elementsFor;
  final Future<Uint8List?> Function(String assetId)? imageBytesFor;
  final String? selectedElementId;
  final ValueChanged<String?>? onSelectElement;

  /// (elementId, rect, committed) — committed=false while dragging.
  final void Function(String id, Rect rect, bool committed)?
      onElementTransform;

  /// (elementId, radians, committed)
  final void Function(String id, double rotation, bool committed)?
      onElementRotate;

  @override
  State<ContinuousCanvas> createState() => _ContinuousCanvasState();
}

/// Lets the surrounding screen drive the canvas (jump to a page, zoom).
class ContinuousCanvasController extends ChangeNotifier {
  _ContinuousCanvasState? _state;
  double _zoomValue = 1;

  void _attach(_ContinuousCanvasState s) => _state = s;
  void _detach(_ContinuousCanvasState s) {
    if (identical(_state, s)) _state = null;
  }

  /// Called by the canvas whenever the zoom level changes (buttons, slider,
  /// Ctrl+wheel) so any UI bound to [zoom] stays in sync.
  void _publishZoom(double z) {
    if ((z - _zoomValue).abs() < 0.0001) return;
    _zoomValue = z;
    notifyListeners();
  }

  /// Current zoom multiplier; 1.0 == one whole page fits the viewport.
  double get zoom => _zoomValue;

  void jumpToPage(int index) => _state?._jumpToPage(index);
  void zoomIn() => _state?._zoomBy(1.2);
  void zoomOut() => _state?._zoomBy(1 / 1.2);
  void setZoom(double z) => _state?._setZoom(z);
  void fitPage() => _state?._setZoom(1);
}

class _ContinuousCanvasState extends State<ContinuousCanvas> {
  final ScrollController _vertical = ScrollController();
  final ScrollController _horizontal = ScrollController();

  /// User zoom multiplier; 1.0 == one whole page fits the viewport.
  double _zoom = 1;
  double _baseScale = 1;
  Size _viewport = Size.zero;
  bool _ctrlHeld = false;

  // Live stroke being drawn, in page coordinates.
  String? _activePageId;
  List<StrokePoint> _active = const [];
  int _activePointer = -1;

  double get _scale => _baseScale * _zoom;

  /// Tools that consume one-pointer drags on the page (so the view must not
  /// scroll underneath them).
  bool get _marking =>
      kInkTools.contains(widget.tool) ||
      widget.tool == ToolType.eraser ||
      widget.tool == ToolType.lasso;

  bool get _lassoing => widget.tool == ToolType.lasso;

  bool get _handTool => widget.tool == ToolType.hand;

  bool get _imageTool => widget.tool == ToolType.image;

  /// True when the scroll views' own physics are disabled, meaning this widget
  /// is responsible for wheel scrolling.
  bool get _scrollLocked =>
      _marking || _ctrlHeld || _handTool || _imageTool;

  // Grab-and-pan state for the hand tool.
  bool _panning = false;
  Offset _panLast = Offset.zero;

  // Live pointers, used for two-finger pinch-zoom / pan on touch devices.
  final Map<int, Offset> _pointers = {};
  bool _multiTouch = false;
  Offset _pinchFocal = Offset.zero;
  double _pinchDistance = 1;

  /// When a stylus has been used recently, fingers pan instead of drawing
  /// (palm rejection). Reset if the stylus goes unused for a while.
  DateTime? _lastStylusAt;
  bool get _stylusMode {
    final at = _lastStylusAt;
    return at != null && DateTime.now().difference(at).inMinutes < 5;
  }

  // Lasso in progress / selection drag state.
  List<Offset> _lassoPoints = const [];
  bool _draggingSelection = false;
  Offset _dragStart = Offset.zero;
  Offset? _rectAnchor;

  /// Time the pointer last moved, used by "require hold to snap".
  DateTime _lastMoveAt = DateTime.now();

  @override
  void initState() {
    super.initState();
    widget.controller?._attach(this);
    HardwareKeyboard.instance.addHandler(_onKey);
    _vertical.addListener(_reportCurrentPage);
  }

  @override
  void didUpdateWidget(covariant ContinuousCanvas old) {
    super.didUpdateWidget(old);
    if (old.controller != widget.controller) {
      old.controller?._detach(this);
      widget.controller?._attach(this);
    }
  }

  @override
  void dispose() {
    widget.controller?._detach(this);
    HardwareKeyboard.instance.removeHandler(_onKey);
    _vertical.dispose();
    _horizontal.dispose();
    super.dispose();
  }

  // ---- Multi-touch (pinch zoom + two-finger pan) ---------------------------

  void _onRootDown(PointerDownEvent e) {
    if (e.kind == PointerDeviceKind.stylus ||
        e.kind == PointerDeviceKind.invertedStylus) {
      _lastStylusAt = DateTime.now();
    }
    _pointers[e.pointer] = e.localPosition;
    if (_pointers.length >= 2 && !_multiTouch) {
      // A second finger arrived: abandon any nascent stroke and switch to
      // pinch/pan so two fingers always navigate, whatever tool is active.
      _multiTouch = true;
      _activePointer = -1;
      _panning = false;
      if (_active.isNotEmpty || _lassoPoints.isNotEmpty) {
        setState(() {
          _active = const [];
          _lassoPoints = const [];
          _activePageId = null;
        });
      }
      _resetPinchBaseline();
    }
  }

  void _onRootMove(PointerMoveEvent e) {
    if (!_pointers.containsKey(e.pointer)) return;
    _pointers[e.pointer] = e.localPosition;
    if (_multiTouch && _pointers.length >= 2) _updatePinch();
  }

  void _onRootUp(PointerEvent e) {
    _pointers.remove(e.pointer);
    if (_pointers.length < 2) {
      _multiTouch = false;
      // Keep the gesture "locked" until every finger lifts, so the remaining
      // finger doesn't suddenly start drawing mid-gesture.
      if (_pointers.isNotEmpty) _activePointer = -2;
    }
    if (_pointers.isEmpty && _activePointer == -2) _activePointer = -1;
  }

  void _resetPinchBaseline() {
    final pts = _pointers.values.toList();
    if (pts.length < 2) return;
    _pinchFocal = (pts[0] + pts[1]) / 2;
    _pinchDistance =
        (pts[0] - pts[1]).distance.clamp(1.0, double.infinity).toDouble();
  }

  void _updatePinch() {
    final pts = _pointers.values.toList();
    if (pts.length < 2) return;
    final focal = (pts[0] + pts[1]) / 2;
    final dist =
        (pts[0] - pts[1]).distance.clamp(1.0, double.infinity).toDouble();

    // Pan by how far the fingers moved together...
    _panBy(focal - _pinchFocal);
    // ...and zoom by how far they spread apart.
    final factor = dist / _pinchDistance;
    if ((factor - 1).abs() > 0.005) _zoomBy(factor, focal: focal);

    _pinchFocal = focal;
    _pinchDistance = dist;
  }

  /// Drags the view by [delta] (screen pixels), both axes at once.
  void _panBy(Offset delta) {
    if (_vertical.hasClients) {
      final v = (_vertical.offset - delta.dy)
          .clamp(0.0, _vertical.position.maxScrollExtent);
      _vertical.jumpTo(v);
    }
    if (_horizontal.hasClients) {
      final h = (_horizontal.offset - delta.dx)
          .clamp(0.0, _horizontal.position.maxScrollExtent);
      _horizontal.jumpTo(h);
    }
  }

  /// Re-reads the real modifier state (guards against a missed key-up).
  void _syncModifiers() {
    final held = HardwareKeyboard.instance.isControlPressed ||
        HardwareKeyboard.instance.isMetaPressed;
    if (held != _ctrlHeld && mounted) setState(() => _ctrlHeld = held);
  }

  bool _onKey(KeyEvent event) {
    final held = HardwareKeyboard.instance.isControlPressed ||
        HardwareKeyboard.instance.isMetaPressed;
    if (held != _ctrlHeld && mounted) setState(() => _ctrlHeld = held);
    return false;
  }

  // ---- Geometry ------------------------------------------------------------

  /// Full sheet size for a page, including any extendable margin area.
  Size _sheetSize(NotePage page) =>
      page.marginSpec.outerSize(widget.sizeFor(page));

  /// Scale at which a whole page fits the viewport (zoom == 1).
  void _computeBaseScale(Size viewport) {
    if (widget.pages.isEmpty) return;
    final first = _sheetSize(widget.pages.first);
    final sw = viewport.width / first.width;
    final sh = viewport.height / first.height;
    _baseScale = (sw < sh ? sw : sh) * 0.94;
  }

  double _itemHeight(int index) =>
      _sheetSize(widget.pages[index]).height * _scale + _kPageGap;

  double _offsetOfPage(int index) {
    var offset = _kPageGap;
    for (var i = 0; i < index; i++) {
      offset += _itemHeight(i);
    }
    return offset;
  }

  double get _contentWidth {
    var maxW = 0.0;
    for (final p in widget.pages) {
      final w = _sheetSize(p).width * _scale;
      if (w > maxW) maxW = w;
    }
    return maxW + 32 > _viewport.width ? maxW + 32 : _viewport.width;
  }

  void _jumpToPage(int index) {
    if (index < 0 || index >= widget.pages.length) return;
    if (!_vertical.hasClients) return;
    final target = _offsetOfPage(index)
        .clamp(0.0, _vertical.position.maxScrollExtent);
    _vertical.jumpTo(target);
    widget.onCurrentPageChanged(index);
  }

  void _reportCurrentPage() {
    if (!_vertical.hasClients || widget.pages.isEmpty) return;
    final centre = _vertical.offset + _viewport.height / 2;
    var acc = _kPageGap;
    for (var i = 0; i < widget.pages.length; i++) {
      acc += _itemHeight(i);
      if (centre < acc) {
        widget.onCurrentPageChanged(i);
        return;
      }
    }
    widget.onCurrentPageChanged(widget.pages.length - 1);
  }

  // ---- Zoom ----------------------------------------------------------------

  void _setZoom(double target, {Offset? focal}) {
    final clamped = target.clamp(0.25, 8.0).toDouble();
    if ((clamped - _zoom).abs() < 0.0001) return;
    final ratio = clamped / _zoom;

    final anchorY = focal?.dy ?? _viewport.height / 2;
    final anchorX = focal?.dx ?? _viewport.width / 2;
    final oldV = _vertical.hasClients ? _vertical.offset : 0.0;
    final oldH = _horizontal.hasClients ? _horizontal.offset : 0.0;

    setState(() => _zoom = clamped);
    widget.controller?._publishZoom(clamped);

    // Keep the point under the cursor roughly stable after the relayout.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (_vertical.hasClients) {
        final target = ((oldV + anchorY) * ratio - anchorY)
            .clamp(0.0, _vertical.position.maxScrollExtent);
        _vertical.jumpTo(target);
      }
      if (_horizontal.hasClients) {
        final target = ((oldH + anchorX) * ratio - anchorX)
            .clamp(0.0, _horizontal.position.maxScrollExtent);
        _horizontal.jumpTo(target);
      }
    });
  }

  void _zoomBy(double factor, {Offset? focal}) =>
      _setZoom(_zoom * factor, focal: focal);

  void _onPointerSignal(PointerSignalEvent event) {
    // On web, the engine turns Ctrl+wheel into a scale event (browsers reserve
    // that gesture for pinch-zoom), so handle both forms.
    if (event is PointerScaleEvent) {
      if (event.scale != 1.0) {
        _zoomBy(event.scale, focal: event.localPosition);
      }
      return;
    }
    if (event is! PointerScrollEvent) return;
    final zoomHeld = HardwareKeyboard.instance.isControlPressed ||
        HardwareKeyboard.instance.isMetaPressed;
    if (zoomHeld) {
      // Smooth, proportional zoom rather than fixed steps.
      final factor = math.exp(-event.scrollDelta.dy / 220);
      _zoomBy(factor, focal: event.localPosition);
    } else if (_scrollLocked) {
      // Physics are off (hand tool / marking tool), so drive scrolling here —
      // both axes, so a horizontal wheel or shift+wheel pans sideways too.
      if (_vertical.hasClients && event.scrollDelta.dy != 0) {
        final target = (_vertical.offset + event.scrollDelta.dy)
            .clamp(0.0, _vertical.position.maxScrollExtent);
        _vertical.jumpTo(target);
      }
      if (_horizontal.hasClients && event.scrollDelta.dx != 0) {
        final target = (_horizontal.offset + event.scrollDelta.dx)
            .clamp(0.0, _horizontal.position.maxScrollExtent);
        _horizontal.jumpTo(target);
      }
    }
  }

  // ---- Drawing -------------------------------------------------------------

  /// Whether [local] (sheet coordinates) lands on one of the page's images.
  ///
  /// The picture's own gesture detector handles the interaction; this is only
  /// so the canvas knows to keep its hands off.
  bool _hitsElement(Offset local, NotePage page) {
    final elements = widget.elementsFor?.call(page.id) ?? const [];
    if (elements.isEmpty) return false;
    final point = _toContent(local, page);
    for (final element in elements) {
      final rect = Rect.fromLTWH(
        element.x,
        element.y,
        element.width,
        element.height,
      ).inflate(12 / (_scale <= 0 ? 1 : _scale));
      if (rect.contains(point)) return true;
    }
    return false;
  }

  /// Converts a pointer position on the sheet into content coordinates.
  /// Strokes are stored relative to the original content origin, so they stay
  /// locked to the page when extendable margins grow or shrink.
  Offset _toContent(Offset local, NotePage page) =>
      (local / _scale) - page.marginSpec.contentOffset;

  void _onPageDown(PointerDownEvent e, NotePage page) {
    // Modifier state can go stale if the browser/app misses a key-up (e.g.
    // after Ctrl+wheel zoom), which would otherwise leave scrolling locked.
    _syncModifiers();

    // Two fingers down: the root handler is driving pinch/pan.
    if (_multiTouch || _activePointer == -2) return;

    // Tapping the page (rather than a picture) dismisses the current image
    // selection. If the tap did land on an image, that image's own gesture
    // recogniser re-selects it a moment later, so this is safe to do eagerly.
    if (_imageTool && widget.selectedElementId != null) {
      widget.onSelectElement?.call(null);
    }

    // Palm rejection: once a stylus is in use, fingers pan rather than mark.
    final fingerWhileStylus =
        e.kind == PointerDeviceKind.touch && _stylusMode;

    // With the hand tool, a drag that starts on a picture belongs to that
    // picture; panning the page as well would move both at once.
    if (_handTool && _hitsElement(e.localPosition, page)) return;

    if (_handTool || fingerWhileStylus) {
      if (_activePointer != -1) return;
      _activePointer = e.pointer;
      _panning = true;
      _panLast = e.position;
      return;
    }
    if (!_marking || _activePointer != -1) return;
    _activePointer = e.pointer;
    final p = _toContent(e.localPosition, page);

    if (_lassoing) {
      final sel = widget.selection;
      // Tapping inside an existing selection starts a move; otherwise a new
      // lasso begins (and any old selection is dropped).
      if (sel != null && sel.pageId == page.id && sel.hitTest(p)) {
        _draggingSelection = true;
        _dragStart = p - sel.offset;
        return;
      }
      widget.onClearSelection();
      _rectAnchor =
          widget.lassoOptions.mode == LassoMode.rectangular ? p : null;
      setState(() {
        _activePageId = page.id;
        _lassoPoints = [p];
      });
      return;
    }

    if (widget.tool == ToolType.eraser) {
      _eraseAt(page, p);
    } else {
      setState(() {
        _activePageId = page.id;
        _active = [StrokePoint(p.dx, p.dy, e.pressure)];
      });
    }
  }

  void _onPageMove(PointerMoveEvent e, NotePage page) {
    if (_multiTouch) return;
    if (e.pointer != _activePointer) return;

    if (_panning) {
      _panBy(e.position - _panLast);
      _panLast = e.position;
      return;
    }
    final p = _toContent(e.localPosition, page);

    if (_lassoing) {
      if (_draggingSelection) {
        widget.onSelectionDrag(p - _dragStart);
      } else if (_activePageId == page.id) {
        final anchor = _rectAnchor;
        setState(() {
          _lassoPoints = anchor == null
              ? [..._lassoPoints, p]
              : _rectOutline(anchor, p);
        });
      }
      return;
    }

    if (widget.tool == ToolType.eraser) {
      _eraseAt(page, p);
    } else if (_activePageId == page.id) {
      _lastMoveAt = DateTime.now();
      setState(() => _active = [..._active, StrokePoint(p.dx, p.dy, e.pressure)]);
    }
  }

  /// Four corners of the rectangle between [a] and [b].
  static List<Offset> _rectOutline(Offset a, Offset b) => [
        a,
        Offset(b.dx, a.dy),
        b,
        Offset(a.dx, b.dy),
      ];

  void _onPageUp(PointerEvent e, NotePage page) {
    if (e.pointer != _activePointer) return;
    _activePointer = -1;

    if (_panning) {
      _panning = false;
      return;
    }

    if (_lassoing) {
      if (_draggingSelection) {
        _draggingSelection = false;
        widget.onSelectionDragEnd();
      } else {
        final lasso = _lassoPoints;
        _rectAnchor = null;
        setState(() {
          _lassoPoints = const [];
          _activePageId = null;
        });
        if (lasso.length > 2) widget.onLassoComplete(page.id, lasso);
      }
      return;
    }

    if (widget.tool == ToolType.eraser || _active.isEmpty) {
      setState(() {
        _active = const [];
        _activePageId = null;
      });
      return;
    }

    // The shape tool snaps the freehand outline to a clean geometric shape.
    // With "require hold to snap" the pointer must pause before lifting.
    var points = _active;
    var filled = false;
    if (widget.tool == ToolType.shape) {
      final held = DateTime.now().difference(_lastMoveAt).inMilliseconds > 350;
      if (!widget.shapeOptions.requireHoldToSnap || held) {
        points = ShapeRecognizer.recognize(_active);
        filled = widget.shapeOptions.fillColor;
      }
    }

    final stroke = InkStroke(
      id: 'pending',
      tool: widget.tool,
      color: widget.color,
      width: widget.width,
      points: points,
      style: widget.strokeStyle,
      filled: filled,
      tip: widget.strokeTip,
    );
    widget.onStrokeCommitted(page.id, stroke);
    setState(() {
      _active = const [];
      _activePageId = null;
    });
  }

  void _eraseAt(NotePage page, Offset p) {
    final r = widget.eraserRadius / _scale;
    final r2 = r * r;
    final hits = <String>{};
    for (final s in widget.strokesByPage[page.id] ?? const <InkStroke>[]) {
      if (widget.eraserMode == EraserMode.highlighterOnly &&
          s.tool != ToolType.highlighter) {
        continue;
      }
      if (!s.bounds.inflate(r).contains(p)) continue;
      for (final pt in s.points) {
        if ((pt.offset - p).distanceSquared <= r2) {
          hits.add(s.id);
          break;
        }
      }
    }
    if (hits.isNotEmpty) widget.onErase(page.id, hits);
  }

  // ---- Build ---------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    if (widget.pages.isEmpty) {
      return const Center(child: Text('No pages'));
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final vp = constraints.biggest;
        if (vp != _viewport) {
          _viewport = vp;
          _computeBaseScale(vp);
        }
        // The hand tool pans manually (below) so it can move both axes at
        // once; marking tools must not scroll the view out from under them.
        final lockScroll = _scrollLocked;
        return MouseRegion(
          cursor: _cursorForTool(),
          child: Listener(
            onPointerSignal: _onPointerSignal,
            onPointerDown: _onRootDown,
            onPointerMove: _onRootMove,
            onPointerUp: _onRootUp,
            onPointerCancel: _onRootUp,
            child: Scrollbar(
              controller: _vertical,
              child: SingleChildScrollView(
                controller: _horizontal,
                scrollDirection: Axis.horizontal,
                physics: lockScroll
                    ? const NeverScrollableScrollPhysics()
                    : null,
                child: SizedBox(
                  width: _contentWidth,
                  height: vp.height,
                  child: ListView.builder(
                    controller: _vertical,
                    physics: lockScroll
                        ? const NeverScrollableScrollPhysics()
                        : null,
                    padding: const EdgeInsets.only(
                        top: _kPageGap, bottom: _kPageGap * 4),
                    itemCount: widget.pages.length,
                    itemBuilder: (context, index) {
                      final page = widget.pages[index];
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        // Load this page's ink as it scrolls into view...
                        widget.onPageVisible(page.id);
                        // ...and start rendering the next few pages so they
                        // are ready before the user reaches them.
                        final ahead = widget.pages.sublist(
                          (index + 1).clamp(0, widget.pages.length),
                          (index + 4).clamp(0, widget.pages.length),
                        );
                        if (ahead.isNotEmpty) widget.prefetch?.call(ahead);
                      });
                      final size = widget.sizeFor(page);
                      return Padding(
                        padding:
                            const EdgeInsets.only(bottom: _kPageGap),
                        child: Center(
                          child: _PageTile(
                            page: page,
                            baseSize: size,
                            scale: _scale,
                            strokes:
                                widget.strokesByPage[page.id] ?? const [],
                            active:
                                _activePageId == page.id ? _active : const [],
                            lasso: _activePageId == page.id
                                ? _lassoPoints
                                : const [],
                            selection: widget.selection?.pageId == page.id
                                ? widget.selection
                                : null,
                            tool: widget.tool,
                            color: widget.color,
                            width: widget.width,
                            strokeStyle: widget.strokeStyle,
                            strokeTip: widget.strokeTip,
                            elements:
                                widget.elementsFor?.call(page.id) ?? const [],
                            imageBytesFor: widget.imageBytesFor,
                            selectedElementId: widget.selectedElementId,
                            onSelectElement: widget.onSelectElement,
                            onElementTransform: widget.onElementTransform,
                            onElementRotate: widget.onElementRotate,
                            // Canva-style: pictures are clickable whenever
                            // you're not holding a drawing tool, so the Hand
                            // (default) tool selects and moves them.
                            imagesInteractive: _imageTool || _handTool,
                            backgroundLoader: widget.backgroundLoader,
                            cachedBackground: widget.cachedBackground,
                            onPointerDown: (e) => _onPageDown(e, page),
                            onPointerMove: (e) => _onPageMove(e, page),
                            onPointerUp: (e) => _onPageUp(e, page),
                            pageNumber: index + 1,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  MouseCursor _cursorForTool() {
    switch (widget.tool) {
      case ToolType.hand:
        return SystemMouseCursors.grab;
      case ToolType.pen:
      case ToolType.pencil:
      case ToolType.highlighter:
      case ToolType.eraser:
        return SystemMouseCursors.precise;
      default:
        return SystemMouseCursors.basic;
    }
  }
}

/// A single page rendered at [scale], with its background, ink and live stroke.
class _PageTile extends StatefulWidget {
  const _PageTile({
    required this.page,
    required this.baseSize,
    required this.scale,
    required this.strokes,
    required this.active,
    required this.lasso,
    required this.selection,
    required this.tool,
    required this.color,
    required this.width,
    required this.strokeStyle,
    required this.strokeTip,
    required this.elements,
    required this.imageBytesFor,
    required this.selectedElementId,
    required this.onSelectElement,
    required this.onElementTransform,
    required this.onElementRotate,
    required this.imagesInteractive,
    required this.backgroundLoader,
    required this.cachedBackground,
    required this.onPointerDown,
    required this.onPointerMove,
    required this.onPointerUp,
    required this.pageNumber,
  });

  final NotePage page;

  /// Original content size (before extendable margins add space).
  final Size baseSize;
  final double scale;
  final List<InkStroke> strokes;
  final List<StrokePoint> active;
  final List<Offset> lasso;
  final LassoSelection? selection;
  final ToolType tool;
  final int color;
  final double width;
  final StrokeStyle strokeStyle;
  final StrokeTip strokeTip;
  final List<CanvasElement> elements;
  final Future<Uint8List?> Function(String assetId)? imageBytesFor;
  final String? selectedElementId;
  final ValueChanged<String?>? onSelectElement;
  final void Function(String id, Rect rect, bool committed)?
      onElementTransform;
  final void Function(String id, double rotation, bool committed)?
      onElementRotate;
  final bool imagesInteractive;
  final Future<ui.Image?> Function(NotePage) backgroundLoader;
  final ui.Image? Function(NotePage)? cachedBackground;
  final ValueChanged<PointerDownEvent> onPointerDown;
  final ValueChanged<PointerMoveEvent> onPointerMove;
  final ValueChanged<PointerEvent> onPointerUp;
  final int pageNumber;

  @override
  State<_PageTile> createState() => _PageTileState();
}

class _PageTileState extends State<_PageTile> {
  ui.Image? _background;
  bool _loading = false;

  bool get _hasBackground =>
      widget.page.pdfAssetId != null || widget.page.bgAssetId != null;

  @override
  void initState() {
    super.initState();
    // Paint whatever is already cached (full image or thumbnail) right away,
    // so a fast scroll shows content instead of a white page.
    _background = widget.cachedBackground?.call(widget.page);
    _load();
  }

  Future<void> _load() async {
    if (!_hasBackground) return;
    if (_background == null) setState(() => _loading = true);
    try {
      final img = await widget.backgroundLoader(widget.page);
      if (mounted) {
        setState(() {
          _background = img;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final margins = widget.page.marginSpec;
    final sheet = margins.outerSize(widget.baseSize);
    final offset = margins.contentOffset;
    final w = sheet.width * widget.scale;
    final h = sheet.height * widget.scale;
    return Listener(
      behavior: HitTestBehavior.opaque,
      onPointerDown: widget.onPointerDown,
      onPointerMove: widget.onPointerMove,
      onPointerUp: widget.onPointerUp,
      onPointerCancel: widget.onPointerUp,
      child: Container(
        width: w,
        height: h,
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.16),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        clipBehavior: Clip.hardEdge,
        child: FittedBox(
          fit: BoxFit.fill,
          child: SizedBox(
            width: sheet.width,
            height: sheet.height,
            child: Stack(
              children: [
                RepaintBoundary(
                  child: CustomPaint(
                    size: sheet,
                    painter: _background != null
                        ? BackgroundPainter(
                            image: _background!,
                            margins: margins,
                            baseSize: widget.baseSize,
                          )
                        : PaperPainter(
                            template: widget.page.template,
                            paperColor: widget.page.paperColor,
                            margins: margins,
                            baseSize: widget.baseSize,
                          ),
                  ),
                ),
                if (widget.elements.isNotEmpty &&
                    widget.imageBytesFor != null)
                  Positioned.fill(
                    child: ImageLayer(
                      elements: widget.elements,
                      bytesFor: widget.imageBytesFor!,
                      // Layout is in content units (inside the FittedBox), but
                      // pointer deltas arrive in screen pixels.
                      dragScale: widget.scale,
                      offset: offset,
                      interactive: widget.imagesInteractive,
                      selectedId: widget.selectedElementId,
                      onSelect: (id) => widget.onSelectElement?.call(id),
                      onTransform: (id, r) =>
                          widget.onElementTransform?.call(id, r, false),
                      onTransformEnd: (id, r) =>
                          widget.onElementTransform?.call(id, r, true),
                      onRotate: (id, a, c) =>
                          widget.onElementRotate?.call(id, a, c),
                    ),
                  ),
                RepaintBoundary(
                  child: CustomPaint(
                    size: sheet,
                    painter: CommittedInkPainter(
                      widget.strokes,
                      offset: offset,
                      shiftedIds: widget.selection?.strokeIds,
                      shift: widget.selection?.offset ?? Offset.zero,
                    ),
                  ),
                ),
                CustomPaint(
                  size: sheet,
                  painter: ActiveStrokePainter(
                    points: widget.active,
                    tool: widget.tool,
                    color: widget.color,
                    width: widget.width,
                    style: widget.strokeStyle,
                    tip: widget.strokeTip,
                    offset: offset,
                  ),
                ),
                CustomPaint(
                  size: sheet,
                  painter: LassoPainter(
                    lasso: widget.lasso,
                    selection: widget.selection,
                    offset: offset,
                  ),
                ),
                if (_loading)
                  const Center(
                    child: SizedBox(
                      width: 48,
                      height: 48,
                      child: CircularProgressIndicator(strokeWidth: 3),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
