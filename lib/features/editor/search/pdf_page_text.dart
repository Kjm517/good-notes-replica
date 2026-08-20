import 'package:pdfrx/pdfrx.dart';

import 'pdf_text_line.dart';

/// Reads one page's text as lines with measured boxes.
///
/// PDFium reports a box per character, which is the accurate way round: lines
/// are assembled from glyphs that were actually placed, rather than guessed at
/// from baselines. Everything above this works in 0–1 fractions of the page,
/// top-left origin — the space the rendered page image uses.
Future<List<PdfTextLine>> readPageLines(PdfPage page) async {
  if (page.width <= 0 || page.height <= 0) return const [];
  final text = await page.loadStructuredText();
  return linesFromCharBoxes(
    text: text.fullText,
    boxes: charBoxesOf(text.charRects, page.width, page.height),
  );
}

/// Converts PDF-space character rects into the highlighter's space.
///
/// A PDF page measures y upward from the bottom and reports `top` as the
/// larger value; the page image measures it down from the top.
List<CharBox> charBoxesOf(
  Iterable<PdfRect> rects,
  double pageWidth,
  double pageHeight,
) {
  if (pageWidth <= 0 || pageHeight <= 0) return const [];
  return [
    for (final rect in rects)
      CharBox(
        x: rect.left / pageWidth,
        y: (pageHeight - rect.top) / pageHeight,
        w: rect.width.abs() / pageWidth,
        h: rect.height.abs() / pageHeight,
      ),
  ];
}
