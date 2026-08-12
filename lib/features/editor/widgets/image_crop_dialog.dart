import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../../core/models/image_element.dart';

/// Aspect-ratio presets, Canva style.
enum CropAspect { freeform, original, square, r4x3, r3x4, r16x9, r9x16 }

extension _AspectX on CropAspect {
  String get label => switch (this) {
        CropAspect.freeform => 'Freeform',
        CropAspect.original => 'Original',
        CropAspect.square => '1:1',
        CropAspect.r4x3 => '4:3',
        CropAspect.r3x4 => '3:4',
        CropAspect.r16x9 => '16:9',
        CropAspect.r9x16 => '9:16',
      };

  IconData get icon => switch (this) {
        CropAspect.freeform => Icons.crop_free_rounded,
        CropAspect.original => Icons.image_outlined,
        CropAspect.square => Icons.crop_square_rounded,
        CropAspect.r4x3 => Icons.crop_landscape_rounded,
        CropAspect.r3x4 => Icons.crop_portrait_rounded,
        CropAspect.r16x9 => Icons.crop_16_9_rounded,
        CropAspect.r9x16 => Icons.stay_current_portrait_rounded,
      };

  /// Target width/height ratio, or null for freeform.
  double? ratio(double originalAspect) => switch (this) {
        CropAspect.freeform => null,
        CropAspect.original => originalAspect,
        CropAspect.square => 1,
        CropAspect.r4x3 => 4 / 3,
        CropAspect.r3x4 => 3 / 4,
        CropAspect.r16x9 => 16 / 9,
        CropAspect.r9x16 => 9 / 16,
      };
}

/// Canva-style crop editor: aspect-ratio presets, a rotate slider, and a crop
/// window you can drag by its corners or move as a whole.
class ImageCropDialog extends StatefulWidget {
  const ImageCropDialog({
    super.key,
    required this.bytes,
    required this.data,
    this.initialRotation = 0,
  });

  final Uint8List bytes;
  final ImageElementData data;
  final double initialRotation;

  /// Returns the updated crop plus the chosen rotation (radians).
  static Future<(ImageElementData, double)?> show(
    BuildContext context, {
    required Uint8List bytes,
    required ImageElementData data,
    double rotation = 0,
  }) {
    return showDialog<(ImageElementData, double)>(
      context: context,
      builder: (_) => ImageCropDialog(
        bytes: bytes,
        data: data,
        initialRotation: rotation,
      ),
    );
  }

  @override
  State<ImageCropDialog> createState() => _ImageCropDialogState();
}

class _ImageCropDialogState extends State<ImageCropDialog> {
  late double _left = widget.data.cropLeft;
  late double _top = widget.data.cropTop;
  late double _right = widget.data.cropRight;
  late double _bottom = widget.data.cropBottom;
  late double _rotationDeg = widget.initialRotation * 180 / math.pi;

  CropAspect _aspect = CropAspect.freeform;
  Size? _imageSize;

  static const _minSize = 0.05;

  @override
  void initState() {
    super.initState();
    _measure();
  }

  Future<void> _measure() async {
    final image = await decodeImageFromList(widget.bytes);
    if (mounted) {
      setState(() => _imageSize =
          Size(image.width.toDouble(), image.height.toDouble()));
    }
    image.dispose();
  }

  double get _originalAspect {
    final s = _imageSize;
    return s == null || s.height == 0 ? 1 : s.width / s.height;
  }

  /// Re-shapes the crop window to the selected aspect ratio, keeping it
  /// centred on its current position and inside the image.
  void _applyAspect(CropAspect aspect) {
    setState(() => _aspect = aspect);
    final ratio = aspect.ratio(_originalAspect);
    if (ratio == null || _imageSize == null) return;

    // Work in image pixels so the ratio is true to the picture.
    final imgW = _imageSize!.width, imgH = _imageSize!.height;
    final cx = (_left + _right) / 2, cy = (_top + _bottom) / 2;
    var wPx = (_right - _left) * imgW;
    var hPx = wPx / ratio;
    if (hPx > imgH) {
      hPx = imgH;
      wPx = hPx * ratio;
    }
    if (wPx > imgW) {
      wPx = imgW;
      hPx = wPx / ratio;
    }
    final wFrac = wPx / imgW, hFrac = hPx / imgH;
    var l = cx - wFrac / 2, t = cy - hFrac / 2;
    l = l.clamp(0.0, 1 - wFrac);
    t = t.clamp(0.0, 1 - hFrac);
    setState(() {
      _left = l;
      _top = t;
      _right = l + wFrac;
      _bottom = t + hFrac;
    });
  }

