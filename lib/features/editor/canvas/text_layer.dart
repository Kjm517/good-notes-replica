import 'package:flutter/material.dart';

import '../../../core/db/database.dart';
import '../../../core/models/enums.dart';
import '../../../core/models/text_element.dart';
import 'hit_overflow.dart';

/// Renders a page's text boxes and sticky notes and lets the active one be
/// dragged, resized, formatted and — Canva-style — typed into directly on the
/// canvas. Positions are in content coordinates, mirroring [ImageLayer].
class TextLayer extends StatelessWidget {
  const TextLayer({
    super.key,
    required this.elements,
    required this.dragScale,
    required this.offset,
    required this.interactive,
    required this.selectedId,
    required this.editingId,
    required this.onSelect,
    required this.onBeginEdit,
    required this.onChanged,
    required this.onEndEdit,
    required this.onDelete,
    this.onShiftZ,
    required this.onTransform,
    required this.onTransformEnd,
    this.previewRect,
    this.previewRotation,
  });

  final List<CanvasElement> elements;

  /// On-screen pixels per content point (pointer deltas arrive in screen px).
  final double dragScale;

  /// Content origin within the sheet (extendable margins).
  final Offset offset;

  /// Whether the items respond to touch (only for the Text/Sticky/Hand tools).
  final bool interactive;

  final String? selectedId;

  /// The element currently open for inline text entry, if any.
  final String? editingId;

  final ValueChanged<String?> onSelect;
  final ValueChanged<String> onBeginEdit;
  final void Function(String id, TextElementData data) onChanged;
  final VoidCallback onEndEdit;
  final ValueChanged<String> onDelete;
  final void Function(String id, bool forward)? onShiftZ;
  final void Function(String id, Rect rect) onTransform;
  final void Function(String id, Rect rect) onTransformEnd;

  /// Live two-finger transform driven by the canvas (content coordinates).
  final Rect? previewRect;
  final double? previewRotation;

  @override
  Widget build(BuildContext context) {
    if (elements.isEmpty) return const SizedBox.shrink();
    final element = elements.first;
    // Positioned item goes straight onto the page Stack so a busy page does
    // not run a full-sheet hit test per text box.
    return _TextItem(
      key: ValueKey(element.id),
      element: element,
      dragScale: dragScale,
      offset: offset,
      interactive: interactive,
      selected: element.id == selectedId,
      editing: element.id == editingId,
      onSelect: () => onSelect(element.id),
      onBeginEdit: () => onBeginEdit(element.id),
      onChanged: (data) => onChanged(element.id, data),
      onEndEdit: onEndEdit,
      onDelete: () => onDelete(element.id),
      onBringForward: () => onShiftZ?.call(element.id, true),
      onSendBackward: () => onShiftZ?.call(element.id, false),
      onTransform: (r) => onTransform(element.id, r),
      onTransformEnd: (r) => onTransformEnd(element.id, r),
      previewRect: element.id == selectedId ? previewRect : null,
      previewRotation: element.id == selectedId ? previewRotation : null,
    );
  }
}

class _TextItem extends StatefulWidget {
  const _TextItem({
    super.key,
    required this.element,
    required this.dragScale,
    required this.offset,
    required this.interactive,
    required this.selected,
    required this.editing,
    required this.onSelect,
    required this.onBeginEdit,
    required this.onChanged,
    required this.onEndEdit,
    required this.onDelete,
    required this.onBringForward,
    required this.onSendBackward,
    required this.onTransform,
    required this.onTransformEnd,
    this.previewRect,
    this.previewRotation,
  });

  final CanvasElement element;
  final double dragScale;
  final Offset offset;
  final bool interactive;
  final bool selected;
  final bool editing;
  final VoidCallback onSelect;
  final VoidCallback onBeginEdit;
  final ValueChanged<TextElementData> onChanged;
  final VoidCallback onEndEdit;
  final VoidCallback onDelete;
  final VoidCallback onBringForward;
  final VoidCallback onSendBackward;
  final ValueChanged<Rect> onTransform;
  final ValueChanged<Rect> onTransformEnd;
  final Rect? previewRect;
  final double? previewRotation;

