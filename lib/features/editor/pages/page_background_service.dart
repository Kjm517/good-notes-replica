import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:pdfx/pdfx.dart';

import '../../../core/db/database.dart';
import '../../../core/storage/asset_store.dart';
import '../../../core/storage/page_render_cache.dart';
import '../../../core/sync/file_sync.dart';
import '../../library/data/asset_repository.dart';

/// Loads and caches page background images: imported photos (decoded) and PDF
/// pages (rendered via pdfx).
///
/// GPU textures stay tiny (a handful of full pages) so the device does not
/// run out of memory. Rendered PDF pages are also written to a local JPEG
/// cache: the first visit pays for PdfRenderer, later visits just decode
/// the file. The original PDF is kept as the source of truth.
class PageBackgroundService {
  PageBackgroundService(this._assets, {FileSync? files}) : _files = files;
  final AssetRepository _assets;
  final FileSync? _files;

  /// Full-resolution page images (insertion-ordered = oldest first).
  ///
  /// These are GPU textures: a single A4 page at [_maxRenderSide] is several
  /// megabytes, so the cache must stay small. Holding too many exhausts the
  /// GPU and the browser drops the WebGL context (CONTEXT_LOST_WEBGL), which
  /// blanks the whole canvas.
  final Map<String, ui.Image> _cache = {};
  static const int _maxCached = 6;

  /// Longest side of a rendered page, in pixels. Enough to stay crisp at 100%
  /// zoom without wasting texture memory.
  static const double _maxRenderSide = 1600;

  /// Small sidebar thumbnails — far cheaper, but still bounded.
  final Map<String, ui.Image> _thumbs = {};
  static const int _maxThumbs = 120;

  final Map<String, Future<PdfDocument>> _pdfDocs = {};
  final Map<String, Future<ui.Image?>> _inFlight = {};

  /// Tail of the render queue for each open PDF, so page access stays serial.
  final Map<String, Future<void>> _pdfQueue = {};

  /// Runs [action] with exclusive access to [assetId]'s document.
  ///
  /// Android renders PDFs through `PdfRenderer`, which allows exactly one open
  /// page per document — a second `openPage` while another is still open throws,
  /// and the plugin surfaces it only as "Unknown error". The canvas, the
  /// prefetcher and the sidebar thumbnails all draw from the same document, so
  /// without this queue most pages fail to render on a device slow enough for
  /// the requests to overlap.
  Future<T> _exclusive<T>(String assetId, Future<T> Function() action) {
    final previous = _pdfQueue[assetId] ?? Future<void>.value();
    final done = Completer<void>();
    _pdfQueue[assetId] = done.future;
    return previous.then((_) => action()).whenComplete(() {
      // Never completes with an error, so the next waiter always runs.
      done.complete();
      if (_pdfQueue[assetId] == done.future) _pdfQueue.remove(assetId);
    });
  }

  bool hasBackground(NotePage page) =>
      page.bgAssetId != null ||
      (page.pdfAssetId != null && page.pdfPageIndex != null);

  /// Returns a *clone* of the cached image. Callers own the clone and must
  /// dispose it; that lets the cache dispose its own copy on eviction without
  /// pulling the texture out from under a widget that is still painting it.
  Future<ui.Image?> load(NotePage page) {
    final existing = _cache[page.id];
    if (existing != null) return Future.value(existing.clone());
    // Coalesce concurrent requests for the same page (the canvas and the
    // sidebar can both ask at once).
    return _inFlight.putIfAbsent(page.id, () async {
      ui.Image? image;
      try {
        if (page.bgAssetId != null) {
          final bytes = await _bytesFor(page.bgAssetId!);
          if (bytes != null) image = await _decode(bytes);
        } else if (page.pdfAssetId != null && page.pdfPageIndex != null) {
          image = await _loadPdfPage(page);
        }
      } catch (e) {
        debugPrint('[bg] load failed for page ${page.id}: $e');
      } finally {
        _inFlight.remove(page.id);
      }
      if (image != null) {
        _cache[page.id] = image;
        _trim(_cache, _maxCached);
        return image.clone();
      }
      return null;
    });
  }

