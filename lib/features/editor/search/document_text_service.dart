import 'dart:async';

import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart' as sf;

import '../../../core/db/database.dart';
import '../../../core/models/enums.dart';
import '../../../core/models/outline_entry.dart';
import '../../../core/storage/asset_store.dart';
import '../../library/data/asset_repository.dart';
import 'native_pdf_text.dart';
import 'outline_heading_detector.dart';

/// One hit from "find in document".
class SearchHit {
  const SearchHit({
    required this.pageId,
    required this.pageIndex,
    required this.snippet,
    required this.matchCount,
  });

  final String pageId;

  /// Zero-based position in the document.
  final int pageIndex;

  /// A little context around the first match, for the results list.
  final String snippet;
  final int matchCount;
}

/// Extracts and searches the text of PDF-backed documents.
///
/// The renderer (pdfx) cannot read text, so extraction uses a separate PDF
/// parser. It happens **once, in the background**, and the result is stored on
/// the page row — searching a 4,895-page book then costs one SQL query instead
/// of re-parsing 150 MB.
class DocumentTextService {
  DocumentTextService(this._db, this._assets);

  final AppDatabase _db;
  final AssetRepository _assets;

  /// In-flight text jobs, chained per document so a quiz extract and Find
  /// don't parse the same PDF at once — and a second caller waits instead of
  /// assuming the first run finished.
  final Map<String, Future<void>> _indexJobs = {};

  /// In-flight outline jobs, so editor-open and Find don't parse the PDF twice.
  final Map<String, Future<void>> _outlineJobs = {};

  /// Empty outlines cached before native file extract existed. Retry once
  /// per process so a 150 MB textbook can still get its bookmarks.
  final Set<String> _outlineNativeRetry = {};

  /// True once every page of [documentId] has been through extraction.
  Future<bool> isIndexed(String documentId) async {
    final pending =
        await (_db.select(_db.notePages)
              ..where(
                (p) =>
                    p.documentId.equals(documentId) &
                    p.deletedAt.isNull() &
                    p.searchText.isNull(),
              )
              ..limit(1))
            .get();
    return pending.isEmpty;
  }

  /// Extracts text for pages that don't have it yet.
  ///
  /// [pageIndices] limits the pass to those note-page indexes (quiz only
  /// needs a sample). [onProgress] reports 0..1. Safe to call repeatedly;
  /// already-indexed pages are skipped, so an interrupted run resumes.
  Future<void> index(
    String documentId, {
    void Function(double progress)? onProgress,
    Set<int>? pageIndices,
  }) {
    final previous = _indexJobs[documentId];
    late final Future<void> job;
    job = () async {
      if (previous != null) {
        try {
          await previous;
        } catch (_) {}
      }
      await _indexBody(
        documentId,
        onProgress: onProgress,
        pageIndices: pageIndices,
      );
    }();
    _indexJobs[documentId] = job;
    return job.whenComplete(() {
      if (identical(_indexJobs[documentId], job)) {
        _indexJobs.remove(documentId);
      }
    });
  }