  void _dragCorner(int corner, Offset delta, Size box) {
    final dx = delta.dx / box.width;
    final dy = delta.dy / box.height;
    setState(() {
      switch (corner) {
        case 0:
          _left = (_left + dx).clamp(0.0, _right - _minSize);
          _top = (_top + dy).clamp(0.0, _bottom - _minSize);
        case 1:
          _right = (_right + dx).clamp(_left + _minSize, 1.0);
          _top = (_top + dy).clamp(0.0, _bottom - _minSize);
        case 2:
          _left = (_left + dx).clamp(0.0, _right - _minSize);
          _bottom = (_bottom + dy).clamp(_top + _minSize, 1.0);
        case 3:
          _right = (_right + dx).clamp(_left + _minSize, 1.0);
          _bottom = (_bottom + dy).clamp(_top + _minSize, 1.0);
      }
    });
    // Keep a locked ratio honoured while dragging.
    final ratio = _aspect.ratio(_originalAspect);
    if (ratio != null) _lockRatio(ratio, corner);
  }

  void _lockRatio(double ratio, int corner) {
    final s = _imageSize;
    if (s == null) return;
    final wPx = (_right - _left) * s.width;
    final hFrac = (wPx / ratio) / s.height;
    setState(() {
      // Grow/shrink vertically from the anchored edge.
      if (corner == 0 || corner == 1) {
        _top = (_bottom - hFrac).clamp(0.0, _bottom - _minSize);
      } else {
        _bottom = (_top + hFrac).clamp(_top + _minSize, 1.0);
      }
    });
  }

  /// Drags the whole crop window without changing its size.
  void _moveWindow(Offset delta, Size box) {
    final dx = delta.dx / box.width;
    final dy = delta.dy / box.height;
    final w = _right - _left, h = _bottom - _top;
    setState(() {
      _left = (_left + dx).clamp(0.0, 1 - w);
      _top = (_top + dy).clamp(0.0, 1 - h);
      _right = _left + w;
      _bottom = _top + h;
    });
  }

