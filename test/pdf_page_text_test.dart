import 'package:flutter_test/flutter_test.dart';
import 'package:notably/features/editor/quiz/quiz_highlight_finder.dart';
import 'package:notably/features/editor/search/pdf_page_text.dart';
import 'package:pdf/pdf.dart' as w;
import 'package:pdf/widgets.dart' as pw;
import 'package:pdfrx/pdfrx.dart';

/// A two-column page, built to order: the left column at x=40, the right at
/// x=230, both starting near the top of a 400x600 page.
Future<PdfDocument> _twoColumnPdf() async {
  final doc = pw.Document();
  doc.addPage(
    pw.Page(
      pageFormat: const w.PdfPageFormat(400, 600),
      build: (_) => pw.Stack(
        children: [
          pw.Positioned(
            left: 40,
            top: 30,
            child: pw.SizedBox(
              width: 150,
              child: pw.Text(
                'Hypothermia is associated with increased mortality.',
                style: const pw.TextStyle(fontSize: 9),
              ),
            ),
          ),
          pw.Positioned(
            left: 230,
            top: 30,
            child: pw.SizedBox(
              width: 150,
              child: pw.Text(
                'Antimicrobials within one hour of recognition.',
                style: const pw.TextStyle(fontSize: 9),
              ),
            ),
          ),
        ],
      ),
    ),
  );
  return PdfDocument.openData(await doc.save());
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // pdfrxFlutterInitialize() is deliberately not called here: it asks
  // path_provider for a temp directory, which needs a plugin host the test
  // runner does not have. The engine itself loads on first use, which is all
  // these tests need.

  test('a real PDF page yields measured text lines', () async {
    final doc = await _twoColumnPdf();
    addTearDown(doc.dispose);

    // The regression this guards: opening with useProgressiveLoading left
    // `pages` holding only page one, so every lookup past it read nothing at
    // all and the highlighter fell back to a guessed box.
    expect(doc.pages, isNotEmpty);

    final lines = await readPageLines(doc.pages.first);
    expect(lines, isNotEmpty);
    expect(lines.every((l) => l.chars.isNotEmpty), isTrue);
  });

  test('text drawn at the top of the page is marked at the top', () async {
    final doc = await _twoColumnPdf();
    addTearDown(doc.dispose);
    final lines = await readPageLines(doc.pages.first);

    // PDF pages measure y upward from the bottom; the image measures it down
    // from the top. Getting that backwards mirrors every mark on the page.
    for (final line in lines) {
      expect(line.y, lessThan(0.3));
    }
  });

  test('the two columns are separate lines, never one across the gutter',
      () async {
    final doc = await _twoColumnPdf();
    addTearDown(doc.dispose);
    final lines = await readPageLines(doc.pages.first);

    for (final line in lines) {
      expect(
        line.w,
        lessThan(0.5),
        reason: 'a line spanning the gutter paints ink across the page: '
            '"${line.text}"',
      );
    }
    expect(lines.any((l) => l.x < 0.5 && l.text.contains('Hypothermia')), isTrue);
    expect(
      lines.any((l) => l.x > 0.5 && l.text.contains('Antimicrobials')),
      isTrue,
    );
  });

  test('an answer is marked inside its own column', () async {
    final doc = await _twoColumnPdf();
    addTearDown(doc.dispose);
    final lines = await readPageLines(doc.pages.first);

    final match = findAnswerOnPage(
      lines: lines,
      answer: 'Within 1 hour of recognition',
      prompt: 'When should intravenous antimicrobials be initiated?',
    );
    expect(match.marks, isNotEmpty);
    for (final mark in match.marks) {
      expect(mark.x, greaterThan(0.5), reason: 'the answer is in the right column');
      expect(mark.y, lessThan(0.3));
    }
  });
}
