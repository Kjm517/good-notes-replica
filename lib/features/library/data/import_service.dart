import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:drift/drift.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:pdfx/pdfx.dart';
import 'package:uuid/uuid.dart';

import '../../../core/db/database.dart';
import '../../../core/models/enums.dart';
import 'asset_repository.dart';

/// Reports import progress: [fraction] 0..1 and a human-readable [label].
typedef ImportProgress = void Function(double fraction, String label);

/// Raised when the user picks a document we can't render directly.
///
/// PowerPoint and Word files are zipped OOXML, not page images — rendering
/// them faithfully means implementing most of Office. GoodNotes has the same
/// limitation and solves it by converting to PDF on import (using Apple's
/// system converter, which isn't available to us). So we ask for a PDF.
class UnsupportedImportFormat implements Exception {
  const UnsupportedImportFormat(this.filename, this.extension);

  final String filename;
  final String extension;

  bool get isPresentation =>
      extension == 'ppt' || extension == 'pptx' || extension == 'key';

  String get appName => switch (extension) {
        'ppt' || 'pptx' => 'PowerPoint',
        'key' => 'Keynote',
        'doc' || 'docx' => 'Word',
        _ => 'the app that made it',
      };
}

/// Office formats we recognise well enough to explain, but can't render.
const List<String> kConvertibleExtensions = [
  'ppt', 'pptx', 'key', 'doc', 'docx',
];

/// Imports external files (PDFs, images) as annotatable documents. Each PDF
/// page / image becomes a [NotePage] whose background is the source content,
/// so it can be highlighted and written on like in GoodNotes.
class ImportService {
  ImportService(this._db, this._uuid, this._assets, {this.ownerUid});

  final AppDatabase _db;
  final Uuid _uuid;
  final AssetRepository _assets;

  /// Account that will own the imported document (null when signed out).
  final String? ownerUid;

  /// Prompts for image files and creates a document with one page per image.
  /// Returns the new document id, or null if cancelled.
  Future<String?> importImages({
    String? parentId,
    ImportProgress? onProgress,
  }) async {
    final result = await FilePicker.pickFiles(
      type: FileType.image,
      allowMultiple: true,
      withData: true,
    );
    if (result == null || result.files.isEmpty) return null;

    final total = result.files.length;
    onProgress?.call(0, 'Preparing $total image${total == 1 ? '' : 's'}…');
    final docId = _uuid.v4();
    final title = _titleFrom(result.files.first.name);
    await _db.transaction(() async {
      await _db.into(_db.documents).insert(DocumentsCompanion.insert(
            id: docId,
            type: DocumentType.notebook,
            title: Value(title),
            parentId: Value(parentId),
            ownerUid: Value(ownerUid),
          ));
      var index = 0;
      String? coverThumb;
      for (final file in result.files) {
        final bytes = file.bytes;
        if (bytes == null) continue;
        // Keep an independent copy for storage: decoding below can detach the
        // original buffer (esp. on web), which would corrupt the DB write.
        final stored = Uint8List.fromList(bytes);
        final size = await _imageSize(bytes);
        final assetId = await _assets.store(
          id: _uuid.v4(),
          bytes: stored,
          kind: 0,
          filename: file.name,
          mime: _mimeFromExt(file.extension),
        );
        await _db.into(_db.notePages).insert(NotePagesCompanion.insert(
              id: _uuid.v4(),
              documentId: docId,
              pageIndex: index++,
              template: const Value(PaperTemplate.blank),
              bgAssetId: Value(assetId),
              pageW: Value(size.width),
              pageH: Value(size.height),
            ));
        coverThumb ??= base64Encode(stored);
        onProgress?.call(index / total, 'Imported $index of $total images');
      }
      if (coverThumb != null) {
        await (_db.update(_db.documents)..where((d) => d.id.equals(docId)))
            .write(DocumentsCompanion(coverThumb: Value(coverThumb)));
      }
    });
    onProgress?.call(1, 'Done');
    return docId;
  }