  @override
  Widget build(BuildContext context) {
    final shortest = MediaQuery.of(context).size.shortestSide;
    final maxWidth = (shortest - 80).clamp(240.0, 460.0);

    return AlertDialog(
      insetPadding: const EdgeInsets.all(16),
      titlePadding: const EdgeInsets.fromLTRB(20, 16, 8, 0),
      title: Row(
        children: [
          const Text('Crop'),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.close_rounded),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
      content: SizedBox(
        width: maxWidth,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _sectionLabel(context, 'Aspect ratio'),
              SizedBox(
                height: 74,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: CropAspect.values.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 8),
                  itemBuilder: (context, i) {
                    final a = CropAspect.values[i];
                    return _AspectCard(
                      aspect: a,
                      selected: _aspect == a,
                      onTap: () => _applyAspect(a),
                    );
                  },
                ),
              ),
              const SizedBox(height: 12),
              _sectionLabel(context, 'Rotate'),
              Row(
                children: [
                  Expanded(
                    child: Slider(
                      min: -180,
                      max: 180,
                      value: _rotationDeg.clamp(-180, 180),
                      onChanged: (v) => setState(() => _rotationDeg = v),
                    ),
                  ),
                  TextButton(
                    onPressed: () => setState(() => _rotationDeg = 0),
                    child: const Text('Reset'),
                  ),
                  SizedBox(
                    width: 42,
                    child: Text('${_rotationDeg.round()}°',
                        textAlign: TextAlign.end,
                        style: Theme.of(context).textTheme.bodySmall),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              AspectRatio(
                aspectRatio: 1,
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final box = constraints.biggest;
                    final rect = Rect.fromLTRB(
                      _left * box.width,
                      _top * box.height,
                      _right * box.width,
                      _bottom * box.height,
                    );
                    return Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Positioned.fill(
                          child: Transform.rotate(
                            angle: _rotationDeg * math.pi / 180,
                            child: Image.memory(widget.bytes,
                                fit: BoxFit.contain),
                          ),
                        ),
                        Positioned.fill(
                          child: IgnorePointer(
                            child: CustomPaint(painter: _CropOverlay(rect)),
                          ),
                        ),
                        // Drag inside the window to reposition it.
                        Positioned.fromRect(
                          rect: rect,
                          child: GestureDetector(
                            behavior: HitTestBehavior.translucent,
                            onPanUpdate: (d) => _moveWindow(d.delta, box),
                            child: const SizedBox.expand(),
                          ),
                        ),
                        for (var i = 0; i < 4; i++)
                          Positioned(
                            left: (i.isEven ? rect.left : rect.right) - 14,
                            top: (i < 2 ? rect.top : rect.bottom) - 14,
                            child: GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onPanUpdate: (d) =>
                                  _dragCorner(i, d.delta, box),
                              child: Container(
                                width: 28,
                                height: 28,
                                decoration: BoxDecoration(
                                  color:
                                      Theme.of(context).colorScheme.primary,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                      color: Colors.white, width: 2),
                                ),
                              ),
                            ),
                          ),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => setState(() {
            _left = 0;
            _top = 0;
            _right = 1;
            _bottom = 1;
            _rotationDeg = 0;
            _aspect = CropAspect.freeform;
          }),
          child: const Text('Reset'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(
            context,
            (
              widget.data.copyWith(
                cropLeft: _left,
                cropTop: _top,
                cropRight: _right,
                cropBottom: _bottom,
              ),
              _rotationDeg * math.pi / 180,
            ),
          ),
          child: const Text('Done'),
        ),
      ],
    );
  }

  Widget _sectionLabel(BuildContext context, String text) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(text,
            style: Theme.of(context)
                .textTheme
                .labelMedium
                ?.copyWith(fontWeight: FontWeight.w700)),
      );
}

class _AspectCard extends StatelessWidget {
  const _AspectCard(
      {required this.aspect, required this.selected, required this.onTap});
  final CropAspect aspect;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: onTap,
      child: Container(
        width: 72,
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected ? scheme.primary : scheme.outlineVariant,
            width: selected ? 2 : 1,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(aspect.icon, size: 22),
            const SizedBox(height: 4),
            Text(aspect.label,
                style: Theme.of(context).textTheme.labelSmall),
          ],
        ),
      ),
    );
  }
}

class _CropOverlay extends CustomPainter {
  const _CropOverlay(this.rect);
  final Rect rect;

  @override
  void paint(Canvas canvas, Size size) {
    final dim = Paint()..color = const Color(0x99000000);
    canvas.drawRect(Rect.fromLTRB(0, 0, size.width, rect.top), dim);
    canvas.drawRect(
        Rect.fromLTRB(0, rect.bottom, size.width, size.height), dim);
    canvas.drawRect(Rect.fromLTRB(0, rect.top, rect.left, rect.bottom), dim);
    canvas.drawRect(
        Rect.fromLTRB(rect.right, rect.top, size.width, rect.bottom), dim);

    canvas.drawRect(
      rect,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
    final guide = Paint()
      ..color = Colors.white54
      ..strokeWidth = 1;
    for (var i = 1; i < 3; i++) {
      final x = rect.left + rect.width * i / 3;
      final y = rect.top + rect.height * i / 3;
      canvas.drawLine(Offset(x, rect.top), Offset(x, rect.bottom), guide);
      canvas.drawLine(Offset(rect.left, y), Offset(rect.right, y), guide);
    }
  }

  @override
  bool? hitTest(Offset position) => false;

  @override
  bool shouldRepaint(covariant _CropOverlay old) => old.rect != rect;
}
