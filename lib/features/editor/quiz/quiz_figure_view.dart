import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/design.dart';
import '../../../core/db/database.dart';
import '../providers.dart';
import 'quiz_models.dart';

/// The diagram an identification item is asking about, with the marker drawn
/// on it.
///
/// Unlike [QuizSourcePreview] this is inline and shown *before* the answer:
/// the figure is the question. It also crops to the marked area rather than
/// showing the whole page — a full textbook page scaled into a card leaves the
/// structure a few pixels wide, which is not something a student can name.
class QuizFigureView extends ConsumerStatefulWidget {
  const QuizFigureView({
    super.key,
    required this.documentId,
    required this.question,
    this.height = 260,
  });

  final String documentId;
  final QuizQuestion question;
  final double height;

  @override
  ConsumerState<QuizFigureView> createState() => _QuizFigureViewState();
}

class _QuizFigureViewState extends ConsumerState<QuizFigureView> {
  ui.Image? _image;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void didUpdateWidget(QuizFigureView old) {
    super.didUpdateWidget(old);
    if (old.question.pageIndex != widget.question.pageIndex ||
        old.question.figure?.region.w != widget.question.figure?.region.w) {
      _loading = true;
      _load();
    }
  }

  Future<void> _load() async {
    final pages =
        await ref.read(pageRepositoryProvider).getPages(widget.documentId);
    NotePage? page;
    for (final row in pages) {
      if (row.pageIndex == widget.question.pageIndex) {
        page = row;
        break;
      }
    }
    if (!mounted) return;
    if (page == null) {
      setState(() => _loading = false);
      return;
    }
    final dpr = MediaQuery.devicePixelRatioOf(context);
    final width = MediaQuery.sizeOf(context).width;
    // Resolution has to scale with the crop, not sit at a fixed multiplier.
    // Showing a fifth of the page from a 1.6x render leaves roughly a third of
    // the pixels the card actually paints, which is why the figure looked
    // soft. Ask for what the visible slice needs, then cap it: a page is
    // decoded into memory, and on web that memory is the whole ceiling.
    final slice = widget.question.figure?.region.w ??
        widget.question.highlight?.w ??
        1.0;
    final zoom = (1 / slice.clamp(0.05, 1.0)).clamp(1.0, 6.0);
    final target = (width * dpr * zoom).clamp(900.0, 3600.0);
    final image = await ref
        .read(pageBackgroundServiceProvider)
        .loadThumbnail(page, targetWidth: target);
    if (!mounted) {
      image?.dispose();
      return;
    }
    setState(() {
      _image?.dispose();
      _image = image;
      _loading = false;
    });
  }

  @override
  void dispose() {
    _image?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final image = _image;
    return Container(
      height: widget.height,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: t.surfaceAlt,
        borderRadius: BorderRadius.circular(Radii.control),
        border: Border.all(color: t.line),
      ),
      child: _loading
          ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
          : image == null
              ? Center(
                  child: Text(
                    'Figure unavailable',
                    style: TextStyle(color: t.textMuted),
                  ),
                )
              : CustomPaint(
                  painter: _FigurePainter(
                    image: image,
                    figure: widget.question.figure,
                    spot: widget.question.highlight,
                    marker: t.premium,
                    markerOn: t.premiumOn,
                    coverColor: t.surface,
                    coverLine: t.line,
                  ),
                  size: Size.infinite,
                ),
    );
  }
}

/// Draws the page zoomed to the marked structure, with a ring around it.
class _FigurePainter extends CustomPainter {
  _FigurePainter({
    required this.image,
    required this.figure,
    required this.spot,
    required this.marker,
    required this.markerOn,
    required this.coverColor,
    required this.coverLine,
  });

  final ui.Image image;

  /// Set for a blanked diagram: crop to it, cover every label, number them.
  final QuizFigure? figure;

  /// Used when there is no [figure] — a model-written item marks a structure.
  final QuizHighlight? spot;

  final Color marker;
  final Color markerOn;
  final Color coverColor;
  final Color coverLine;

