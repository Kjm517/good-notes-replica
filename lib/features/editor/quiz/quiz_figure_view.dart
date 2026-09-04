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
    if (old.question.pageIndex != widget.question.pageIndex) {
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
    // Rendered larger than the card: the crop below throws most of it away,
    // so the source has to carry the detail the zoom will need.
    final target = (width * dpr * 1.6).clamp(720.0, 2200.0);
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
                    spot: widget.question.highlight,
                    marker: t.premium,
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
    required this.spot,
    required this.marker,
  });

  final ui.Image image;
  final QuizHighlight? spot;
  final Color marker;

  @override
  void paint(Canvas canvas, Size size) {
    final iw = image.width.toDouble();
    final ih = image.height.toDouble();
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
      old.image != image || old.spot != spot || old.marker != marker;
}
