import 'dart:async';

import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:pdfrx/pdfrx.dart';

import '../../../core/db/database.dart';
import '../../library/data/asset_repository.dart';
import '../data/page_repository.dart';
import '../search/pdf_page_text.dart';
import '../search/pdf_text_line.dart';
import 'quiz_align.dart';
import 'quiz_highlight_finder.dart';
import 'quiz_models.dart';
import 'quiz_quality.dart';

/// The page the answer is actually on, and the strokes to paint over it.
class QuizSourceMatch {
  const QuizSourceMatch({
    required this.pageIndex,
    required this.marks,
    this.exact = false,
    this.estimated = false,
    this.readable = true,
    this.citedReferenceList = false,
  });

  final int pageIndex;
  final List<QuizHighlight> marks;

  /// The answer's own wording was found on the page.
  final bool exact;

  /// The box is a guess rather than a measurement.
  final bool estimated;

  /// Some text could be read from the pages searched. False for a scan, where
  /// nothing can be found until OCR exists.
  final bool readable;

  /// The page the citation named turned out to be a bibliography — the
  /// citation was wrong, not the answer.
  final bool citedReferenceList;

  bool get found => marks.isNotEmpty;

  /// The part worth keeping on the question so this never has to run again.
  QuizAnswerLocation? get location => marks.isEmpty || estimated
      ? null
      : QuizAnswerLocation(pageIndex: pageIndex, marks: marks, exact: exact);
}

/// Finds where a quiz answer lives in the source document.
///
/// Gemini cites pages loosely: it will number a page by the folio printed on
/// it, or by its position in the sample it was given. So the citation is
/// treated as a lead, not a fact — the page whose text actually states the
/// answer wins, and the highlighter is drawn from that page's own text
/// geometry rather than from a guessed rectangle.
class QuizSourceLocator {
  QuizSourceLocator(this._db, this._pages, this._assets);

  final AppDatabase _db;
  final PageRepository _pages;
  final AssetRepository _assets;

  final _cache = <String, QuizSourceMatch>{};

  /// Opening a textbook costs seconds, and a quiz asks about a dozen answers
  /// in a row. The open document is kept warm between lookups and closed once
  /// the flurry is over, instead of being reopened per question.
  _PageReader? _reader;
  Timer? _idle;

  _PageReader _acquireReader() {
    _idle?.cancel();
    return _reader ??= _PageReader(_assets);
  }

  void _releaseReader() {
    _idle?.cancel();
    _idle = Timer(const Duration(seconds: 45), () {
      final reader = _reader;
      _reader = null;
      unawaited(reader?.close());
    });
  }

  /// Closes the warm document. Wired to the provider's disposal.
  void dispose() {
    _idle?.cancel();
    _idle = null;
    final reader = _reader;
    _reader = null;
    unawaited(reader?.close());
  }

  Future<QuizSourceMatch> locate({
    required String documentId,
    required List<int> candidatePages,
    required QuizSourceTarget target,
    Set<int> sourcePages = const {},
  }) async {
    final fallback = candidatePages.isEmpty ? 0 : candidatePages.first;
    // A found answer belongs to the answer, wherever the tap came from. A
    // failure only holds for the pages it actually looked at.
    final foundKey = '$documentId|${target.answer}';
    final missKey = '$foundKey|${candidatePages.join(',')}|${sourcePages.length}';
    final cached = _cache[foundKey] ?? _cache[missKey];
    if (cached != null) return cached;

    final match = await _locate(
      documentId: documentId,
      candidatePages: candidatePages,
      target: target,
      fallback: fallback,
      sourcePages: sourcePages,
    );
    if (_cache.length > 60) _cache.clear();
    _cache[match.found ? foundKey : missKey] = match;
    return match;
  }

