import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:pdfx/pdfx.dart';

import '../../../core/db/database.dart';
import '../../library/data/asset_repository.dart';

/// Loads and caches page background images: imported photos (decoded) and PDF
/// pages (rendered via pdfx). Images are cached per page id; opened PDF
/// documents are reused across their pages.
class PageBackgroundService {
  PageBackgroundService(this._assets);
  final AssetRepository _assets;

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
          final bytes = await _assets.getBytes(page.bgAssetId!);
          if (bytes != null) image = await _decode(bytes);
        } else if (page.pdfAssetId != null && page.pdfPageIndex != null) {
          image = await _renderPdfPage(page.pdfAssetId!, page.pdfPageIndex!);
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
  Future<ui.Image?> loadThumbnail(NotePage page,
      {double targetWidth = 300}) async {
    final existing = _thumbs[page.id];
    if (existing != null) return existing.clone();
    ui.Image? image;
    try {
      if (page.bgAssetId != null) {
        final bytes = await _assets.getBytes(page.bgAssetId!);
        if (bytes != null) {
          image = await _decode(bytes, targetWidth: targetWidth.round());
        }
      } else if (page.pdfAssetId != null && page.pdfPageIndex != null) {
        image = await _renderPdfPage(page.pdfAssetId!, page.pdfPageIndex!,
            targetWidth: targetWidth);
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
    final codec = await ui.instantiateImageCodec(bytes,
        targetWidth: targetWidth);
    final frame = await codec.getNextFrame();
    return frame.image;
  }

  Future<PdfDocument> _openPdf(String assetId) {
    return _pdfDocs.putIfAbsent(assetId, () async {
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
      // Web (no filesystem) and any legacy rows still stored inline.
      final bytes = await _assets.getBytes(assetId);
      if (bytes == null) {
        throw StateError('Missing PDF asset $assetId');
      }
      return PdfDocument.openData(bytes);
    });
  }

  Future<ui.Image?> _renderPdfPage(String assetId, int pageIndex,
      {double? targetWidth}) async {
    final doc = await _openPdf(assetId);
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
        format: PdfPageImageFormat.png,
        backgroundColor: '#FFFFFF',
      );
      if (rendered == null) return null;
      return _decode(rendered.bytes);
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

  /// A cached image for [page] if one is already available, without doing any
  /// work — used to paint something immediately instead of a blank page.
  ui.Image? cachedOrThumb(NotePage page) =>
      (_cache[page.id] ?? _thumbs[page.id])?.clone();

  /// Drops cached renders for a page (e.g. after its background changes).
  void evict(String pageId) {
    _cache.remove(pageId)?.dispose();
    _thumbs.remove(pageId)?.dispose();
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
  }
}
