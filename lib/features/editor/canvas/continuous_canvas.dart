import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/db/database.dart';
import '../../../core/ink/ink_stroke.dart';
import '../../../core/models/enums.dart';
import '../../../core/models/text_element.dart';
import '../ink/shape_recognizer.dart';
import '../pages/background_painter.dart';
import '../pages/paper_painter.dart';
import '../providers.dart';
import '../state/lasso_selection.dart';
import '../state/tool_settings.dart';
import 'image_layer.dart';
import 'ink_painters.dart';
import 'lasso_painter.dart';
import 'text_layer.dart';

const double _kPageGap = 16;

/// Splits a scaled-axis delta into unscaled sheet coordinate + leftover pixels.
///
/// Page sheets scale with zoom; [_kPageGap] gutters and the centred empty
/// space around a row do not. Overflow past the sheet is kept as screen pixels
/// so it is not multiplied by the zoom ratio.
(double sheet, double extra) _unscaleAxis(
  double delta,
  double extent,
  double scale,
) {
  final scaled = extent * scale;
  if (delta < 0) return (0.0, delta);
  if (delta > scaled) return (extent, delta - scaled);
  if (scale <= 0) return (0.0, 0.0);
  return (delta / scale, 0.0);
}

/// A document point that must stay under a viewport location across zoom.
class _ZoomAnchor {
  const _ZoomAnchor({
    required this.pageIndex,
    required this.sheet,
    required this.extra,
    required this.viewport,
  });

  final int pageIndex;

  /// Unscaled coordinates on the page sheet (clamped to the sheet).
  final Offset sheet;

  /// Overflow into non-scaling gutters, in screen pixels.
  final Offset extra;