  @override
  void paint(Canvas canvas, Size size) {
    final iw = image.width.toDouble();
    final ih = image.height.toDouble();

    final diagram = figure;
    if (diagram != null) {
      _paintBlankedFigure(canvas, size, diagram, iw, ih);
      return;
    }

    final hl = spot;

    // Without a marker there is nothing to zoom to, so show the whole page.
    if (hl == null) {
      canvas.drawImageRect(
        image,
        Rect.fromLTWH(0, 0, iw, ih),
        _fit(Rect.fromLTWH(0, 0, iw, ih), size),
        Paint()..filterQuality = FilterQuality.medium,
      );
      return;
    }

    // Context around the structure: enough of the figure to orient by, not so
    // much that the marked part shrinks away again.
    final cx = (hl.x + hl.w / 2) * iw;
    final cy = (hl.y + hl.h / 2) * ih;
    final span = (hl.w * iw).clamp(1.0, iw) * 5.0;
    final spanY = (hl.h * ih).clamp(1.0, ih) * 5.0;
    final half = (span > spanY ? span : spanY) / 2;

    var src = Rect.fromCenter(
      center: Offset(cx, cy),
      width: half * 2,
      height: half * 2 * (size.height / size.width),
    );
    // Keep the crop on the page.
    src = _shiftInside(src, Rect.fromLTWH(0, 0, iw, ih));

    canvas.drawImageRect(
      image,
      src,
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()..filterQuality = FilterQuality.medium,
    );

    // The ring, mapped from page space into the cropped view.
    final sx = size.width / src.width;
    final sy = size.height / src.height;
    final target = Rect.fromLTWH(
      (hl.x * iw - src.left) * sx,
      (hl.y * ih - src.top) * sy,
      hl.w * iw * sx,
      hl.h * ih * sy,
    ).inflate(6);

    // Nothing is covered on this path: it draws a model-written item, where
    // the marker is the structure being asked about. Painting over it would
    // hide the very thing the student has to name.
    canvas.drawRRect(
      RRect.fromRectAndRadius(target, const Radius.circular(8)),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..color = marker,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(target.inflate(3), const Radius.circular(11)),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..color = marker.withValues(alpha: 0.35),
    );
  }

  /// Draws the figure with every label covered and numbered.
  void _paintBlankedFigure(
    Canvas canvas,
    Size size,
    QuizFigure diagram,
    double iw,
    double ih,
  ) {
    final region = diagram.region;
    var src = Rect.fromLTWH(
      region.x * iw,
      region.y * ih,
      math.max(region.w * iw, 1),
      math.max(region.h * ih, 1),
    );
    src = _shiftInside(src, Rect.fromLTWH(0, 0, iw, ih));

    // Fit rather than fill: stretching a diagram to the card's aspect ratio
    // misshapes the very thing being identified.
    final dst = _fit(Rect.fromLTWH(0, 0, src.width, src.height), size);
    canvas.drawImageRect(
      image,
      src,
      dst,
      Paint()..filterQuality = FilterQuality.medium,
    );

    final sx = dst.width / src.width;
    final sy = dst.height / src.height;
    Rect toView(QuizHighlight box) => Rect.fromLTWH(
          dst.left + (box.x * iw - src.left) * sx,
          dst.top + (box.y * ih - src.top) * sy,
          box.w * iw * sx,
          box.h * ih * sy,
        );

    for (var i = 0; i < diagram.erase.length; i++) {
      final box = toView(diagram.erase[i]).inflate(3);
      final isTarget = i == diagram.targetIndex;
      final rrect = RRect.fromRectAndRadius(box, const Radius.circular(5));

      // Opaque: a translucent wash leaves the word readable underneath, which
      // is the whole failure this exists to prevent.
      canvas.drawRRect(rrect, Paint()..color = coverColor);
      canvas.drawRRect(
        rrect,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = isTarget ? 2.5 : 1
          ..color = isTarget ? marker : coverLine,
      );
      _paintNumber(canvas, box, i + 1, isTarget);
    }
  }

  /// The number a student answers against. The asked-about one is filled.
  void _paintNumber(Canvas canvas, Rect box, int number, bool isTarget) {
    const radius = 9.0;
    final centre = Offset(box.left - radius * 0.2, box.center.dy);
    canvas.drawCircle(
      centre,
      radius,
      Paint()..color = isTarget ? marker : coverColor,
    );
    canvas.drawCircle(
      centre,
      radius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..color = isTarget ? marker : coverLine,
    );
    final painter = TextPainter(
      text: TextSpan(
        text: '$number',
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: isTarget ? markerOn : coverLine,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    painter.paint(
      canvas,
      centre - Offset(painter.width / 2, painter.height / 2),
    );
  }

  Rect _fit(Rect src, Size size) {
    final scale = (size.width / src.width) < (size.height / src.height)
        ? size.width / src.width
        : size.height / src.height;
    final w = src.width * scale;
    final h = src.height * scale;
    return Rect.fromLTWH((size.width - w) / 2, (size.height - h) / 2, w, h);
  }

  Rect _shiftInside(Rect r, Rect bounds) {
    var out = r;
    if (out.width > bounds.width) {
      out = Rect.fromLTWH(bounds.left, out.top, bounds.width, out.height);
    }
    if (out.height > bounds.height) {
      out = Rect.fromLTWH(out.left, bounds.top, out.width, bounds.height);
    }
    var dx = 0.0;
    var dy = 0.0;
    if (out.left < bounds.left) dx = bounds.left - out.left;
    if (out.right > bounds.right) dx = bounds.right - out.right;
    if (out.top < bounds.top) dy = bounds.top - out.top;
    if (out.bottom > bounds.bottom) dy = bounds.bottom - out.bottom;
    return out.shift(Offset(dx, dy));
  }

  @override
  bool shouldRepaint(_FigurePainter old) =>
      old.image != image ||
      old.spot != spot ||
      old.figure != figure ||
      old.marker != marker ||
      old.coverColor != coverColor;
}