  /// Prompts for a PDF and creates a document with one page per PDF page.
  Future<String?> importPdf({
    String? parentId,
    ImportProgress? onProgress,
  }) async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      // Office formats are accepted by the picker so selecting one gives a
      // useful explanation instead of the file being silently unselectable.
      allowedExtensions: ['pdf', ...kConvertibleExtensions],
      // Only ask for bytes on web. On Android the picker loads the whole file
      // into a single Java byte[] before it ever reaches Dart, and anything
      // past the ~192 MB heap limit throws OutOfMemoryError on a plugin
      // coroutine — an uncaught crash that kills the process where no Dart
      // catch can see it. Native imports stream from the path instead.
      withData: kIsWeb,
    );
    if (result == null || result.files.isEmpty) return null;
    final file = result.files.first;

    final extension = (file.extension ?? '').toLowerCase();
    if (extension != 'pdf') {
      throw UnsupportedImportFormat(file.name, extension);
    }

    final path = file.path;
    if (!kIsWeb && path != null) {
      return _importPdfFromPath(
        path: path,
        name: file.name,
        parentId: parentId,
        onProgress: onProgress,
      );
    }

    final bytes = file.bytes;
    if (bytes == null) return null;

    final docId = _uuid.v4();
    final assetId = _uuid.v4();
    final title = _titleFrom(file.name);

    // Keep an independent copy for storage FIRST: PdfDocument.openData can
    // transfer/detach the original buffer on web, which would then corrupt the
    // database write below.
    final stored = Uint8List.fromList(bytes);
    final mb = (stored.length / 1e6).toStringAsFixed(1);
    onProgress?.call(0, 'Opening PDF ($mb MB)…');

    // Read page sizes up front (may detach `bytes`; `stored` is unaffected).
    final doc = await PdfDocument.openData(bytes);
    final count = doc.pagesCount;

    // Render the cover now, while the document is already open. Doing it later
    // would mean re-opening the whole file just to draw a card-sized preview.
    final coverThumb = await _renderPdfCover(doc);

    final sizes = await _measurePages(doc, count, onProgress);
    await doc.close();
    onProgress?.call(0.9, 'Saving $count pages…');

    await _db.transaction(() async {
      await _db.into(_db.documents).insert(DocumentsCompanion.insert(
            id: docId,
            type: DocumentType.pdf,
            title: Value(title),
            parentId: Value(parentId),
            coverThumb: Value(coverThumb),
            ownerUid: Value(ownerUid),
          ));
      await _assets.store(
        id: assetId,
        bytes: stored,
        kind: 1,
        filename: file.name,
        mime: 'application/pdf',
      );
      // One batched insert instead of 4,895 round-trips.
      await _db.batch((batch) {
        batch.insertAll(_db.notePages, [
          for (var i = 0; i < sizes.length; i++)
            NotePagesCompanion.insert(
              id: _uuid.v4(),
              documentId: docId,
              pageIndex: i,
              template: const Value(PaperTemplate.blank),
              pdfAssetId: Value(assetId),
              pdfPageIndex: Value(i),
              pageW: Value(sizes[i].width),
              pageH: Value(sizes[i].height),
            ),
        ]);
      });
    });
    onProgress?.call(1, 'Done');
    return docId;
  }

  /// Imports a PDF that is already on disk, streaming it into asset storage.
  ///
  /// Nothing here holds the file in memory: pdfium reads it via its own file
  /// handle and the asset copy goes file-to-file, so import cost is flat in
  /// the size of the PDF rather than linear.
  Future<String?> _importPdfFromPath({
    required String path,
    required String name,
    String? parentId,
    ImportProgress? onProgress,
  }) async {
    final docId = _uuid.v4();
    final assetId = _uuid.v4();
    final title = _titleFrom(name);

    onProgress?.call(0, 'Opening PDF…');
    final doc = await PdfDocument.openFile(path);
    final count = doc.pagesCount;

    final coverThumb = await _renderPdfCover(doc);
    final sizes = await _measurePages(doc, count, onProgress);
    await doc.close();

    onProgress?.call(0.9, 'Saving $count pages…');
    // Copy outside the transaction: it is the slow part for a large file, and
    // holding a write transaction open across it would block every other
    // reader for the duration.
    final storedAssetId = await _assets.storeFile(
      id: assetId,
      sourcePath: path,
      kind: 1,
      filename: name,
      mime: 'application/pdf',
    );

    await _db.transaction(() async {
      await _db.into(_db.documents).insert(DocumentsCompanion.insert(
            id: docId,
            type: DocumentType.pdf,
            title: Value(title),
            parentId: Value(parentId),
            coverThumb: Value(coverThumb),
            ownerUid: Value(ownerUid),
          ));
      await _db.batch((batch) {
        batch.insertAll(_db.notePages, [
          for (var i = 0; i < sizes.length; i++)
            NotePagesCompanion.insert(
              id: _uuid.v4(),
              documentId: docId,
              pageIndex: i,
              template: const Value(PaperTemplate.blank),
              pdfAssetId: Value(storedAssetId),
              pdfPageIndex: Value(i),
              pageW: Value(sizes[i].width),
              pageH: Value(sizes[i].height),
            ),
        ]);
      });
    });
    onProgress?.call(1, 'Done');
    return docId;
  }

  /// Page dimensions for every page.
  ///
  /// Opening 4,895 pages one at a time to read their size dominated import —
  /// minutes of work for information that is almost always identical on every
  /// page. So sample a handful first; if they agree, reuse that size for the
  /// whole document and only fall back to measuring each page when the
  /// document genuinely has mixed page sizes.
  Future<List<ui.Size>> _measurePages(
    PdfDocument doc,
    int count,
    ImportProgress? onProgress,
  ) async {
    onProgress?.call(0.05, 'Checking page sizes…');

    final probeIndexes = <int>{1, 2, (count / 2).ceil(), count}
        .where((i) => i >= 1 && i <= count)
        .toList();

    ui.Size? first;
    var uniform = true;
    for (final index in probeIndexes) {
      final page = await doc.getPage(index);
      final size = ui.Size(page.width, page.height);
      await page.close();
      first ??= size;
      if (size != first) uniform = false;
    }

    if (uniform && first != null) {
      onProgress?.call(0.85, 'All $count pages are the same size');
      return List<ui.Size>.filled(count, first);
    }

    // Mixed sizes: measure properly.
    final sizes = <ui.Size>[];
    for (var i = 1; i <= count; i++) {
      final page = await doc.getPage(i);
      sizes.add(ui.Size(page.width, page.height));
      await page.close();
      if (i % 25 == 0 || i == count) {
        onProgress?.call(0.05 + (i / count) * 0.8, 'Reading page $i of $count');
      }
    }
    return sizes;
  }

  /// A small PNG of page 1, base64 encoded, for the library card.
  Future<String?> _renderPdfCover(PdfDocument doc) async {
    try {
      final page = await doc.getPage(1);
      try {
        const targetWidth = 320.0;
        final scale = targetWidth / page.width;
        final rendered = await page.render(
          width: page.width * scale,
          height: page.height * scale,
          format: PdfPageImageFormat.png,
          backgroundColor: '#FFFFFF',
        );
        return rendered == null ? null : base64Encode(rendered.bytes);
      } finally {
        await page.close();
      }
    } catch (e) {
      debugPrint('Cover render failed: $e');
      return null;
    }
  }

  Future<ui.Size> _imageSize(Uint8List bytes) async {
    final codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    final size = ui.Size(
      frame.image.width.toDouble(),
      frame.image.height.toDouble(),
    );
    frame.image.dispose();
    codec.dispose();
    return size;
  }

  String _titleFrom(String filename) {
    final dot = filename.lastIndexOf('.');
    return dot > 0 ? filename.substring(0, dot) : filename;
  }

  String _mimeFromExt(String? ext) {
    switch (ext?.toLowerCase()) {
      case 'png':
        return 'image/png';
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'gif':
        return 'image/gif';
      case 'webp':
        return 'image/webp';
      default:
        return 'image/*';
    }
  }
}