  /// Small preview for the sidebar / library card. [targetWidth] should be the
  /// *physical* pixel width (logical width × devicePixelRatio) so thumbnails
  /// stay crisp on high-DPI screens instead of being upscaled.
  Future<ui.Image?> loadThumbnail(
    NotePage page, {
    double targetWidth = 300,
  }) async {
    final existing = _thumbs[page.id];
    if (existing != null) return existing.clone();
    ui.Image? image;
    try {
      if (page.bgAssetId != null) {
        final bytes = await _bytesFor(page.bgAssetId!);
        if (bytes != null) {
          image = await _decode(bytes, targetWidth: targetWidth.round());
        }
      } else if (page.pdfAssetId != null && page.pdfPageIndex != null) {
        image = await _loadPdfPage(
          page,
          targetWidth: targetWidth,
          variant: pageRenderThumbKey(targetWidth.round()),
        );
      }
    } catch (e) {
      debugPrint('[bg] thumb failed for page ${page.id}: $e');
    }
    if (image != null) {
      _thumbs[page.id] = image;
      _trim(_thumbs, _maxThumbs);
      return image.clone();
    }
    return null;
  }

  /// Drops the oldest entries once [max] is exceeded, disposing the cache's
  /// handle. Widgets hold clones, so their copies stay valid until they too
  /// are disposed — the texture is freed once every holder lets go.
  void _trim(Map<String, ui.Image> cache, int max) {
    while (cache.length > max) {
      final key = cache.keys.first;
      cache.remove(key)?.dispose();
    }
  }

  Future<ui.Image> _decode(Uint8List bytes, {int? targetWidth}) async {
    final codec = await ui.instantiateImageCodec(
      bytes,
      targetWidth: targetWidth,
    );
    final frame = await codec.getNextFrame();
    return frame.image;
  }

  Future<PdfDocument> _openPdf(String assetId) {
    return _pdfDocs.putIfAbsent(assetId, () async {
      try {
        // Prefer opening straight from disk: pdfx then reads the file lazily
        // instead of us materialising the whole thing in memory. For a 150 MB
        // textbook that is the difference between a brief pause and a stall.
        final path = await _assets.localPathOf(assetId);
        if (path != null) {
          try {
            return await PdfDocument.openFile(path);
          } catch (e) {
            debugPrint('[bg] openFile failed, falling back to bytes: $e');
          }
        }
        // Web (no filesystem) and any legacy rows still stored inline. If the
        // row has no bytes yet (synced from another device), try R2 first.
        //
        // Reading the file whole is the last resort for a reason: a textbook
        // sized PDF does not fit in a single allocation on a phone, so failing
        // with a message beats being killed mid-render.
        final size = await _assets.sizeOf(assetId);
        if (size != null && size > kMaxInMemoryAssetBytes) {
          throw StateError(
            'PDF asset $assetId is ${(size / 1e6).round()} MB and cannot be '
            'opened from memory on this platform',
          );
        }
        final bytes = await _bytesFor(assetId);
        if (bytes == null) {
          throw StateError('Missing PDF asset $assetId');
        }
        return PdfDocument.openData(bytes);
      } catch (e) {
        // Drop the failed future so a later download / re-import can retry —
        // otherwise every page keeps failing forever after the first miss.
        _pdfDocs.remove(assetId);
        rethrow;
      }
    });
  }

  /// Local bytes, falling back to an R2 download when FileSync is configured.
  Future<Uint8List?> _bytesFor(String assetId) async {
    var bytes = await _assets.getBytes(assetId);
    if (bytes != null) return bytes;
    final ok = await _files?.download(assetId) ?? false;
    if (!ok) return null;
    return _assets.getBytes(assetId);
  }

  /// Disk JPEG if this page has been drawn before; otherwise PdfRenderer,
  /// then persist so the next open skips the renderer.
  Future<ui.Image?> _loadPdfPage(
    NotePage page, {
    double? targetWidth,
    String variant = kPageRenderFull,
  }) async {
    final cached = await readPageRender(page.id, variant);
    if (cached != null) {
      try {
        return await _decode(cached);
      } catch (e) {
        debugPrint('[bg] disk render corrupt for ${page.id}: $e');
        unawaited(deletePageRenders(page.id));
      }
    }
    return _renderPdfPage(
      page.pdfAssetId!,
      page.pdfPageIndex!,
      targetWidth: targetWidth,
      persistPageId: page.id,
      persistVariant: variant,
    );
  }