  Future<void> _indexBody(
    String documentId, {
    void Function(double progress)? onProgress,
    Set<int>? pageIndices,
  }) async {
    try {
      // Bookmarks (and heading fallback) must not wait on a 943-page text
      // pass — the sidebar needs the TOC as soon as the file is open.
      await ensureOutline(documentId);

      var pages =
          await (_db.select(_db.notePages)
                ..where(
                  (p) =>
                      p.documentId.equals(documentId) &
                      p.deletedAt.isNull() &
                      p.searchText.isNull(),
                )
                ..orderBy([(p) => OrderingTerm.asc(p.pageIndex)]))
              .get();
      if (pageIndices != null) {
        pages = [
          for (final page in pages)
            if (pageIndices.contains(page.pageIndex)) page,
        ];
      }
      if (pages.isEmpty) return;

      // Any PDF-backed page tells us which asset to open.
      final assetId = pages.first.pdfAssetId;
      if (assetId == null) {
        // Image-only document: nothing to extract, but mark it done so we
        // don't try again on every search.
        await _markEmpty(pages);
        return;
      }

      final path = await _assets.localPathOf(assetId);
      if (NativePdfText.isSupported && path != null) {
        final session = await NativePdfText.open(path);
        if (session != null) {
          try {
            await _extractPages(
              pages,
              onProgress: onProgress,
              read: session.extractPage,
            );
            return;
          } finally {
            await session.close();
          }
        }
      }

      // Syncfusion only accepts a whole document in memory, and parsing it
      // costs several times the file on top. Past a certain size that is more
      // than the platform allows, and the process is killed with no error —
      // so a very large PDF stays unindexed rather than taking the app down.
      final size = await _assets.sizeOf(assetId);
      if (size != null && size > kMaxInMemoryAssetBytes) {
        debugPrint(
          'Skipping in-memory text extraction for $documentId: '
          '${(size / 1e6).round()} MB exceeds the Dart heap limit',
        );
        return;
      }

      final bytes = await _assets.getBytes(assetId);
      if (bytes == null) return;

      final document = sf.PdfDocument(inputBytes: bytes);
      final extractor = sf.PdfTextExtractor(document);
      try {
        await _extractPages(
          pages,
          onProgress: onProgress,
          read: (pdfIndex) => extractor.extractText(
            startPageIndex: pdfIndex,
            endPageIndex: pdfIndex,
          ),
        );
      } finally {
        document.dispose();
      }
    } catch (e) {
      debugPrint('Text extraction failed for $documentId: $e');
    }
  }

  Future<void> _extractPages(
    List<NotePage> pages, {
    void Function(double progress)? onProgress,
    required FutureOr<String> Function(int pdfPageIndex) read,
  }) async {
    for (var i = 0; i < pages.length; i++) {
      final page = pages[i];
      final pdfIndex = page.pdfPageIndex;
      if (pdfIndex == null) continue;
      String text;
      try {
        text = await read(pdfIndex);
      } catch (_) {
        text = '';
      }
      await (_db.update(
        _db.notePages,
      )..where((p) => p.id.equals(page.id))).write(
        NotePagesCompanion(
          searchText: Value(text.toLowerCase()),
          // Extraction is a derived cache, not user content — don't dirty
          // the row or every page would be re-uploaded to the cloud.
          dirty: const Value(false),
        ),
      );
      if (i % 4 == 0 || i == pages.length - 1) {
        onProgress?.call((i + 1) / pages.length);
        await Future<void>.delayed(Duration.zero);
      }
    }
  }

  /// True when any of [pageIndices] (or the whole document) still has no
  /// extraction attempt stored. Distinguishes "parser skipped" from "scan".
  Future<bool> hasUnextractedPages(
    String documentId, {
    Set<int>? pageIndices,
  }) async {
    final pages =
        await (_db.select(_db.notePages)
              ..where(
                (p) =>
                    p.documentId.equals(documentId) &
                    p.deletedAt.isNull() &
                    p.searchText.isNull(),
              )
              ..limit(pageIndices == null ? 1 : 4000))
            .get();
    if (pageIndices == null) return pages.isNotEmpty;
    return pages.any((p) => pageIndices.contains(p.pageIndex));
  }

  /// Loads the PDF's table of contents (embedded bookmarks first, heading
  /// heuristics only if there are none). Cached on [Documents.outline].
  ///
  /// Safe to call from the editor on open: bookmarks are a handful of catalog
  /// objects, not a 943-page text extract. OCR is not attempted; a scanned
  /// file with neither bookmarks nor text stores an empty list so we don't
  /// retry. A later OCR pass can overwrite that column.
  Future<void> ensureOutline(String documentId) {
    return _outlineJobs.putIfAbsent(documentId, () async {
      try {
        await _ensureOutline(documentId);
      } finally {
        _outlineJobs.remove(documentId);
      }
    });
  }

