import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/design.dart';
import '../../../core/db/database.dart';
import '../providers.dart';
import 'quiz_models.dart';
import 'quiz_source_locator.dart';

/// Modal showing the imported page (PDF render, photo, or scan) a quiz item
/// cited with "See page N", with the answer marked in highlighter.
///
/// The citation is a lead, not a fact — Gemini numbers pages by the folio
/// printed on them as often as by their position in the file. When [target]
/// is given the page's own text is read to find the answer, and the preview
/// settles on whichever page actually states it.
class QuizSourcePreview extends ConsumerStatefulWidget {
  const QuizSourcePreview({
    super.key,
    required this.documentId,
    required this.pageIndex,
    this.target,
    this.onResolved,
    this.onOpenInNotebook,
  });

  final String documentId;

  /// Zero-based page in the opened document.
  final int pageIndex;

  /// The answer to hunt for. Without it the page is shown unmarked.
  final QuizSourceTarget? target;

  /// Reports where the answer was found, so the caller can keep it on the
  /// question and never pay for the lookup twice.
  final void Function(QuizSourceMatch match)? onResolved;

  /// Opens the resolved page in the editor — which is not always the page the
  /// preview was asked for, so it takes the page index.
  final void Function(int pageIndex)? onOpenInNotebook;

  static Future<void> show(
    BuildContext context, {
    required String documentId,
    required int pageIndex,
    QuizSourceTarget? target,
    void Function(QuizSourceMatch match)? onResolved,
    void Function(int pageIndex)? onOpenInNotebook,
  }) {
    return showDialog<void>(
      context: context,
      builder: (ctx) => QuizSourcePreview(
        documentId: documentId,
        pageIndex: pageIndex,
        target: target,
        onResolved: onResolved,
        onOpenInNotebook: onOpenInNotebook,
      ),
    );
  }

  @override
  ConsumerState<QuizSourcePreview> createState() => _QuizSourcePreviewState();
}

