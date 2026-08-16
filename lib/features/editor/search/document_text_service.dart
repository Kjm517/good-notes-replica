import 'dart:async';

import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart' as sf;

import '../../../core/db/database.dart';
import '../../../core/models/enums.dart';
import '../../../core/models/outline_entry.dart';
import '../../../core/storage/asset_store.dart';
import '../../library/data/asset_repository.dart';

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

  /// Documents currently being indexed, so two callers don't duplicate work.
  final Set<String> _indexing = {};

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

  /// Extracts text for every page that doesn't have it yet.
  ///
  /// [onProgress] reports 0..1. Safe to call repeatedly; already-indexed pages
  /// are skipped, so an interrupted run resumes where it left off.
  Future<void> index(
    String documentId, {
    void Function(double progress)? onProgress,
  }) async {
    if (_indexing.contains(documentId)) return;
    _indexing.add(documentId);
    try {
      final doc = await (_db.select(
        _db.documents,
      )..where((d) => d.id.equals(documentId))).getSingleOrNull();
      // The outline is extracted the first time only: null means "never tried".
      final needsOutline =
          doc != null && doc.type == DocumentType.pdf && doc.outline == null;

      final pages =
          await (_db.select(_db.notePages)
                ..where(
                  (p) =>
                      p.documentId.equals(documentId) &
                      p.deletedAt.isNull() &
                      p.searchText.isNull(),
                )
                ..orderBy([(p) => OrderingTerm.asc(p.pageIndex)]))
              .get();
      if (pages.isEmpty && !needsOutline) return;

      // Any PDF-backed page tells us which asset to open; when text is already
      // indexed we still need one to reach the file for the outline.
      final assetId = pages.isNotEmpty
          ? pages.first.pdfAssetId
          : (await (_db.select(_db.notePages)
                      ..where(
                        (p) =>
                            p.documentId.equals(documentId) &
                            p.pdfAssetId.isNotNull(),
                      )
                      ..limit(1))
                    .getSingleOrNull())
                ?.pdfAssetId;
      if (assetId == null) {
        // Image-only document: nothing to extract, but mark it done so we
        // don't try again on every search.
        if (pages.isNotEmpty) await _markEmpty(pages);
        if (needsOutline) await _storeOutline(documentId, const []);
        return;
      }

      // The extractor only accepts a whole document in memory, and parsing it
      // costs several times the file on top. Past a certain size that is more
      // than the platform allows, and the process is killed with no error —
      // so a very large PDF stays unindexed and Find falls back to page
      // numbers rather than taking the app down with it.
      final size = await _assets.sizeOf(assetId);
      if (size != null && size > kMaxInMemoryAssetBytes) {
        debugPrint(
          'Skipping text extraction for $documentId: '
          '${(size / 1e6).round()} MB exceeds the in-memory limit',
        );
        return;
      }

      final bytes = await _assets.getBytes(assetId);
      if (bytes == null) return;

      final document = sf.PdfDocument(inputBytes: bytes);
      final extractor = sf.PdfTextExtractor(document);
      try {
        if (needsOutline) {
          await _storeOutline(documentId, _readOutline(document));
        }
        for (var i = 0; i < pages.length; i++) {
          final page = pages[i];
          final pdfIndex = page.pdfPageIndex;
          if (pdfIndex == null) continue;
          String text;
          try {
            text = extractor.extractText(
              startPageIndex: pdfIndex,
              endPageIndex: pdfIndex,
            );
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
          if (i % 10 == 0 || i == pages.length - 1) {
            onProgress?.call((i + 1) / pages.length);
            // Let the UI breathe between chunks.
            await Future<void>.delayed(Duration.zero);
          }
        }
      } finally {
        document.dispose();
      }
    } catch (e) {
      debugPrint('Text extraction failed for $documentId: $e');
    } finally {
      _indexing.remove(documentId);
    }
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