  @override
  State<_TextItem> createState() => _TextItemState();
}

class _TextItemState extends State<_TextItem> {
  late final TextEditingController _controller = TextEditingController(
    text: _data.text,
  );
  late final FocusNode _focus = FocusNode();
  Rect? _live;
  bool _canvasOwnsPinch = false;

  static const double _minSize = 40;

  bool get _sticky => widget.element.type == ElementType.sticky;
  late String _parsedJson = widget.element.data;
  late TextElementData _parsed = TextElementData.fromJson(_parsedJson);

  TextElementData get _data {
    final json = widget.element.data;
    if (json != _parsedJson) {
      _parsedJson = json;
      _parsed = TextElementData.fromJson(json);
    }
    return _parsed;
  }

  double get _rotation => widget.previewRotation ?? widget.element.rotation;

  Rect get _stored => Rect.fromLTWH(
    widget.element.x,
    widget.element.y,
    widget.element.width,
    widget.element.height,
  );
  Rect get _rect => widget.previewRect ?? _live ?? _stored;

  /// Pinch-resize scales type with the box; corner-drag only reflows.
  double get _pinchFontScale {
    final preview = widget.previewRect;
    if (preview == null || widget.element.width <= 0) return 1;
    return preview.width / widget.element.width;
  }

  TextElementData get _visualData {
    final scale = _pinchFontScale;
    if ((scale - 1).abs() < 0.001) return _data;
    return _data.copyWith(
      fontSize: TextElementData.clampFontSize(_data.fontSize * scale),
    );
  }

  @override
  void initState() {
    super.initState();
    _focus.addListener(_onFocusChange);
    if (widget.editing) _requestEditFocus();
  }

  @override
  void didUpdateWidget(covariant _TextItem old) {
    super.didUpdateWidget(old);
    // Reflect external edits only while the user isn't actively typing, so a
    // formatting change (which re-emits the element) never fights the cursor.
    if (!widget.editing && _controller.text != _data.text) {
      _controller.text = _data.text;
    }
    if (widget.editing && !old.editing) _requestEditFocus();
  }

  @override
  void dispose() {
    _focus.removeListener(_onFocusChange);
    _focus.dispose();
    _controller.dispose();
    super.dispose();
  }

  bool get _showChrome => widget.selected || widget.editing;