class _QuizSourcePreviewState extends ConsumerState<QuizSourcePreview> {
  late int _pageIndex = widget.pageIndex;
  ui.Image? _image;
  var _loading = true;
  var _locating = false;
  var _missing = false;
  List<QuizHighlight> _marks = const [];
  var _estimated = false;
  var _searched = false;
  var _exact = false;
  var _readable = true;
  var _citedReferenceList = false;
  final _transform = TransformationController();
  var _zoomed = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(_run());
    });
  }

  /// Renders the cited page straight away, then moves to the page that holds
  /// the answer if the lookup finds a better one.
  Future<void> _run() async {
    final target = widget.target;
    if (target == null || target.isEmpty) {
      await _loadImage(_pageIndex);
      return;
    }
    // Already resolved for this answer — paint it and render that page
    // directly, with no second look at the PDF.
    final known = target.location;
    if (known != null) {
      setState(() {
        _pageIndex = known.pageIndex;
        _marks = known.marks;
        _exact = known.exact;
        _searched = true;
      });
      await _loadImage(known.pageIndex);
      return;
    }
    setState(() => _locating = true);
    final pending = _loadImage(_pageIndex);
    QuizSourceMatch match;
    try {
      match = await ref.read(quizSourceLocatorProvider).locate(
            documentId: widget.documentId,
            candidatePages: [
              widget.pageIndex,
              if (target.sourcePageIndex != null &&
                  target.sourcePageIndex != widget.pageIndex)
                target.sourcePageIndex!,
            ],
            target: target,
          );
    } finally {
      await pending;
    }
    widget.onResolved?.call(match);
    if (!mounted) return;
    setState(() {
      _locating = false;
      _searched = true;
      _marks = match.marks;
      _exact = match.exact;
      _estimated = match.estimated;
      _readable = match.readable;
      _citedReferenceList = match.citedReferenceList;
    });
    if (match.pageIndex != _pageIndex) {
      setState(() {
        _pageIndex = match.pageIndex;
        _loading = true;
        _zoomed = false;
      });
      await _loadImage(match.pageIndex);
    }
  }

  Future<void> _loadImage(int pageIndex) async {
    final pages =
        await ref.read(pageRepositoryProvider).getPages(widget.documentId);
    NotePage? page;
    for (final row in pages) {
      if (row.pageIndex == pageIndex) {
        page = row;
        break;
      }
    }
    if (!mounted) return;
    if (page == null) {
      setState(() {
        _loading = false;
        _missing = true;
      });
      return;
    }
    final dpr = MediaQuery.devicePixelRatioOf(context);
    final width = MediaQuery.sizeOf(context).width;
    final target = (width * dpr).clamp(480.0, 1400.0);
    final image = await ref
        .read(pageBackgroundServiceProvider)
        .loadThumbnail(page, targetWidth: target);
    if (!mounted || pageIndex != _pageIndex) {
      image?.dispose();
      return;
    }
    setState(() {
      _image?.dispose();
      _image = image;
      _loading = false;
      _missing = image == null;
    });
  }

  @override
  void dispose() {
    _transform.dispose();
    _image?.dispose();
    super.dispose();
  }

  /// Frames the marked passage so the student lands on it instead of hunting
  /// across a full textbook page.
  void _zoomToMarks(Size viewport, Rect dest, List<Rect> boxes) {
    if (_zoomed || boxes.isEmpty) return;
    _zoomed = true;
    var box = boxes.first;
    for (final rect in boxes.skip(1)) {
      box = box.expandToInclude(rect);
    }
    box = box.inflate(28);
    final scale = math
        .min(
          viewport.width / math.max(box.width, 1),
          viewport.height / math.max(box.height, 1),
        )
        .clamp(1.15, 4.5);
    _transform.value = Matrix4.identity()
      ..translateByDouble(viewport.width / 2, viewport.height / 2, 0, 1)
      ..scaleByDouble(scale, scale, 1, 1)
      ..translateByDouble(-box.center.dx, -box.center.dy, 0, 1);
  }

  /// Says plainly what the marker means — and, when there is nothing to mark,
  /// why. A page shown without explanation reads as a bug.
  String get _caption {
    if (_locating) return 'finding the answer…';
    if (_marks.isNotEmpty) {
      if (_estimated) return 'answer is near here';
      // Only the answer's own wording earns the confident wording; a match on
      // its key terms is a good lead, and says so.
      return _exact ? 'answer highlighted' : 'closest match highlighted';
    }
    if (!_searched) return '';
    if (_citedReferenceList) return 'the cited page was the reference list';
    return _readable ? 'answer not found on this page' : 'scan — no text to mark';
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final number = _pageIndex + 1;
    final caption = _caption;
    return Dialog(
      backgroundColor: t.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Radii.sheet),
      ),
      insetPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 28),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560, maxHeight: 720),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 8, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      caption.isEmpty ? 'Page $number' : 'Page $number · $caption',
                      style: AppTokens.mono(
                        size: 14,
                        color: t.text,
                        weight: FontWeight.w700,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Close',
                    onPressed: () => Navigator.of(context).pop(),
                    icon: Icon(Icons.close_rounded, color: t.textMuted),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              SizedBox(
                height:
                    (MediaQuery.sizeOf(context).height * 0.55).clamp(240.0, 520.0),
                width: double.infinity,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(Radii.control),
                  child: ColoredBox(
                    color: t.fill,
                    child: _body(t),
                  ),
                ),
              ),
              if (widget.onOpenInNotebook != null) ...[
                const SizedBox(height: 10),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () {
                      final page = _pageIndex;
                      Navigator.of(context).pop();
                      widget.onOpenInNotebook!(page);
                    },
                    child: Text(
                      'Open in notebook',
                      style: TextStyle(color: t.premiumText),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _body(AppTokens t) {
    if (_loading) {
      return Center(
        child: CircularProgressIndicator(color: t.premium),
      );
    }
    if (_missing || _image == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'No photo or PDF image on this page.',
            textAlign: TextAlign.center,
            style: TextStyle(color: t.textMuted),
          ),
        ),
      );
    }
    final image = _image!;
    final marks = [for (final mark in _marks) mark.asInkStroke()];
    return LayoutBuilder(
      builder: (context, constraints) {
        final viewport = constraints.biggest;
        final src = Size(image.width.toDouble(), image.height.toDouble());
        final dest = Alignment.center.inscribe(
          applyBoxFit(BoxFit.contain, src, viewport).destination,
          Offset.zero & viewport,
        );
        final boxes = [
          for (final mark in marks)
            Rect.fromLTWH(
              dest.left + mark.x * dest.width,
              dest.top + mark.y * dest.height,
              mark.w * dest.width,
              math.max(mark.h * dest.height, 12),
            ),
        ];
        if (boxes.isNotEmpty) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) _zoomToMarks(viewport, dest, boxes);
          });
        }
        return InteractiveViewer(
          transformationController: _transform,
          minScale: 0.8,
          maxScale: 6,
          child: SizedBox(
            width: viewport.width,
            height: viewport.height,
            child: Stack(
              children: [
                Positioned.fromRect(
                  rect: dest,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      RawImage(image: image, fit: BoxFit.fill),
                      for (final mark in marks)
                        Positioned(
                          left: mark.x * dest.width,
                          top: mark.y * dest.height,
                          width: mark.w * dest.width,
                          height: math.max(mark.h * dest.height, 12),
                          child: IgnorePointer(
                            child: _HighlighterMark(
                              color: t.pdfBadge.withValues(alpha: 0.20),
                            ),
                          ),
                        ),
                    ],
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

/// Soft red marker stroke — light enough that the printed type stays readable.
class _HighlighterMark extends StatelessWidget {
  const _HighlighterMark({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _HighlighterPainter(color: color),
    );
  }
}

class _HighlighterPainter extends CustomPainter {
  const _HighlighterPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width < 2 || size.height < 2) return;
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;

    final inkH = size.height * 0.70;
    final top = size.height * 0.05;
    final inset = math.min(4.0, size.width * 0.015);
    final rect = Rect.fromLTWH(
      inset,
      top,
      math.max(2, size.width - inset * 2),
      inkH,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, Radius.circular(inkH / 2)),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant _HighlighterPainter oldDelegate) =>
      oldDelegate.color != color;
}

/// Explanation body with tappable "See page N" citations.
class QuizExplanationText extends StatelessWidget {
  const QuizExplanationText({
    super.key,
    required this.explanation,
    required this.fallbackPageIndex,
    required this.onOpenPage,
    this.target,
  });

  final String explanation;

  /// Zero-based page if Gemini omitted a "See page N" citation.
  final int fallbackPageIndex;

  /// The answer the preview should highlight, whichever page it opens.
  final QuizSourceTarget? target;
  final void Function(int pageIndex, [QuizSourceTarget? target]) onOpenPage;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    var parts = parseExplanationPageLinks(explanation);
    final hasLink = parts.any((p) => p.pageNumber != null);
    if (!hasLink) {
      parts = [
        ...parts,
        if (explanation.trim().isNotEmpty)
          const ExplanationSegment(text: ' '),
        ExplanationSegment(
          text: 'See page ${fallbackPageIndex + 1}.',
          pageNumber: fallbackPageIndex + 1,
        ),
      ];
    }
    final bodyStyle = TextStyle(height: 1.45, color: t.textSecondary);
    final linkStyle = AppTokens.mono(
      size: 13,
      color: t.premiumText,
      weight: FontWeight.w700,
    ).copyWith(
      decoration: TextDecoration.underline,
      decorationColor: t.premiumText,
      height: 1.45,
    );
    return Text.rich(
      TextSpan(
        style: bodyStyle,
        children: [
          for (final part in parts)
            if (part.pageNumber == null)
              TextSpan(text: part.text)
            else
              WidgetSpan(
                alignment: PlaceholderAlignment.baseline,
                baseline: TextBaseline.alphabetic,
                child: GestureDetector(
                  // The answer travels with the tap: wherever the preview
                  // settles, it still knows what to highlight.
                  onTap: () => onOpenPage(part.pageNumber! - 1, target),
                  child: Text(part.text, style: linkStyle),
                ),
              ),
        ],
      ),
    );
  }
}
