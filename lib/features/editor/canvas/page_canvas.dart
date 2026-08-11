import 'package:flutter/material.dart';

import '../../../core/db/database.dart';
import '../../../core/ink/ink_stroke.dart';
import '../../../core/models/enums.dart';
import '../pages/paper_painter.dart';
import 'ink_painters.dart';

/// Interaction mode of the canvas at a moment in time.
enum _Mode { none, draw, gesture }

/// The interactive page surface: paper + committed ink + live stroke, with
/// two-finger pan/zoom and one-pointer (stylus/finger) drawing & erasing.
class PageCanvas extends StatefulWidget {
  const PageCanvas({
    super.key,
    required this.page,
    required this.pageSize,
    required this.strokes,
    required this.tool,
    required this.color,
    required this.width,
    required this.eraserMode,
    required this.onStrokeCommitted,
    required this.onErase,
    this.eraserRadius = 12,
  });

  final NotePage page;
  final Size pageSize;
  final List<InkStroke> strokes;
  final ToolType tool;
  final int color;
  final double width;
  final EraserMode eraserMode;
  final ValueChanged<InkStroke> onStrokeCommitted;
  final ValueChanged<Set<String>> onErase;
  final double eraserRadius;

  @override
  State<PageCanvas> createState() => _PageCanvasState();
}

class _PageCanvasState extends State<PageCanvas> {
  Matrix4 _matrix = Matrix4.identity();
  bool _initialized = false;
  Size _viewport = Size.zero;

  final Map<int, Offset> _pointers = {};
  _Mode _mode = _Mode.none;

  // Live stroke, in page coordinates.
  List<StrokePoint> _active = const [];

  // Two-finger gesture baseline.
  Offset _lastFocal = Offset.zero;
  double _lastDist = 1;

  void _fit(Size viewport) {
    final scale = viewport.width / widget.pageSize.width;
    final scaledHeight = widget.pageSize.height * scale;
    final dy = scaledHeight < viewport.height
        ? (viewport.height - scaledHeight) / 2
        : 16.0;
    _matrix = Matrix4.identity()
      ..translate(0.0, dy)
      ..scale(scale);
    _initialized = true;
  }

  Offset _toPage(Offset viewportPoint) {
    final inv = Matrix4.copy(_matrix)..invert();
    return MatrixUtils.transformPoint(inv, viewportPoint);
  }

  bool get _canDraw =>
      widget.tool == ToolType.pen ||
      widget.tool == ToolType.pencil ||
      widget.tool == ToolType.highlighter ||
      widget.tool == ToolType.eraser;

  // ---- Pointer handling ----------------------------------------------------

  void _onDown(PointerDownEvent e) {
    _pointers[e.pointer] = e.localPosition;
    if (_pointers.length == 1 && _mode == _Mode.none) {
      if (widget.tool == ToolType.hand) {
        // Hand tool: single-finger pan.
        _mode = _Mode.gesture;
        _resetGestureBaseline();
      } else if (_canDraw) {
        _mode = _Mode.draw;
        final p = _toPage(e.localPosition);
        if (widget.tool == ToolType.eraser) {
          _eraseAt(p);
          _active = const [];
        } else {
          setState(() => _active = [StrokePoint(p.dx, p.dy, e.pressure)]);
        }
      }
    } else if (_pointers.length >= 2) {
      if (_mode == _Mode.draw) {
        // Second finger arrived: abandon the nascent stroke, switch to gesture.
        setState(() => _active = const []);
      }
      _mode = _Mode.gesture;
      _resetGestureBaseline();
    }
  }

  void _onMove(PointerMoveEvent e) {
    if (!_pointers.containsKey(e.pointer)) return;
    _pointers[e.pointer] = e.localPosition;

    if (_mode == _Mode.gesture) {
      _updateGesture();
    } else if (_mode == _Mode.draw && _pointers.length == 1) {
      final p = _toPage(e.localPosition);
      if (widget.tool == ToolType.eraser) {
        _eraseAt(p);
      } else {
        setState(() =>
            _active = [..._active, StrokePoint(p.dx, p.dy, e.pressure)]);
      }
    }
  }