  void _requestEditFocus() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !widget.editing) return;
      _focus.requestFocus();
      _controller.selection = TextSelection.collapsed(
        offset: _controller.text.length,
      );
    });
  }

  void _onFocusChange() {
    if (!_focus.hasFocus && widget.editing) {
      _commitText();
      widget.onEndEdit();
    }
  }

  void _commitText() {
    if (_controller.text != _data.text) {
      widget.onChanged(_data.copyWith(text: _controller.text));
    }
  }

  Offset _toContent(Offset delta) =>
      widget.dragScale <= 0 ? delta : delta / widget.dragScale;

  void _move(Offset screenDelta) {
    final next = _rect.shift(_toContent(screenDelta));
    setState(() => _live = next);
    widget.onTransform(next);
  }

  /// Free resize from a corner — width and height move independently so a
  /// text box can be made wider (for wrapping) without locking aspect.
  void _resize(_Corner corner, Offset screenDelta) {
    final d = _toContent(screenDelta);
    final r = _rect;
    final growX = switch (corner) {
      _Corner.topRight || _Corner.bottomRight => d.dx,
      _Corner.topLeft || _Corner.bottomLeft => -d.dx,
    };
    final growY = switch (corner) {
      _Corner.bottomLeft || _Corner.bottomRight => d.dy,
      _Corner.topLeft || _Corner.topRight => -d.dy,
    };
    final width = (r.width + growX).clamp(_minSize, 100000.0);
    final height = (r.height + growY).clamp(_minSize, 100000.0);
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

  void _commitRect() {
    final r = _rect;
    setState(() {
      _live = null;
    });
    widget.onTransformEnd(r);
  }

  void _onScaleStart(ScaleStartDetails d) {
    widget.onSelect();
    _canvasOwnsPinch = d.pointerCount >= 2;
    if (_canvasOwnsPinch) return;
  }

  void _onScaleUpdate(ScaleUpdateDetails d) {
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
      });
      return;
    }
    final r = _rect;
    setState(() {
      _live = null;
    });
    widget.onTransformEnd(r);
  }

  @override
  Widget build(BuildContext context) {
    final rect = _rect;
    final visual = _visualData;
    final s = widget.dragScale <= 0 ? 1.0 : widget.dragScale;
    final accent = Theme.of(context).colorScheme.primary;

    final field = widget.editing ? _buildField(visual) : null;
    final content = _sticky
        ? _StickyCard(
            data: visual,
            editing: widget.editing,
            field: field,
            elevated: widget.selected || widget.editing,
          )
        : _PlainText(data: visual, editing: widget.editing, field: field);

    // While editing, the field owns taps (place the cursor); otherwise the box
    // is a drag target that selects on tap and edits on double-tap.
    final body = widget.editing
        ? content
        : (!widget.interactive && !widget.selected)
        ? content
        : GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: widget.onSelect,
            onDoubleTap: widget.onBeginEdit,
            onScaleStart: _onScaleStart,
            onScaleUpdate: _onScaleUpdate,
            onScaleEnd: _onScaleEnd,
            child: MouseRegion(cursor: SystemMouseCursors.move, child: content),
          );

    final showChrome = _showChrome;
    final chrome = showChrome ? 12 / s : 0.0;
    final rotation = _rotation;

    Widget painted = Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned(
          left: chrome,
          top: chrome,
          right: chrome,
          bottom: chrome,
          child: body,
        ),
        if (showChrome) ...[
          Positioned(
            left: chrome,
            top: chrome,
            right: chrome,
            bottom: chrome,
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  border: Border.all(color: accent, width: 2 / s),
                ),
              ),
            ),
          ),
          for (final corner in _Corner.values)
            _CornerHandle(
              corner: corner,
              scale: s,
              pad: EdgeInsets.all(chrome),
              onDrag: (delta) => _resize(corner, delta),
              onEnd: _commitRect,
            ),
        ],
      ],
    );
    if (rotation.abs() > 0.0001) {
      painted = Transform.rotate(angle: rotation, child: painted);
    }
    if (showChrome) painted = HitOverflow(child: painted);
    painted = IgnorePointer(
      ignoring: !widget.interactive && !widget.selected && !widget.editing,
      child: painted,
    );
    painted = RepaintBoundary(child: painted);

    return Positioned(
      left: rect.left + widget.offset.dx - chrome,
      top: rect.top + widget.offset.dy - chrome,
      width: rect.width + chrome * 2,
      height: rect.height + chrome * 2,
      child: painted,
    );
  }

  Widget _buildField(TextElementData data) {
    return TextField(
      controller: _controller,
      focusNode: _focus,
      maxLines: null,
      expands: false,
      textAlign: data.textAlign,
      textCapitalization: TextCapitalization.sentences,
      cursorColor: Color(data.colorValue),
      style: TextStyle(
        fontSize: data.fontSize,
        height: _sticky ? 1.4 : 1.3,
        fontWeight: data.bold ? FontWeight.w700 : FontWeight.w400,
        color: Color(data.colorValue),
        shadows: _sticky
            ? null
            : const [
                Shadow(color: Color(0xE6FFFFFF), blurRadius: 3),
                Shadow(color: Color(0xB3FFFFFF), blurRadius: 8),
              ],
      ),
      decoration: const InputDecoration(
        isDense: true,
        filled: false,
        fillColor: Color(0x00000000),
        hoverColor: Color(0x00000000),
        border: InputBorder.none,
        enabledBorder: InputBorder.none,
        focusedBorder: InputBorder.none,
        disabledBorder: InputBorder.none,
        errorBorder: InputBorder.none,
        focusedErrorBorder: InputBorder.none,
        contentPadding: EdgeInsets.zero,
        hintText: 'Type…',
      ),
      // Persist as the user types so a focus loss (or crash) never drops
      // the last few characters they wrote.
      onChanged: (text) => widget.onChanged(data.copyWith(text: text)),
    );
  }
}

