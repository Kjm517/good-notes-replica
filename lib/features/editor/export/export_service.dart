import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../../core/db/database.dart';
import '../../../core/ink/ink_stroke.dart';
import '../canvas/ink_painters.dart';
import '../pages/background_painter.dart';
import '../pages/page_background_service.dart';
import '../pages/paper_painter.dart';

/// Progress callback for a long export.
typedef ExportProgress = void Function(double fraction, String label);

/// Flattens pages (paper/PDF background + ink annotations) into images and
/// assembles them into a PDF for export, sharing or printing.
class ExportService {
  ExportService(this._backgrounds);

  final PageBackgroundService _backgrounds;

  /// Renders one page to a PNG at [pixelRatio] device pixels per point.
  Future<Uint8List?> renderPage({
    required NotePage page,
    required Size baseSize,
    required List<InkStroke> strokes,
    double pixelRatio = 2.0,
  }) async {
    final margins = page.marginSpec;
    final sheet = margins.outerSize(baseSize);
    final offset = margins.contentOffset;

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.scale(pixelRatio);

    final background = await _backgrounds.load(page);
    if (background != null) {
      BackgroundPainter(
        image: background,
        margins: margins,
        baseSize: baseSize,
      ).paint(canvas, sheet);
    } else {
      PaperPainter(
        template: page.template,
        paperColor: page.paperColor,
        margins: margins,
        baseSize: baseSize,
      ).paint(canvas, sheet);
    }

    CommittedInkPainter(strokes, offset: offset).paint(canvas, sheet);

    final picture = recorder.endRecording();
    final image = await picture.toImage(
      (sheet.width * pixelRatio).ceil(),
      (sheet.height * pixelRatio).ceil(),
    );
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    picture.dispose();
    image.dispose();
    background?.dispose();
    return data?.buffer.asUint8List();
  }

  /// Builds a PDF containing [pages] with their annotations flattened in.
  Future<Uint8List> buildPdf({
    required List<NotePage> pages,
    required Size Function(NotePage) sizeFor,
    required Future<List<InkStroke>> Function(String pageId) strokesFor,
    double pixelRatio = 2.0,
    ExportProgress? onProgress,
  }) async {
    final doc = pw.Document();
    for (var i = 0; i < pages.length; i++) {
      final page = pages[i];
      final base = sizeFor(page);
      final png = await renderPage(
        page: page,
        baseSize: base,
        strokes: await strokesFor(page.id),
        pixelRatio: pixelRatio,
      );
      if (png == null) continue;

      final sheet = page.marginSpec.outerSize(base);
      final image = pw.MemoryImage(png);
      doc.addPage(
        pw.Page(
          pageFormat: PdfPageFormat(sheet.width, sheet.height),
          build: (context) => pw.FullPage(
            ignoreMargins: true,
            child: pw.Image(image, fit: pw.BoxFit.fill),
          ),
        ),
      );
      onProgress?.call(
        (i + 1) / pages.length,
        'Rendering page ${i + 1} of ${pages.length}',
      );
    }
    return doc.save();
  }
}