  /// Viewport-local point that should stay on [sheet] + [extra].
  final Offset viewport;
}

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
    this.thumbnailLoader,
    this.onScrollSettled,
    this.elementsFor,
    this.imageBytesFor,
    this.selectedElementId,
    this.onSelectElement,
    this.onElementTransform,
    this.onElementRotate,
    this.onDeleteElement,
    this.onShiftElementZ,
    this.onCreateElement,
    this.onEditElement,
    this.editingElementId,
    this.onChangeText,
    this.onEndEditText,
    this.palmRejection = true,
    this.twoPageSpread = false,
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
  final Future<ui.Image?> Function(NotePage page, double viewScale)
      backgroundLoader;

  /// Returns an already-cached image for a page (no work), so a tile can paint
  /// something immediately instead of flashing white while it renders.
  final ui.Image? Function(NotePage page)? cachedBackground;

  /// Asked to render upcoming pages ahead of the scroll position.
  final void Function(List<NotePage> pages)? prefetch;

  /// Cheap preview used while scrolling. Full-resolution loads wait until
  /// [onScrollSettled].
  final Future<ui.Image?> Function(NotePage page)? thumbnailLoader;

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
  /// [pageId] is set on commit when the object was dropped on a different page.
  final void Function(String id, Rect rect, bool committed, {String? pageId})?
  onElementTransform;

  /// (elementId, radians, committed)
  final void Function(String id, double rotation, bool committed)?
  onElementRotate;

  /// Deletes an image/sticker element from its delete grip.
  final ValueChanged<String>? onDeleteElement;

  /// Bring the object forward (true) or send it backward (false) in z-order.
  final void Function(String id, bool forward)? onShiftElementZ;

  /// Tapping an empty spot with the Text/Sticky tool: (pageId, content point,
  /// isSticky). The screen inserts the element and opens it for editing.
  final void Function(String pageId, Offset at, bool sticky)? onCreateElement;

  /// Double-tapping a text/sticky element (or tapping the toolbar pencil) opens
  /// it for inline editing.
  final ValueChanged<String>? onEditElement;

  /// The element currently open for inline text entry, if any.
  final String? editingElementId;

  /// Persists a text/sticky element's content or formatting as it's edited.
  final void Function(String id, TextElementData data)? onChangeText;

  /// The inline text field lost focus / the user tapped Done.
  final VoidCallback? onEndEditText;

  /// When true, a finger resting on the page is ignored once a stylus is in
  /// use (fingers pan instead of mark). Off means every touch draws.
  final bool palmRejection;

  /// Renders consecutive pages side by side. Used by landscape tablet layout.
  final bool twoPageSpread;

  /// Fired after pan/zoom/wheel input has been idle briefly, so the
  /// background service can drop fling-queued prefetch work.
  final VoidCallback? onScrollSettled;

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

  /// Prefix sums of unscaled row sheet heights. Scaled positions are
  /// `offset[r] * _scale + r * _kPageGap` so pinch does not rebuild this.
  List<double>? _rowOffsets;
  double? _unscaledMaxSheetWidth;
  double _maxRowGap = 0;
  double? _uniformUnscaledHeight;
  int _layoutLen = -1;
  bool _layoutSpread = false;
  int _layoutPagesIdentity = 0;

  Timer? _settleTimer;
  bool _scrollSettled = true;

  /// Tools that consume one-pointer drags on the page (so the view must not
  /// scroll underneath them).
  bool get _marking =>
      kInkTools.contains(widget.tool) ||
      widget.tool == ToolType.eraser ||
      widget.tool == ToolType.lasso;

  bool get _lassoing => widget.tool == ToolType.lasso;

  bool get _handTool => widget.tool == ToolType.hand;

  bool get _imageTool => widget.tool == ToolType.image;

  bool get _textTool => widget.tool == ToolType.text;

  bool get _stickyTool => widget.tool == ToolType.sticky;

  /// Tools that place/move on-page objects (images, text, sticky notes).
  bool get _elementTool => _imageTool || _textTool || _stickyTool;

  /// True when a one-finger drag should pan the document instead of drawing.
  bool get _canOneFingerPan {
    if (_handTool || _elementTool) return true;
    return widget.palmRejection &&
        _stylusMode &&
        _downKind == PointerDeviceKind.touch;
  }

  Offset? _panOrigin;
  PointerDeviceKind? _downKind;

  // Grab-and-pan state for the hand tool.
  bool _panning = false;
  Offset _panLast = Offset.zero;

  // Live pointers, used for two-finger pinch-zoom / pan on touch devices.
  final Map<int, Offset> _pointers = {};
  bool _multiTouch = false;
  bool _elementPinch = false;
  String? _elPinchId;
  int _elPinchPage = 0;
  Rect _elPinchStartRect = Rect.zero;
  double _elPinchStartRot = 0;
  Offset _elPinchStartFocal = Offset.zero;
  double _elPinchStartDist = 1;
  double _elPinchStartAngle = 0;
  Rect? _elPinchLiveRect;
  double? _elPinchLiveRot;
  double? _elPinchStartFont;
  Offset _pinchFocal = Offset.zero;
  double _pinchDistance = 1;

  /// Empty-space tap tracking so we can deselect on pointer *up* instead of
  /// down. Clearing on down disposed the delete/rotate grips before their
  /// GestureDetector could fire.
  Offset? _downGlobal;
  Offset? _downContent;
  bool _downOnElement = false;
  int? _downPointer;

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
    _vertical.addListener(_onScrollActivity);
    _horizontal.addListener(_onScrollActivity);
  }

  @override
  void didUpdateWidget(covariant ContinuousCanvas old) {
    super.didUpdateWidget(old);
    if (old.controller != widget.controller) {
      old.controller?._detach(this);
      widget.controller?._attach(this);
    }
    if (old.twoPageSpread != widget.twoPageSpread && _viewport != Size.zero) {
      _computeBaseScale(_viewport);
      widget.controller?._publishZoom(_zoom);
    }
  }

  @override
  void dispose() {
    widget.controller?._detach(this);
    HardwareKeyboard.instance.removeHandler(_onKey);
    _settleTimer?.cancel();
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
    if (_pointers.length == 1) {
      _panOrigin = e.position;
      _panLast = e.position;
      _downKind = e.kind;
      // Do not clear _downOnElement here. The page Listener is inner, so
      // _onPageDown already ran and recorded whether this finger landed on
      // a sticker/text/image. Resetting would let one-finger pan steal the
      // drag: the object and the page both move, and the sticker jumps
      // ahead of the finger.
      if (_pointerHitsAnyElement(e.localPosition)) {
        _downOnElement = true;
      }
    }
    if (_pointers.length >= 2 && !_multiTouch && !_elementPinch) {
      if (_beginElementPinch()) {
        return;
      }
      // Otherwise abandon any nascent stroke and switch to pinch/pan so two
      // fingers always navigate, whatever tool is active.
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
    if (_elementPinch) {
      _updateElementPinch();
      return;
    }
    if (_multiTouch && _pointers.length >= 2) {
      _updatePinch();
      return;
    }
    if (_pointers.length < 2) _multiTouch = false;

    // One-finger pan from the root so it still works on the gutter and after
    // zoom (nested scroll views would otherwise eat the vertical drag).
    // Never pan while the finger is on an object — that object owns the drag.
    if (_pointers.length == 1 && _canOneFingerPan && !_downOnElement) {
      final origin = _panOrigin;
      if (origin != null && !_panning) {
        final slop = _handTool ||
                (widget.palmRejection &&
                    _stylusMode &&
                    _downKind == PointerDeviceKind.touch)
            ? 0.0
            : 14.0;
        if ((e.position - origin).distance > slop) {
          _panning = true;
        }
      }
      if (_panning) {
        _panBy(e.position - _panLast);
        _panLast = e.position;
      }
    }
  }

  void _onRootUp(PointerEvent e) {
    _pointers.remove(e.pointer);
    if (_pointers.length < 2) {
      if (_elementPinch) _commitElementPinch();
      _multiTouch = false;
      _elementPinch = false;
      if (_pointers.isNotEmpty) _activePointer = -2;
    }
    if (_pointers.isEmpty) {
      if (_activePointer == -2) _activePointer = -1;
      _panning = false;
      _panOrigin = null;
      _downOnElement = false;
    }
  }

  bool _beginElementPinch() {
    final selected = _findSelectedElement();
    if (selected == null) return false;
    final (element, pageIndex) = selected;
    // Once an object is selected, two fingers resize/rotate it. Page pinch
    // only runs when nothing is selected — otherwise the canvas zoom always
    // wins and stickers feel stuck.
    final pts = _pointers.values
        .map((p) => _viewportToContentAlways(p, pageIndex))
        .toList();
    if (pts.length < 2) return false;
    _elementPinch = true;
    _elPinchId = element.id;
    _elPinchPage = pageIndex;
    _elPinchStartRect = Rect.fromLTWH(
      element.x,
      element.y,
      element.width,
      element.height,
    );
    _elPinchStartRot = element.rotation;
    _elPinchStartFocal = (pts[0] + pts[1]) / 2;
    _elPinchStartDist = (pts[0] - pts[1]).distance.clamp(1.0, double.infinity);
    _elPinchStartAngle = math.atan2(
      pts[1].dy - pts[0].dy,
      pts[1].dx - pts[0].dx,
    );
    _elPinchStartFont =
        (element.type == ElementType.text || element.type == ElementType.sticky)
        ? TextElementData.fromJson(element.data).fontSize
        : null;
    _activePointer = -1;
    _panning = false;
    if (_active.isNotEmpty || _lassoPoints.isNotEmpty) {
      setState(() {
        _active = const [];
        _lassoPoints = const [];
        _activePageId = null;
      });
    }
    return true;
  }

  void _updateElementPinch() {
    final id = _elPinchId;
    if (id == null || _pointers.length < 2) return;
    final pts = _pointers.values
        .map((p) => _viewportToContentAlways(p, _elPinchPage))
        .toList();
    final focal = (pts[0] + pts[1]) / 2;
    final dist = (pts[0] - pts[1]).distance.clamp(1.0, double.infinity);
    final angle = math.atan2(pts[1].dy - pts[0].dy, pts[1].dx - pts[0].dx);
    final factor = dist / _elPinchStartDist;
    final start = _elPinchStartRect;
    final aspect = start.height == 0 ? 1.0 : start.width / start.height;
    final width = (start.width * factor).clamp(24.0, 100000.0);
    final height = width / aspect;
    final next = Rect.fromCenter(
      center: start.center + (focal - _elPinchStartFocal),
      width: width,
      height: height,
    );
    final rotation = _elPinchStartRot + (angle - _elPinchStartAngle);
    setState(() {
      _elPinchLiveRect = next;
      _elPinchLiveRot = rotation;
    });
  }

  void _commitElementPinch() {
    final id = _elPinchId;
    final rect = _elPinchLiveRect;
    final rot = _elPinchLiveRot;
    final startRect = _elPinchStartRect;
    final startFont = _elPinchStartFont;
    _elPinchId = null;
    _elPinchLiveRect = null;
    _elPinchLiveRot = null;
    _elPinchStartFont = null;
    if (id == null || rect == null) return;
    _commitElementTransform(id, rect);
    if (rot != null) widget.onElementRotate?.call(id, rot, true);
    if (startFont != null && startRect.width > 0) {
      final nextFont = TextElementData.clampFontSize(
        startFont * rect.width / startRect.width,
      );
      if ((nextFont - startFont).abs() > 0.05) {
        final selected = _findSelectedElement();
        if (selected != null && selected.$1.id == id) {
          final data = TextElementData.fromJson(selected.$1.data);
          widget.onChangeText?.call(id, data.copyWith(fontSize: nextFont));
        }
      }
    }
    if (mounted) setState(() {});
  }

  (CanvasElement, int)? _findSelectedElement() {
    final id = widget.selectedElementId;
    if (id == null) return null;
    for (var i = 0; i < widget.pages.length; i++) {
      final elements = widget.elementsFor?.call(widget.pages[i].id) ?? const [];
      for (final element in elements) {
        if (element.id == id) return (element, i);
      }
    }
    return null;
  }

  Offset _viewportToContentAlways(Offset local, int index) {
    final origin = _pageOriginInContent(index);
    final sheet = ((local + _scrollOffset) - origin) / _scale;
    return sheet - widget.pages[index].marginSpec.contentOffset;
  }

  void _resetPinchBaseline() {
    final pts = _pointers.values.toList();
    if (pts.length < 2) return;
    _pinchFocal = (pts[0] + pts[1]) / 2;
    _pinchDistance = (pts[0] - pts[1]).distance
        .clamp(1.0, double.infinity)
        .toDouble();
  }

  void _updatePinch() {
    final pts = _pointers.values.toList();
    if (pts.length < 2) return;
    final focal = (pts[0] + pts[1]) / 2;
    final dist = (pts[0] - pts[1]).distance
        .clamp(1.0, double.infinity)
        .toDouble();

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
      final v = (_vertical.offset - delta.dy).clamp(
        0.0,
        _vertical.position.maxScrollExtent,
      );
      _vertical.jumpTo(v);
    }
    if (_horizontal.hasClients) {
      final h = (_horizontal.offset - delta.dx).clamp(
        0.0,
        _horizontal.position.maxScrollExtent,
      );
      _horizontal.jumpTo(h);
    }
  }

  /// Re-reads the real modifier state (guards against a missed key-up).
  void _syncModifiers() {
    final held =
        HardwareKeyboard.instance.isControlPressed ||
        HardwareKeyboard.instance.isMetaPressed;
    if (held != _ctrlHeld && mounted) setState(() => _ctrlHeld = held);
  }

  bool _onKey(KeyEvent event) {
    final held =
        HardwareKeyboard.instance.isControlPressed ||
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
    final second = widget.twoPageSpread && widget.pages.length > 1
        ? _sheetSize(widget.pages[1])
        : Size.zero;
    final spreadWidth = widget.twoPageSpread
        ? first.width + second.width + _kPageGap
        : first.width;
    final spreadHeight = widget.twoPageSpread
        ? math.max(first.height, second.height)
        : first.height;
    final sw = viewport.width / spreadWidth;
    final sh = viewport.height / spreadHeight;
    _baseScale = (sw < sh ? sw : sh) * 0.94;
  }

  int get _rowCount => widget.twoPageSpread
      ? (widget.pages.length + 1) ~/ 2
      : widget.pages.length;

  int _rowForPage(int index) => widget.twoPageSpread ? index ~/ 2 : index;

  void _ensureLayoutCache() {
    final identity = identityHashCode(widget.pages);
    if (_rowOffsets != null &&
        _layoutLen == widget.pages.length &&
        _layoutSpread == widget.twoPageSpread &&
        _layoutPagesIdentity == identity) {
      return;
    }
    _layoutLen = widget.pages.length;
    _layoutSpread = widget.twoPageSpread;
    _layoutPagesIdentity = identity;
    final n = _rowCount;
    final offsets = List<double>.filled(n + 1, 0);
    var maxSheetW = 0.0;
    var maxGap = 0.0;
    var uniform = true;
    double? firstH;
    for (var row = 0; row < n; row++) {
      final h = _unscaledRowHeight(row);
      firstH ??= h;
      if ((h - firstH).abs() > 0.5) uniform = false;
      offsets[row + 1] = offsets[row] + h;
      final firstIndex = widget.twoPageSpread ? row * 2 : row;
      var sheetW = _sheetSize(widget.pages[firstIndex]).width;
      var gap = 0.0;
      final secondIndex = firstIndex + 1;
      if (widget.twoPageSpread && secondIndex < widget.pages.length) {
        sheetW += _sheetSize(widget.pages[secondIndex]).width;
        gap = _kPageGap;
      }
      if (sheetW > maxSheetW) maxSheetW = sheetW;
      if (gap > maxGap) maxGap = gap;
    }
    _rowOffsets = offsets;
    _uniformUnscaledHeight = uniform ? firstH : null;
    _unscaledMaxSheetWidth = maxSheetW;
    _maxRowGap = maxGap;
  }

  double _unscaledRowHeight(int row) {
    final firstIndex = widget.twoPageSpread ? row * 2 : row;
    var height = _sheetSize(widget.pages[firstIndex]).height;
    final secondIndex = firstIndex + 1;
    if (widget.twoPageSpread && secondIndex < widget.pages.length) {
      height = math.max(height, _sheetSize(widget.pages[secondIndex]).height);
    }
    return height;
  }

  /// Content-Y of the start of [row], not including the list's top padding.
  double _scaledRowStart(int row) {
    _ensureLayoutCache();
    return _rowOffsets![row] * _scale + row * _kPageGap;
  }

  double _rowHeight(int row) {
    _ensureLayoutCache();
    final unscaled = _rowOffsets![row + 1] - _rowOffsets![row];
    return unscaled * _scale + _kPageGap;
  }

  double _offsetOfPage(int index) {
    _ensureLayoutCache();
    final row = _rowForPage(index);
    return _kPageGap + _scaledRowStart(row);
  }

  double get _contentWidth => _contentWidthAt(_scale);

  double _contentWidthAt(double scale) {
    _ensureLayoutCache();
    final scaled = (_unscaledMaxSheetWidth ?? 0) * scale + _maxRowGap;
    return scaled + 32 > _viewport.width ? scaled + 32 : _viewport.width;
  }

  /// Analytic [ScrollPosition.maxScrollExtent] at [scale], including the
  /// constant page gaps and ListView padding that do not zoom.
  double _maxVerticalExtentAt(double scale) {
    _ensureLayoutCache();
    if (_viewport.height <= 0) return 0;
    final n = _rowCount;
    final unscaled = n == 0 ? 0.0 : _rowOffsets![n];
    final total =
        unscaled * scale + n * _kPageGap + _kPageGap + _kPageGap * 4;
    return math.max(0.0, total - _viewport.height);
  }

  double _maxHorizontalExtentAt(double scale) {
    if (_viewport.width <= 0) return 0;
    return math.max(0.0, _contentWidthAt(scale) - _viewport.width);
  }

  /// Top-left of a page tile in the scrollable content's coordinate space.
  Offset _pageOriginInContent(int index) {
    final y = _offsetOfPage(index);
    final row = _rowForPage(index);
    final firstIndex = widget.twoPageSpread ? row * 2 : row;
    final firstW = _sheetSize(widget.pages[firstIndex]).width * _scale;
    var rowW = firstW;
    final secondIndex = firstIndex + 1;
    if (widget.twoPageSpread && secondIndex < widget.pages.length) {
      rowW += _kPageGap + _sheetSize(widget.pages[secondIndex]).width * _scale;
    }
    var x = (_contentWidth - rowW) / 2;
    if (widget.twoPageSpread && index == secondIndex) {
      x += firstW + _kPageGap;
    }
    return Offset(x, y);
  }

  Offset get _scrollOffset => Offset(
    _horizontal.hasClients ? _horizontal.offset : 0,
    _vertical.hasClients ? _vertical.offset : 0,
  );

  /// On finger-up, if the object was dragged onto another page, rewrite its
  /// coordinates into that page's content space so it stays visible.
  ({Rect rect, String? pageId}) _resolveDrop(String id, Rect rect) {
    int? srcIndex;
    for (var i = 0; i < widget.pages.length; i++) {
      final elements = widget.elementsFor?.call(widget.pages[i].id) ?? const [];
      if (elements.any((e) => e.id == id)) {
        srcIndex = i;
        break;
      }
    }
    if (srcIndex == null) return (rect: rect, pageId: null);

    final src = widget.pages[srcIndex];
    final centerSheet = rect.center + src.marginSpec.contentOffset;
    final global = _pageOriginInContent(srcIndex) + centerSheet * _scale;

    int? destIndex;
    for (var i = 0; i < widget.pages.length; i++) {
      final origin = _pageOriginInContent(i);
      final size = _sheetSize(widget.pages[i]);
      final pageRect = origin & Size(size.width * _scale, size.height * _scale);
      if (pageRect.contains(global)) {
        destIndex = i;
        break;
      }
    }
    if (destIndex == null || destIndex == srcIndex) {
      final content = widget.sizeFor(src);
      return (rect: _clampToPage(rect, content), pageId: null);
    }

    final dest = widget.pages[destIndex];
    final destOrigin = _pageOriginInContent(destIndex);
    final destSheet = (global - destOrigin) / _scale;
    final destContent = destSheet - dest.marginSpec.contentOffset;
    final placed = Rect.fromCenter(
      center: destContent,
      width: rect.width,
      height: rect.height,
    );
    return (rect: placed, pageId: dest.id);
  }

  /// Keeps enough of [rect] on the page that the object can't vanish into the
  /// gutter if the user dropped it short of the next sheet.
  Rect _clampToPage(Rect rect, Size page) {
    if (page.width <= 0 || page.height <= 0) return rect;
    final minX = 8 - rect.width * 0.4;
    final minY = 8 - rect.height * 0.4;
    final maxX = page.width - 8 - rect.width * 0.6;
    final maxY = page.height - 8 - rect.height * 0.6;
    return Rect.fromLTWH(
      rect.left.clamp(minX, math.max(minX, maxX)),
      rect.top.clamp(minY, math.max(minY, maxY)),
      rect.width,
      rect.height,
    );
  }

  void _commitElementTransform(String id, Rect rect) {
    final drop = _resolveDrop(id, rect);
    widget.onElementTransform?.call(id, drop.rect, true, pageId: drop.pageId);
  }

  void _jumpToPage(int index) {
    if (index < 0 || index >= widget.pages.length) return;
    if (!_vertical.hasClients) return;
    final target = _offsetOfPage(
      index,
    ).clamp(0.0, _vertical.position.maxScrollExtent);
    _vertical.jumpTo(target);
    widget.onCurrentPageChanged(index);
  }

  void _reportCurrentPage() {
    if (!_vertical.hasClients || widget.pages.isEmpty) return;
    final n = _rowCount;
    if (n <= 0) return;
    final row = _rowAtContentY(_vertical.offset + _viewport.height / 2);
    widget.onCurrentPageChanged(widget.twoPageSpread ? row * 2 : row);
  }

  void _onScrollActivity() {
    _reportCurrentPage();
    if (_scrollSettled) {
      setState(() => _scrollSettled = false);
    }
    _scheduleScrollSettle();
  }

  void _scheduleScrollSettle() {
    _settleTimer?.cancel();
    _settleTimer = Timer(const Duration(milliseconds: 80), _onScrollSettled);
  }

  void _onScrollSettled() {
    if (!mounted) return;
    widget.onScrollSettled?.call();
    setState(() => _scrollSettled = true);
    if (!_vertical.hasClients || widget.pages.isEmpty) return;
    final row = _rowAtContentY(_vertical.offset + _viewport.height / 2);
    final index = widget.twoPageSpread ? row * 2 : row;
    final ahead = widget.pages.sublist(
      (index + 1).clamp(0, widget.pages.length),
      (index + 4).clamp(0, widget.pages.length),
    );
    if (ahead.isNotEmpty) widget.prefetch?.call(ahead);
    _debugCheckExtents();
  }

  /// Debug-only: analytic extents must match the laid-out controllers
  /// within a pixel, or a same-frame zoom jumpTo will be corrected later
  /// and the flicker comes back.
  void _debugCheckExtents() {
    assert(() {
      if (!_vertical.hasClients || !_horizontal.hasClients) return true;
      final v = _maxVerticalExtentAt(_scale);
      final h = _maxHorizontalExtentAt(_scale);
      final realV = _vertical.position.maxScrollExtent;
      final realH = _horizontal.position.maxScrollExtent;
      assert(
        (v - realV).abs() < 1.0,
        'vertical extent $v vs laid-out $realV',
      );
      assert(
        (h - realH).abs() < 1.0,
        'horizontal extent $h vs laid-out $realH',
      );
      return true;
    }());
  }

  /// Row whose tile contains [contentY] in scrollable-content coordinates.
  int _rowAtContentY(double contentY) {
    _ensureLayoutCache();
    final n = _rowCount;
    if (n <= 0) return 0;
    final y = contentY - _kPageGap;
    if (y >= _scaledRowStart(n)) return n - 1;
    if (y <= 0) return 0;
    var lo = 0;
    var hi = n - 1;
    while (lo < hi) {
      final mid = (lo + hi + 1) >> 1;
      if (_scaledRowStart(mid) <= y) {
        lo = mid;
      } else {
        hi = mid - 1;
      }
    }
    return lo;
  }

  // ---- Zoom ----------------------------------------------------------------

  void _setZoom(double target, {Offset? focal}) {
    final clamped = target.clamp(0.25, 8.0).toDouble();
    if ((clamped - _zoom).abs() < 0.0001) return;

    final anchorY = focal?.dy ?? _viewport.height / 2;
    final anchorX = focal?.dx ?? _viewport.width / 2;
    final pin = _anchorAt(Offset(anchorX, anchorY));

    setState(() => _zoom = clamped);
    widget.controller?._publishZoom(clamped);

    // jumpTo (forcePixels) must land in this turn, before the dirty build.
    // A post-frame restore paints one frame at the new scale with the old
    // offset, which swaps the ListView's visible range and recreates tiles.
    if (pin != null) _restoreZoomAnchor(pin);
    _reportCurrentPage();
  }

  /// Document point currently under [viewport], in unscaled sheet coordinates.
  _ZoomAnchor? _anchorAt(Offset viewport) {
    if (widget.pages.isEmpty) return null;
    final content = Offset(
      (_horizontal.hasClients ? _horizontal.offset : 0) + viewport.dx,
      (_vertical.hasClients ? _vertical.offset : 0) + viewport.dy,
    );
    final row = _rowAtContentY(content.dy);
    final firstIndex = widget.twoPageSpread ? row * 2 : row;
    var pageIndex = firstIndex;
    if (widget.twoPageSpread) {
      final secondIndex = firstIndex + 1;
      if (secondIndex < widget.pages.length) {
        final firstOrigin = _pageOriginInContent(firstIndex);
        final firstW = _sheetSize(widget.pages[firstIndex]).width * _scale;
        if (content.dx >= firstOrigin.dx + firstW + _kPageGap / 2) {
          pageIndex = secondIndex;
        }
      }
    }
    if (pageIndex < 0 || pageIndex >= widget.pages.length) return null;

    final page = widget.pages[pageIndex];
    final size = _sheetSize(page);
    final origin = _pageOriginInContent(pageIndex);
    final local = content - origin;
    final scale = _scale <= 0 ? 1.0 : _scale;
    final x = _unscaleAxis(local.dx, size.width, scale);
    final y = _unscaleAxis(local.dy, size.height, scale);
    return _ZoomAnchor(
      pageIndex: pageIndex,
      sheet: Offset(x.$1, y.$1),
      extra: Offset(x.$2, y.$2),
      viewport: viewport,
    );
  }

  void _restoreZoomAnchor(_ZoomAnchor pin) {
    if (pin.pageIndex < 0 || pin.pageIndex >= widget.pages.length) return;
    _ensureLayoutCache();
    final origin = _pageOriginInContent(pin.pageIndex);
    final content =
        origin + Offset(pin.sheet.dx * _scale, pin.sheet.dy * _scale) + pin.extra;
    if (_vertical.hasClients) {
      _vertical.jumpTo(
        (content.dy - pin.viewport.dy).clamp(0.0, _maxVerticalExtentAt(_scale)),
      );
    }
    if (_horizontal.hasClients) {
      _horizontal.jumpTo(
        (content.dx - pin.viewport.dx).clamp(
          0.0,
          _maxHorizontalExtentAt(_scale),
        ),
      );
    }
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
    final zoomHeld =
        HardwareKeyboard.instance.isControlPressed ||
        HardwareKeyboard.instance.isMetaPressed;
    if (zoomHeld) {
      // Smooth, proportional zoom rather than fixed steps.
      final factor = math.exp(-event.scrollDelta.dy / 220);
      _zoomBy(factor, focal: event.localPosition);
    } else {
      // Scroll physics stay off so zoomed pages can pan on both axes.
      if (_vertical.hasClients && event.scrollDelta.dy != 0) {
        final target = (_vertical.offset + event.scrollDelta.dy).clamp(
          0.0,
          _vertical.position.maxScrollExtent,
        );
        _vertical.jumpTo(target);
      }
      if (_horizontal.hasClients && event.scrollDelta.dx != 0) {
        final target = (_horizontal.offset + event.scrollDelta.dx).clamp(
          0.0,
          _horizontal.position.maxScrollExtent,
        );
        _horizontal.jumpTo(target);
      }
    }
  }

  // ---- Drawing -------------------------------------------------------------

  /// Whether a pointer in the root Listener's local space is on any object.
  ///
  /// Used as a belt-and-suspenders check so one-finger pan cannot start even
  /// if the page handler's hit test used slightly different coordinates.
  bool _pointerHitsAnyElement(Offset rootLocal) {
    if (widget.elementsFor == null || widget.pages.isEmpty) return false;
    for (var i = 0; i < widget.pages.length; i++) {
      final page = widget.pages[i];
      final origin = _pageOriginInContent(i);
      final sheet = ((rootLocal + _scrollOffset) - origin) / _scale;
      final size = _sheetSize(page);
      if (sheet.dx < -24 ||
          sheet.dy < -24 ||
          sheet.dx > size.width + 24 ||
          sheet.dy > size.height + 24) {
        continue;
      }
      if (_hitsElement(sheet * _scale, page)) return true;
    }
    return false;
  }

  /// Whether [local] (sheet coordinates) lands on a canvas element.
  ///
  /// The picture's own gesture detector handles the interaction; this is only
  /// so the canvas knows to keep its hands off.
  bool _hitsElement(Offset local, NotePage page) {
    final elements = widget.elementsFor?.call(page.id) ?? const [];
    if (elements.isEmpty) return false;
    final point = _toContent(local, page);
    final scale = _scale <= 0 ? 1.0 : _scale;
    for (final element in elements) {
      final pad =
          (element.id == widget.selectedElementId ? 24.0 : 16.0) / scale;
      final rect = Rect.fromLTWH(
        element.x,
        element.y,
        element.width,
        element.height,
      ).inflate(pad);
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

    // Two fingers down: the root handler is driving pinch/pan or an
    // object resize/rotate.
    if (_multiTouch || _elementPinch || _activePointer == -2) return;

    final onElement = _hitsElement(e.localPosition, page);
    _downGlobal = e.position;
    _downContent = _toContent(e.localPosition, page);
    _downOnElement = onElement;
    _downPointer = e.pointer;

    // Text / sticky: a tap places a box; a drag is panned by the root handler.
    if (_textTool || _stickyTool) {
      if (onElement) return;
      return;
    }

    // Selected objects own the pointer so a tap doesn't start a pen stroke.
    if (onElement &&
        (_elementTool || _handTool || widget.selectedElementId != null)) {
      return;
    }

    // Palm rejection: once a stylus is in use, fingers pan rather than mark.
    final fingerWhileStylus =
        widget.palmRejection &&
        e.kind == PointerDeviceKind.touch &&
        _stylusMode;

    if (_handTool && onElement) return;

    if (_handTool || fingerWhileStylus) {
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
      _rectAnchor = widget.lassoOptions.mode == LassoMode.rectangular
          ? p
          : null;
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
    if (_multiTouch || _panning) return;
    if (e.pointer != _activePointer) return;

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
      setState(
        () => _active = [..._active, StrokePoint(p.dx, p.dy, e.pressure)],
      );
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
    if (e.pointer == _downPointer) {
      final moved =
          _downGlobal != null && (e.position - _downGlobal!).distance > 14;
      // A still tap with the text / sticky tool places a new box. A drag
      // was already used to scroll, so it must not create anything.
      if ((_textTool || _stickyTool) &&
          !_downOnElement &&
          !moved &&
          _downContent != null) {
        widget.onCreateElement?.call(page.id, _downContent!, _stickyTool);
      }
      // Image / hand tools: an empty tap drops the selection.
      // Never deselect on pointer-down — that disposed chrome before tap.
      if ((_imageTool || _handTool) &&
          widget.selectedElementId != null &&
          !_downOnElement &&
          !moved) {
        widget.onSelectElement?.call(null);
      }
      _downPointer = null;
      _downGlobal = null;
      _downContent = null;
      _downOnElement = false;
    }

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

  Widget _buildPageTile(int index) {
    final page = widget.pages[index];
    final size = widget.sizeFor(page);
    return _PageTile(
      key: ValueKey(page.id),
      page: page,
      baseSize: size,
      scale: _scale,
      strokes: widget.strokesByPage[page.id] ?? const [],
      active: _activePageId == page.id ? _active : const [],
      lasso: _activePageId == page.id ? _lassoPoints : const [],
      selection: widget.selection?.pageId == page.id ? widget.selection : null,
      tool: widget.tool,
      color: widget.color,
      width: widget.width,
      strokeStyle: widget.strokeStyle,
      strokeTip: widget.strokeTip,
      elements: widget.elementsFor?.call(page.id) ?? const [],
      imageBytesFor: widget.imageBytesFor,
      selectedElementId: widget.selectedElementId,
      onSelectElement: widget.onSelectElement,
      onElementTransform: (id, rect, committed, {pageId}) {
        if (committed) {
          _commitElementTransform(id, rect);
        } else {
          widget.onElementTransform?.call(id, rect, false);
        }
      },
      onElementRotate: widget.onElementRotate,
      onDeleteElement: widget.onDeleteElement,
      onShiftElementZ: widget.onShiftElementZ,
      onEditElement: widget.onEditElement,
      editingElementId: widget.editingElementId,
      onChangeText: widget.onChangeText,
      onEndEditText: widget.onEndEditText,
      // Any element tool (or Hand) can select / move / resize / rotate every
      // canvas object — otherwise picking Sticky would lock images.
      imagesInteractive: _elementTool || _handTool,
      textInteractive: _elementTool || _handTool,
      backgroundLoader: (p) => widget.backgroundLoader(p, _scale),
      cachedBackground: widget.cachedBackground,
      thumbnailLoader: widget.thumbnailLoader,
      requestFull: _scrollSettled,
      onPointerDown: (e) => _onPageDown(e, page),
      onPointerMove: (e) => _onPageMove(e, page),
      onPointerUp: (e) => _onPageUp(e, page),
      pageNumber: index + 1,
      liveElementId: _elPinchId,
      liveRect: _elPinchLiveRect,
      liveRotation: _elPinchLiveRot,
      onBecameVisible: () {
        widget.onPageVisible(page.id);
        final ahead = widget.pages.sublist(
          (index + 1).clamp(0, widget.pages.length),
          (index + 4).clamp(0, widget.pages.length),
        );
        if (ahead.isNotEmpty) widget.prefetch?.call(ahead);
      },
    );
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
        // Nested orthogonal scroll views swallow vertical drags once the page
        // is wider than the screen (zoomed in). Pan is driven by the root
        // pointer handler instead.
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
                physics: const NeverScrollableScrollPhysics(),
                child: SizedBox(
                  width: _contentWidth,
                  height: vp.height,
                  child: ListView.builder(
                    controller: _vertical,
                    physics: const NeverScrollableScrollPhysics(),
                    padding: const EdgeInsets.only(
                      top: _kPageGap,
                      bottom: _kPageGap * 4,
                    ),
                    itemCount: _rowCount,
                    itemExtent: _uniformUnscaledHeight == null
                        ? null
                        : _uniformUnscaledHeight! * _scale + _kPageGap,
                    itemExtentBuilder: _uniformUnscaledHeight == null
                        ? (index, _) => index >= 0 && index < _rowCount
                            ? _rowHeight(index)
                            : null
                        : null,
                    cacheExtent: _viewport.height > 0 ? _viewport.height : 180,
                    itemBuilder: (context, row) {
                      final firstIndex = widget.twoPageSpread ? row * 2 : row;
                      final secondIndex = firstIndex + 1;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: _kPageGap),
                        child: Center(
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildPageTile(firstIndex),
                              if (widget.twoPageSpread &&
                                  secondIndex < widget.pages.length) ...[
                                const SizedBox(width: _kPageGap),
                                _buildPageTile(secondIndex),
                              ],
                            ],
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
class _PageTile extends ConsumerStatefulWidget {
  const _PageTile({
    super.key,
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
    required this.onDeleteElement,
    required this.onShiftElementZ,
    required this.onEditElement,
    required this.editingElementId,
    required this.onChangeText,
    required this.onEndEditText,
    required this.imagesInteractive,
    required this.textInteractive,
    required this.backgroundLoader,
    required this.cachedBackground,
    this.thumbnailLoader,
    this.requestFull = true,
    required this.onPointerDown,
    required this.onPointerMove,
    required this.onPointerUp,
    required this.pageNumber,
    this.liveElementId,
    this.liveRect,
    this.liveRotation,
    this.onBecameVisible,
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
  final void Function(String id, Rect rect, bool committed, {String? pageId})?
  onElementTransform;
  final void Function(String id, double rotation, bool committed)?
  onElementRotate;
  final ValueChanged<String>? onDeleteElement;
  final void Function(String id, bool forward)? onShiftElementZ;
  final ValueChanged<String>? onEditElement;
  final String? editingElementId;
  final void Function(String id, TextElementData data)? onChangeText;
  final VoidCallback? onEndEditText;
  final bool imagesInteractive;
  final bool textInteractive;
  final Future<ui.Image?> Function(NotePage) backgroundLoader;
  final ui.Image? Function(NotePage)? cachedBackground;
  final Future<ui.Image?> Function(NotePage)? thumbnailLoader;

  /// When false (user is flinging), only a thumbnail is requested. Full
  /// resolution waits until scrolling settles.
  final bool requestFull;
  final ValueChanged<PointerDownEvent> onPointerDown;
  final ValueChanged<PointerMoveEvent> onPointerMove;
  final ValueChanged<PointerEvent> onPointerUp;
  final int pageNumber;
  final String? liveElementId;
  final Rect? liveRect;
  final double? liveRotation;
  final VoidCallback? onBecameVisible;

  @override
  ConsumerState<_PageTile> createState() => _PageTileState();
}

class _PageTileState extends ConsumerState<_PageTile> {
  ui.Image? _background;
  bool _loading = false;
  bool _requestedFull = false;

  bool get _hasBackground =>
      widget.page.pdfAssetId != null || widget.page.bgAssetId != null;

  @override
  void initState() {
    super.initState();
    // Paint whatever is already cached (full image or thumbnail) right away,
    // so a fast scroll shows content instead of a white page.
    _background = widget.cachedBackground?.call(widget.page);
    if (widget.requestFull) {
      _loadFull();
    } else if (_background == null) {
      _loadThumb();
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) widget.onBecameVisible?.call();
    });
  }

  @override
  void didUpdateWidget(covariant _PageTile old) {
    super.didUpdateWidget(old);
    if (widget.requestFull && !old.requestFull) {
      _loadFull();
    } else if (widget.requestFull) {
      final crossedFull = old.scale < 0.6 && widget.scale >= 0.6;
      final crossedHiRes = old.scale <= 2.0 && widget.scale > 2.0;
      if (crossedFull || crossedHiRes) {
        _requestedFull = false;
        _loadFull();
      }
    }
  }

  @override
  void dispose() {
    _background?.dispose();
    super.dispose();
  }

  Future<void> _loadThumb() async {
    final loader = widget.thumbnailLoader;
    if (loader == null || !_hasBackground) return;
    try {
      final img = await loader(widget.page);
      if (!mounted) {
        img?.dispose();
        return;
      }
      if (_background != null) {
        img?.dispose();
        return;
      }
      setState(() => _background = img);
    } catch (_) {}
  }

  Future<void> _loadFull() async {
    if (!_hasBackground || _requestedFull) return;
    _requestedFull = true;
    if (_background == null) setState(() => _loading = true);
    try {
      final img = await widget.backgroundLoader(widget.page);
      if (!mounted) {
        img?.dispose();
        return;
      }
      final old = _background;
      setState(() {
        if (img != null) _background = img;
        _loading = false;
      });
      if (old != null && !identical(old, _background)) old.dispose();
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final watched =
        ref.watch(pageElementsProvider(widget.page.id)).asData?.value;
    final elements = watched ?? widget.elements;
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
        clipBehavior: Clip.none,
        child: FittedBox(
          fit: BoxFit.fill,
          child: SizedBox(
            width: sheet.width,
            height: sheet.height,
            child: Stack(
              clipBehavior: Clip.none,
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
                // Positioned children (not full-page overlays) so a busy page
                // does not run N full-sheet hit tests / layouts per frame.
                for (final element in elements)
                  if (element.type == ElementType.image &&
                      widget.imageBytesFor != null)
                    ImageLayer(
                      elements: [element],
                      bytesFor: widget.imageBytesFor!,
                      dragScale: widget.scale,
                      offset: offset,
                      interactive: widget.imagesInteractive,
                      selectedId: widget.selectedElementId,
                      onSelect: (id) => widget.onSelectElement?.call(id),
                      onTransform: (id, r) =>
                          widget.onElementTransform?.call(id, r, false),
                      onTransformEnd: (id, r) =>
                          widget.onElementTransform?.call(id, r, true),
                      previewRect: element.id == widget.liveElementId
                          ? widget.liveRect
                          : null,
                      previewRotation: element.id == widget.liveElementId
                          ? widget.liveRotation
                          : null,
                    )
                  else if (element.type == ElementType.text ||
                      element.type == ElementType.sticky)
                    TextLayer(
                      elements: [element],
                      dragScale: widget.scale,
                      offset: offset,
                      interactive: widget.textInteractive,
                      selectedId: widget.selectedElementId,
                      editingId: widget.editingElementId,
                      onSelect: (id) => widget.onSelectElement?.call(id),
                      onBeginEdit: (id) => widget.onEditElement?.call(id),
                      onChanged: (id, data) =>
                          widget.onChangeText?.call(id, data),
                      onEndEdit: () => widget.onEndEditText?.call(),
                      onDelete: (id) => widget.onDeleteElement?.call(id),
                      onShiftZ: (id, forward) =>
                          widget.onShiftElementZ?.call(id, forward),
                      onTransform: (id, r) =>
                          widget.onElementTransform?.call(id, r, false),
                      onTransformEnd: (id, r) =>
                          widget.onElementTransform?.call(id, r, true),
                      previewRect: element.id == widget.liveElementId
                          ? widget.liveRect
                          : null,
                      previewRotation: element.id == widget.liveElementId
                          ? widget.liveRotation
                          : null,
                    ),
                IgnorePointer(
                  child: RepaintBoundary(
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
                ),
                IgnorePointer(
                  child: CustomPaint(
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
                ),
                IgnorePointer(
                  child: CustomPaint(
                    size: sheet,
                    painter: LassoPainter(
                      lasso: widget.lasso,
                      selection: widget.selection,
                      offset: offset,
                    ),
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