/// Plain text drawn straight on the page (or its inline editor when active).
class _PlainText extends StatelessWidget {
  const _PlainText({
    required this.data,
    required this.editing,
    required this.field,
  });

  final TextElementData data;
  final bool editing;
  final Widget? field;

  @override
  Widget build(BuildContext context) {
    if (editing && field != null) {
      return Container(alignment: Alignment.topLeft, child: field);
    }
    final placeholder = data.text.trim().isEmpty;
    return Container(
      alignment: Alignment.topLeft,
      child: Text(
        placeholder ? 'Text' : data.text,
        textAlign: data.textAlign,
        style: TextStyle(
          fontSize: data.fontSize,
          height: 1.3,
          fontWeight: data.bold ? FontWeight.w700 : FontWeight.w400,
          color: placeholder
              ? Color(data.colorValue).withValues(alpha: 0.4)
              : Color(data.colorValue),
          shadows: const [
            Shadow(color: Color(0xE6FFFFFF), blurRadius: 3),
            Shadow(color: Color(0xB3FFFFFF), blurRadius: 8),
          ],
        ),
      ),
    );
  }
}

/// The same text on a paper-note card, GoodNotes-style.
class _StickyCard extends StatelessWidget {
  const _StickyCard({
    required this.data,
    required this.editing,
    required this.field,
    this.elevated = false,
  });

  final TextElementData data;
  final bool editing;
  final Widget? field;
  final bool elevated;

  @override
  Widget build(BuildContext context) {
    final placeholder = data.text.trim().isEmpty;
    final Widget body = (editing && field != null)
        ? field!
        : Text(
            placeholder ? 'Tap to write a note' : data.text,
            maxLines: 100,
            overflow: TextOverflow.fade,
            style: TextStyle(
              fontSize: data.fontSize,
              height: 1.4,
              color: placeholder
                  ? const Color(0xFF5F5322).withValues(alpha: 0.5)
                  : Color(data.colorValue),
            ),
          );

    return Container(
      padding: const EdgeInsets.fromLTRB(11, 10, 11, 12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF8D6),
        border: Border.all(color: const Color(0xFFF0E39A)),
        borderRadius: BorderRadius.circular(10),
        boxShadow: elevated
            ? [
                BoxShadow(
                  color: const Color(0xFF786414).withValues(alpha: 0.28),
                  blurRadius: 12,
                  offset: const Offset(0, 6),
                ),
              ]
            : const [
                BoxShadow(
                  color: Color(0x24786414),
                  blurRadius: 1,
                  offset: Offset(0, 1),
                ),
              ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'NOTE',
            style: TextStyle(
              fontSize: 8,
              letterSpacing: 1.4,
              fontWeight: FontWeight.w700,
              color: Color(0xFFB09A3E),
            ),
          ),
          const SizedBox(height: 4),
          Expanded(child: body),
        ],
      ),
    );
  }
}

/// Which corner is being dragged.
enum _Corner { topLeft, topRight, bottomLeft, bottomRight }

/// A corner resize grip. Sized in screen pixels so it stays constant at any zoom.
class _CornerHandle extends StatelessWidget {
  const _CornerHandle({
    required this.corner,
    required this.scale,
    required this.pad,
    required this.onDrag,
    required this.onEnd,
  });

  final _Corner corner;
  final double scale;
  final EdgeInsets pad;
  final ValueChanged<Offset> onDrag;
  final VoidCallback onEnd;

  @override
  Widget build(BuildContext context) {
    final s = scale <= 0 ? 1.0 : scale;
    final size = 18 / s;
    final isLeft = corner == _Corner.topLeft || corner == _Corner.bottomLeft;
    final isTop = corner == _Corner.topLeft || corner == _Corner.topRight;
    final leftInset = pad.left - size / 2;
    final rightInset = pad.right - size / 2;
    final topInset = pad.top - size / 2;
    final bottomInset = pad.bottom - size / 2;

    return Positioned(
      left: isLeft ? leftInset : null,
      right: isLeft ? null : rightInset,
      top: isTop ? topInset : null,
      bottom: isTop ? null : bottomInset,
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