  Future<void> _ensureOutline(String documentId) async {
    final doc = await (_db.select(
      _db.documents,
    )..where((d) => d.id.equals(documentId))).getSingleOrNull();
    if (doc == null) return;
    if (doc.type != DocumentType.pdf) {
      if (doc.outline == null) await _storeOutline(documentId, const []);
      return;
    }

    final cached = OutlineEntry.decode(doc.outline);
    if (cached.isNotEmpty) return;
    // `[]` means we already tried. Retry with the native file parser once
    // per process — older builds skipped 150 MB textbooks entirely.
    if (doc.outline != null && !_outlineNativeRetry.add(documentId)) return;

    final page = await (_db.select(_db.notePages)
          ..where(
            (p) =>
                p.documentId.equals(documentId) & p.pdfAssetId.isNotNull(),
          )
          ..limit(1))
        .getSingleOrNull();
    final assetId = page?.pdfAssetId;
    if (assetId == null) {
      if (doc.outline == null) await _storeOutline(documentId, const []);
      return;
    }

    final nativeEntries = await _outlineFromNative(assetId);
    if (nativeEntries != null && nativeEntries.isNotEmpty) {
      await _storeOutline(documentId, nativeEntries);
      return;
    }
    if (doc.outline != null) return;

    final size = await _assets.sizeOf(assetId);
    if (size != null && size > kMaxInMemoryAssetBytes) {
      debugPrint(
        'Skipping in-memory outline for $documentId: '
        '${(size / 1e6).round()} MB exceeds the Dart heap limit',
      );
      await _storeOutline(documentId, nativeEntries ?? const []);
      return;
    }

    final bytes = await _assets.getBytes(assetId);
    if (bytes == null) return;

    final document = sf.PdfDocument(inputBytes: bytes);
    try {
      var entries = _readOutline(document);
      if (entries.isEmpty) {
        entries = await _headingsFromDocument(document);
      }
      await _storeOutline(documentId, entries);
    } catch (e) {
      debugPrint('Outline extract failed for $documentId: $e');
      await _storeOutline(documentId, const []);
    } finally {
      document.dispose();
    }
  }

  Future<List<OutlineEntry>?> _outlineFromNative(String assetId) async {
    if (!NativePdfText.isSupported) return null;
    final path = await _assets.localPathOf(assetId);
    if (path == null) return null;
    final session = await NativePdfText.open(path);
    if (session == null) return null;
    try {
      return await session.outline();
    } finally {
      await session.close();
    }
  }

  /// Heading fallback when [document.bookmarks] is empty. Yields to the
  /// event loop every few pages so a 943-page scan doesn't freeze the UI.
  ///
  /// A future OCR pass belongs here: if extractTextLines returns nothing,
  /// we currently store an empty outline rather than rasterising pages.
  Future<List<OutlineEntry>> _headingsFromDocument(sf.PdfDocument document) async {
    final extractor = sf.PdfTextExtractor(document);
    final lines = <HeadingLine>[];
    final count = document.pages.count;
    for (var i = 0; i < count; i++) {
      List<sf.TextLine> pageLines;
      try {
        pageLines = extractor.extractTextLines(
          startPageIndex: i,
          endPageIndex: i,
        );
      } catch (_) {
        continue;
      }
      for (final line in pageLines) {
        final text = line.text.trim();
        if (text.isEmpty) continue;
        lines.add(HeadingLine(
          text: text,
          pageIndex: i,
          fontSize: line.fontSize,
          bold: line.fontStyle.contains(sf.PdfFontStyle.bold),
        ));
      }
      if (i % 4 == 0) await Future<void>.delayed(Duration.zero);
    }
    return [
      for (final hit in OutlineHeadingDetector.detect(lines))
        OutlineEntry(
          title: hit.title,
          pageIndex: hit.pageIndex,
          depth: hit.depth,
        ),
    ];
  }

  Future<void> _markEmpty(List<NotePage> pages) async {
    for (final page in pages) {
      await (_db.update(
        _db.notePages,
      )..where((p) => p.id.equals(page.id))).write(
        const NotePagesCompanion(searchText: Value(''), dirty: Value(false)),
      );
    }
  }