  void _onUp(PointerEvent e) {
    _pointers.remove(e.pointer);
    if (_mode == _Mode.draw && _pointers.isEmpty) {
      _commitActive();
      _mode = _Mode.none;
    } else if (_mode == _Mode.gesture) {
      if (_pointers.isEmpty) {
        _mode = _Mode.none;
      } else {
        // Keep the gesture locked (ignore the lone finger) until all lift.
        _resetGestureBaseline();
      }
    }
  }

  void _commitActive() {
    if (widget.tool == ToolType.eraser || _active.isEmpty) {
      setState(() => _active = const []);
      return;
    }
    final stroke = InkStroke(
      id: UniqueKey().toString(),
      tool: widget.tool,
      color: widget.color,
      width: widget.width,
      points: _active,
    );
    widget.onStrokeCommitted(stroke);
    setState(() => _active = const []);
  }

  // ---- Two-finger pan/zoom -------------------------------------------------

  Offset _focalOf(List<Offset> pts) {
    var sum = Offset.zero;
    for (final p in pts) {
      sum += p;
    }
    return sum / pts.length.toDouble();
  }

  void _resetGestureBaseline() {
    final pts = _pointers.values.toList();
    if (pts.isEmpty) return;
    _lastFocal = _focalOf(pts);
    _lastDist = pts.length >= 2
        ? (pts[0] - pts[1]).distance.clamp(1.0, double.infinity).toDouble()
        : 1.0;
  }

  void _updateGesture() {
    final pts = _pointers.values.toList();
    if (pts.isEmpty) return;
    final focal = _focalOf(pts);
    // Zoom only with two fingers; a single finger just pans (scale = 1).
    final dist = pts.length >= 2
        ? (pts[0] - pts[1]).distance.clamp(1.0, double.infinity).toDouble()
        : _lastDist;
    final scale = dist / _lastDist;
    final delta = focal - _lastFocal;

    final incr = Matrix4.identity()
      ..translate(focal.dx, focal.dy)
      ..scale(scale)
      ..translate(-focal.dx, -focal.dy);
    final pan = Matrix4.identity()..translate(delta.dx, delta.dy);
    final combined = pan.multiplied(incr);

    setState(() => _matrix = combined.multiplied(_matrix));
    _lastFocal = focal;
    _lastDist = dist;
  }

  // ---- Erasing -------------------------------------------------------------

  void _eraseAt(Offset p) {
    final r = widget.eraserRadius;
    final r2 = r * r;
    final hits = <String>{};
    for (final s in widget.strokes) {
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
    if (hits.isNotEmpty) widget.onErase(hits);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final vp = constraints.biggest;
        if (!_initialized || vp != _viewport) {
          _viewport = vp;
          if (!_initialized) _fit(vp);
        }
        return Listener(
          behavior: HitTestBehavior.opaque,
          onPointerDown: _onDown,
          onPointerMove: _onMove,
          onPointerUp: _onUp,
          onPointerCancel: _onUp,
          child: ClipRect(
            child: Stack(
              children: [
                Positioned.fill(
                  child: ColoredBox(color: Theme.of(context).canvasColor),
                ),
                Transform(
                  transform: _matrix,
                  child: _PageContent(
                    pageSize: widget.pageSize,
                    page: widget.page,
                    strokes: widget.strokes,
                    active: _active,
                    tool: widget.tool,
                    color: widget.color,
                    width: widget.width,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _PageContent extends StatelessWidget {
  const _PageContent({
    required this.pageSize,
    required this.page,
    required this.strokes,
    required this.active,
    required this.tool,
    required this.color,
    required this.width,
  });

  final Size pageSize;
  final NotePage page;
  final List<InkStroke> strokes;
  final List<StrokePoint> active;
  final ToolType tool;
  final int color;
  final double width;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: pageSize.width,
      height: pageSize.height,
      child: Stack(
        children: [
          // Drop shadow for the page.
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.18),
                    blurRadius: 18,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
            ),
          ),
          RepaintBoundary(
            child: CustomPaint(
              size: pageSize,
              painter: PaperPainter(
                template: page.template,
                paperColor: page.paperColor,
                margins: page.marginSpec,
              ),
            ),
          ),
          RepaintBoundary(
            child: CustomPaint(
              size: pageSize,
              painter: CommittedInkPainter(strokes),
            ),
          ),
          CustomPaint(
            size: pageSize,
            painter: ActiveStrokePainter(
              points: active,
              tool: tool,
              color: color,
              width: width,
            ),
          ),
        ],
      ),
    );
  }
}