  Future<ui.Image?> _renderPdfPage(
    String assetId,
    int pageIndex, {
    double? targetWidth,
    String? persistPageId,
    String persistVariant = kPageRenderFull,
  }) async {
    final doc = await _openPdf(assetId);
    return _exclusive(
      assetId,
      () => _renderPdfPageLocked(
        doc,
        pageIndex,
        targetWidth,
        persistPageId: persistPageId,
        persistVariant: persistVariant,
      ),
    );
  }

  Future<ui.Image?> _renderPdfPageLocked(
    PdfDocument doc,
    int pageIndex,
    double? targetWidth, {
    String? persistPageId,
    String persistVariant = kPageRenderFull,
  }) async {
    final page = await doc.getPage(pageIndex + 1);
    try {
      double scale;
      if (targetWidth != null) {
        scale = targetWidth / page.width;
      } else {
        // ~2x for crisp text, capped so one page never becomes a huge texture.
        scale = 2.0;
        final longest = (page.width > page.height ? page.width : page.height);
        if (longest * scale > _maxRenderSide) {
          scale = _maxRenderSide / longest;
        }
      }
      final rendered = await page.render(
        width: page.width * scale,
        height: page.height * scale,
        format: PdfPageImageFormat.jpeg,
        quality: 85,
        backgroundColor: '#FFFFFF',
      );
      if (rendered == null) return null;
      final bytes = rendered.bytes;
      if (persistPageId != null) {
        unawaited(writePageRender(persistPageId, persistVariant, bytes));
      }
      return _decode(bytes);
    } finally {
      await page.close();
    }
  }

  /// Renders [pages] in the background without blocking the caller, so the
  /// next pages are ready by the time they scroll into view.
  void prefetch(Iterable<NotePage> pages) {
    // Keep this modest: each prefetched page occupies a cache slot, and the
    // cache is deliberately small to protect GPU memory.
    for (final page in pages.take(2)) {
      if (!hasBackground(page)) continue;
      if (_cache.containsKey(page.id) || _inFlight.containsKey(page.id)) {
        continue;
      }
      // Fire and forget; the result is cached, and the returned clone is
      // released immediately since no widget is waiting on it yet.
      unawaited(load(page).then((img) => img?.dispose()));
    }
  }

  /// How many pages the open-document overlay warms before handing the
  /// canvas to the user. Enough to start reading; the rest stay lazy.
  static const int prepareWindow = 8;

  /// Renders [pages] one by one and waits, so the editor can keep a modal
  /// up until a usable window is on disk / in RAM.
  Future<void> warmPages(
    List<NotePage> pages, {
    void Function(int done, int total)? onProgress,
  }) async {
    final list = [for (final page in pages) if (hasBackground(page)) page];
    for (var i = 0; i < list.length; i++) {
      final img = await load(list[i]);
      img?.dispose();
      onProgress?.call(i + 1, list.length);
    }
  }

  /// A cached image for [page] if one is already available, without doing any
  /// work — used to paint something immediately instead of a blank page.
  ui.Image? cachedOrThumb(NotePage page) =>
      (_cache[page.id] ?? _thumbs[page.id])?.clone();

  /// Drops cached renders for a page (e.g. after its background changes).
  void evict(String pageId) {
    _cache.remove(pageId)?.dispose();
    _thumbs.remove(pageId)?.dispose();
    unawaited(deletePageRenders(pageId));
  }

  Future<void> dispose() async {
    for (final image in _cache.values) {
      image.dispose();
    }
    _cache.clear();
    for (final image in _thumbs.values) {
      image.dispose();
    }
    _thumbs.clear();
    for (final docFuture in _pdfDocs.values) {
      try {
        (await docFuture).close();
      } catch (_) {}
    }
    _pdfDocs.clear();
    _pdfQueue.clear();
  }
}