  Future<QuizSourceMatch> _locate({
    required String documentId,
    required List<int> candidatePages,
    required QuizSourceTarget target,
    required int fallback,
    Set<int> sourcePages = const {},
  }) async {
    final referencePages = <int>{};

    /// Where to land when nothing matched. Never a bibliography: leaving the
    /// student on a wall of author names reads as the app being broken.
    QuizSourceMatch estimate({bool readable = true}) {
      final landing = candidatePages.firstWhere(
        (index) => !referencePages.contains(index),
        orElse: () => fallback,
      );
      // Gemini's guessed box is kept only where nothing could be read — on a
      // scan its look at the page image is all there is. Once the text has
      // been read and the answer is not in it, painting the guess anyway puts
      // a marker over unrelated type, which is worse than no marker at all.
      final useHint = !readable && landing == fallback && target.hint != null;
      return QuizSourceMatch(
        pageIndex: landing,
        marks: [if (useHint) target.hint!.asInkStroke()],
        estimated: useHint,
        readable: readable,
        citedReferenceList: referencePages.contains(fallback),
      );
    }

    if (target.isEmpty) return estimate();
    try {
      await loadQuizStopWords();
    } catch (_) {
      // Bundled asset missing (tests): term search still runs, just noisier.
    }

    final rows = await _pages.getPages(documentId);
    if (rows.isEmpty) return estimate();
    final byIndex = {for (final row in rows) row.pageIndex: row};

    // A lookup runs while the student waits, so it is bounded by the clock
    // rather than by how many pages the book has. The clock starts once the
    // document is open — opening a 150 MB textbook is a one-off cost that
    // should not eat the first question's search.
    DateTime? deadline;
    bool outOfTime() => deadline != null && DateTime.now().isAfter(deadline!);
    final reader = _acquireReader();
    final tried = <int>{};
    QuizSourceMatch? best;
    var bestScore = 0;
    var readAnyText = false;
    int? citedFolio;

    Future<bool> consider(int index, {bool always = false}) async {
      if (!byIndex.containsKey(index) || !tried.add(index)) return false;
      final row = byIndex[index]!;
      // Laying a page out costs a PDF parse. When Find has already extracted
      // this page, its text says for free whether the parse is worth it.
      final stored = row.searchText;
      if (!always &&
          stored != null &&
          stored.isNotEmpty &&
          !pageMightHoldAnswer(
            stored,
            answer: target.answer,
            prompt: target.prompt,
          )) {
        return false;
      }
      final lines = await reader.lines(row);
      deadline ??= DateTime.now().add(const Duration(seconds: 5));
      if (lines.isEmpty) return false;
      readAnyText = true;
      if (index == fallback) citedFolio ??= printedFolio(lines);
      // A reference list can score well — the answer's words are in the
      // article titles — so it is ruled out before anything is marked on it.
      if (isReferenceLines(lines)) {
        referencePages.add(index);
        return false;
      }
      final match = findAnswerOnPage(
        lines: lines,
        answer: target.answer,
        prompt: target.prompt,
        quote: target.quote,
      );
      if (!match.isEmpty && match.score > bestScore) {
        bestScore = match.score;
        best = QuizSourceMatch(
          pageIndex: index,
          marks: match.marks,
          exact: match.exact,
          citedReferenceList: referencePages.contains(fallback),
        );
      }
      // Only a match that is both verbatim and on-topic ends the search. A
      // phrase can appear anywhere in a textbook; stopping at the first one
      // marked a passing mention and never looked for the page that teaches
      // it.
      return match.conclusive;
    }

    try {
      // The cited page is always read: it is the page on screen, and its
      // folio and layout are what the rest of the search is calibrated on.
      for (final index in candidatePages) {
        if (await consider(index, always: index == fallback)) return best!;
      }

      // Gemini reads the folio off the page as readily as it counts pages in
      // the file. If those disagree, the citation may mean the printed number.
      if (citedFolio != null && candidatePages.isNotEmpty) {
        final shifted = fallback + (fallback + 1 - citedFolio!);
        if (shifted != fallback && await consider(shifted)) return best!;
      }

      final terms = answerSearchTerms(target.answer, target.prompt);
      for (final index in await _pagesMentioning(documentId, terms)) {
        if (await consider(index)) return best!;
        if (outOfTime()) break;
      }

      // The answer was written from these pages, so it is on one of them far
      // more often than not. They are already extracted for Find, so the gate
      // above rules most of them out for the price of a string search.
      if (best == null) {
        for (final index in _nearestFirst(sourcePages, fallback)) {
          if (outOfTime()) break;
          if (await consider(index)) return best!;
        }
      }

      // Nothing yet: the citation is usually close even when it is wrong, so
      // walk outwards from it before giving up.
      if (best == null) {
        for (final index in _neighbours(candidatePages)) {
          if (outOfTime()) break;
          if (await consider(index)) return best!;
        }
      }
      return best ?? estimate(readable: readAnyText);
    } catch (e) {
      debugPrint('Quiz source lookup failed for $documentId: $e');
      return estimate(readable: readAnyText);
    } finally {
      _releaseReader();
    }
  }