  /// Walks the PDF's bookmark tree into a flat, depth-tagged list. Each
  /// bookmark's destination is resolved to a zero-based page index so the
  /// sidebar can jump straight there. Bookmarks whose target can't be resolved
  /// are dropped rather than pointing at the wrong page.
  List<OutlineEntry> _readOutline(sf.PdfDocument document) {
    final entries = <OutlineEntry>[];

    void walk(sf.PdfBookmarkBase node, int depth) {
      for (var i = 0; i < node.count; i++) {
        final sf.PdfBookmark bookmark = node[i];
        String title;
        try {
          title = bookmark.title.trim();
        } catch (_) {
          title = '';
        }

        int? pageIndex;
        try {
          final destination =
              bookmark.destination ?? bookmark.namedDestination?.destination;
          if (destination != null) {
            final idx = document.pages.indexOf(destination.page);
            if (idx >= 0) pageIndex = idx;
          }
        } catch (_) {
          pageIndex = null;
        }

        if (title.isNotEmpty && pageIndex != null) {
          entries.add(
            OutlineEntry(title: title, pageIndex: pageIndex, depth: depth),
          );
        }

        if (bookmark.count > 0) walk(bookmark, depth + 1);
      }
    }

    try {
      walk(document.bookmarks, 0);
    } catch (e) {
      debugPrint('Outline read failed: $e');
    }
    return entries;
  }

  /// Persists the extracted outline as JSON. Only the outline column is
  /// written, leaving the row's dirty flag and updatedAt untouched — the
  /// outline is a derived cache that isn't synced, and touching those would
  /// either cause a needless re-push or (for a not-yet-synced import) drop the
  /// upload entirely.
  Future<void> _storeOutline(
    String documentId,
    List<OutlineEntry> entries,
  ) async {
    await (_db.update(
      _db.documents,
    )..where((d) => d.id.equals(documentId))).write(
      DocumentsCompanion(outline: Value(OutlineEntry.encode(entries))),
    );
  }

  /// Extracted page text for quiz generation. Empty pages (scans, pictures)
  /// are omitted; the caller should index first so [searchText] is populated.
  Future<List<({int pageIndex, String text})>> pageTexts(String documentId) async {
    final pages = await (_db.select(_db.notePages)
          ..where(
            (p) => p.documentId.equals(documentId) & p.deletedAt.isNull(),
          )
          ..orderBy([(p) => OrderingTerm.asc(p.pageIndex)]))
        .get();
    return [
      for (final page in pages)
        if ((page.searchText ?? '').trim().isNotEmpty)
          (pageIndex: page.pageIndex, text: page.searchText!),
    ];
  }

  /// Finds [query] across the document's extracted text.
  Future<List<SearchHit>> search(String documentId, String query) async {
    final needle = query.trim().toLowerCase();
    if (needle.isEmpty) return const [];

    final pages =
        await (_db.select(_db.notePages)
              ..where(
                (p) =>
                    p.documentId.equals(documentId) &
                    p.deletedAt.isNull() &
                    p.searchText.like('%$needle%'),
              )
              ..orderBy([(p) => OrderingTerm.asc(p.pageIndex)]))
            .get();

    return [
      for (final page in pages)
        SearchHit(
          pageId: page.id,
          pageIndex: page.pageIndex,
          snippet: _snippet(page.searchText ?? '', needle),
          matchCount: needle.allMatches(page.searchText ?? '').length,
        ),
    ];
  }

  /// A short window of text around the first match.
  String _snippet(String haystack, String needle) {
    final at = haystack.indexOf(needle);
    if (at < 0) return '';
    const padding = 45;
    final start = (at - padding).clamp(0, haystack.length);
    final end = (at + needle.length + padding).clamp(0, haystack.length);
    final text = haystack.substring(start, end).replaceAll(RegExp(r'\s+'), ' ');
    return '${start > 0 ? '…' : ''}$text${end < haystack.length ? '…' : ''}';
  }
}