  /// The quiz's own source pages, closest to the citation first.
  List<int> _nearestFirst(Set<int> pages, int anchor) {
    final out = pages.toList()
      ..sort((a, b) => (a - anchor).abs().compareTo((b - anchor).abs()));
    return out;
  }

  /// Pages around each citation, nearest first.
  List<int> _neighbours(List<int> anchors, {int reach = 6}) {
    final out = <int>[];
    for (var step = 1; step <= reach; step++) {
      for (final anchor in anchors) {
        out.add(anchor - step);
        out.add(anchor + step);
      }
    }
    return [
      for (final index in out)
        if (index >= 0) index,
    ];
  }

  /// Indexed pages whose stored text mentions the answer's distinctive words.
  /// Only pages already extracted for Find are visible here; the cited page is
  /// always read directly, so an unindexed book still gets a highlight.
  Future<List<int>> _pagesMentioning(String documentId, List<String> terms) async {
    if (terms.isEmpty) return const [];
    final scored = <int, int>{};
    for (final term in terms.take(3)) {
      final rows = await (_db.select(_db.notePages)
            ..where(
              (p) =>
                  p.documentId.equals(documentId) &
                  p.deletedAt.isNull() &
                  p.searchText.like('%$term%'),
            )
            ..limit(30))
          .get();
      for (final row in rows) {
        final text = row.searchText ?? '';
        if (text.isEmpty || isReferencePage(text)) continue;
        scored[row.pageIndex] = scorePageForTerms(text, terms);
      }
    }
    final ranked = scored.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return [
      for (final entry in ranked.take(4))
        if (entry.value >= 2) entry.key,
    ];
  }
}

/// Reads text lines for single pages, keeping each PDF it touches open for
/// the handful of candidates one lookup checks.
///
/// Geometry comes from PDFium, via pdfrx: it reports a box for every
/// character on the page, so a line is assembled from measured glyphs rather
/// than guessed at. That matters because the page layout is what the
/// highlighter draws on — a hand-rolled grouping rule put ink across the
/// gutter of a two-column page, and estimated character widths put the start
/// of a mark in the wrong place.
class _PageReader {
  _PageReader(this._assets);

  final AssetRepository _assets;

  final _documents = <String, Future<PdfDocument?>>{};

  Future<List<PdfTextLine>> lines(NotePage page) async {
    final assetId = page.pdfAssetId;
    final pdfIndex = page.pdfPageIndex;
    if (assetId == null || pdfIndex == null) return const [];

    final document = await _openDocument(assetId);
    if (document == null) return const [];
    if (pdfIndex < 0 || pdfIndex >= document.pages.length) return const [];
    try {
      return await readPageLines(document.pages[pdfIndex]);
    } catch (e) {
      debugPrint('Could not read page $pdfIndex for highlighting: $e');
      return const [];
    }
  }

  Future<PdfDocument?> _openDocument(String assetId) {
    return _documents.putIfAbsent(assetId, () async {
      final path = await _assets.localPathOf(assetId);
      if (path == null) return null;
      try {
        // NOT useProgressiveLoading: that populates `pages` with the first
        // page only until loadPagesProgressively is called, so every lookup
        // past page one finds nothing. PDFium reads the file from disk either
        // way — the page list is what is being deferred, not the bytes.
        return await PdfDocument.openFile(path);
      } catch (e) {
        debugPrint('Highlight lookup could not open the PDF: $e');
        return null;
      }
    });
  }

  Future<void> close() async {
    final documents = _documents.values.toList();
    _documents.clear();
    for (final pending in documents) {
      (await pending)?.dispose();
    }
  }
}
