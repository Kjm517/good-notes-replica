import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:pdfrx/pdfrx.dart';

import '../../../core/db/database.dart';
import '../../../core/storage/asset_store.dart';
import '../../../core/storage/page_render_cache.dart';
import '../../../core/sync/file_sync.dart';
import '../../library/data/asset_repository.dart';

/// Loads and caches page background images: imported photos (decoded) and PDF
/// pages (rendered via PDFium / pdfrx).
///
/// GPU textures stay tiny (a handful of full pages) so the device does not
/// run out of memory. Rendered PDF pages are also written to a local image
/// cache: the first visit pays for PDFium, later visits just decode the
/// file. The original PDF is kept as the source of truth.
class PageBackgroundService {
  PageBackgroundService(this._assets, {FileSync? files}) : _files = files;
  final AssetRepository _assets;
  final FileSync? _files;

  /// Full-resolution page images (insertion-ordered; [_touch] moves a hit
  /// to the end so [_trim] drops the least-recently used).
  ///
  /// These are GPU textures: a single A4 page at [_maxRenderSide] is several
  /// megabytes, so the cache must stay small. Holding too many exhausts the
  /// GPU and the browser drops the WebGL context (CONTEXT_LOST_WEBGL), which
  /// blanks the whole canvas. Web therefore stays at 6; native can hold more.
  final Map<String, ui.Image> _cache = {};
  static final int _maxCached = kIsWeb ? 6 : 12;

  /// Longest side of a rendered page, in pixels. Enough to stay crisp at 100%
  /// zoom without wasting texture memory.
  static const double _maxRenderSide = 1600;
  static const double _hiResRenderSide = 2800;
  static const double _thumbScaleCutoff = 0.6;
  static const double _hiResScaleCutoff = 2.0;

  /// Small sidebar thumbnails — far cheaper, but still bounded.
  final Map<String, ui.Image> _thumbs = {};
  static const int _maxThumbs = 120;

  final Map<String, Future<PdfDocument>> _pdfDocs = {};
  final Map<String, Future<ui.Image?>> _inFlight = {};

  /// Per-document render queues, ordered by [PageRenderPriority]. Native
  /// runs two PDFium jobs at once so the next page is already in flight
  /// while the current one is uploaded to the GPU. Web stays serial.
  final Map<String, _PdfRenderQueue> _pdfQueues = {};

  /// Bumped when scrolling settles. Queued prefetch/thumbnail jobs from a
  /// fling carry an older generation and are dropped instead of starting.
  int _generation = 0;

  /// Drops stale non-visible work from a fling. In-flight prefetch /
  /// thumbnail jobs are cancelled via PDFium's render token.
  void notifyScrollSettled() {
    _generation++;
    for (final queue in _pdfQueues.values) {
      queue.dropStale(_generation);
    }
  }

  /// Enqueues a PdfRenderer job. Visible work jumps the queue; prefetch and
  /// thumbnails wait, and are discarded if the user has scrolled on.
  Future<ui.Image?> _enqueuePdfRender({
    required String assetId,
    required int pageIndex,
    required PageRenderPriority priority,
    double? targetWidth,
    String? persistPageId,
    String persistVariant = kPageRenderFull,
    double maxRenderSide = _maxRenderSide,
  }) {
    final queue = _pdfQueues.putIfAbsent(assetId, _PdfRenderQueue.new);
    final key = '$assetId:$pageIndex:$persistVariant:${targetWidth ?? 'full'}';
    final existing = queue.job(key);
    if (existing != null) {
      if (priority.index < existing.priority.index) {
        existing.priority = priority;
      }
      existing.generation = _generation;
      return existing.completer.future;
    }
    final job = _PdfRenderJob(
      key: key,
      assetId: assetId,
      pageIndex: pageIndex,
      priority: priority,
      generation: _generation,
      targetWidth: targetWidth,
      persistPageId: persistPageId,
      persistVariant: persistVariant,
      maxRenderSide: maxRenderSide,
    );
    queue.enqueue(job);
    _pumpPdfQueue(assetId);
    return job.completer.future;
  }

  void _pumpPdfQueue(String assetId) {
    final queue = _pdfQueues[assetId];
    if (queue == null) return;
    queue.dropStale(_generation);
    while (!queue.atCapacity) {
      final job = queue.takeNext();
      if (job == null) {
        if (queue.activeCount == 0) _pdfQueues.remove(assetId);
        return;
      }
      queue.start(job);
      () async {
        try {
          final doc = await _openPdf(assetId);
          if (job.cancelToken?.isCanceled == true) {
            if (!job.completer.isCompleted) job.completer.complete(null);
            return;
          }
          final image = await _renderPdfPageLocked(
            doc,
            job,
          );
          if (!job.completer.isCompleted) job.completer.complete(image);
        } catch (e) {
          debugPrint('[bg] render failed for $assetId p${job.pageIndex}: $e');
          if (!job.completer.isCompleted) job.completer.complete(null);
        } finally {
          queue.finish(job);
          _pumpPdfQueue(assetId);
        }
      }();
    }
  }

  void _upgradeInFlight(
    NotePage page,
    PageRenderPriority priority,
    String variant,
  ) {
    final assetId = page.pdfAssetId;
    final pageIndex = page.pdfPageIndex;
    if (assetId == null || pageIndex == null) return;
    final queue = _pdfQueues[assetId];
    if (queue == null) return;
    final key = '$assetId:$pageIndex:$variant:full';
    final job = queue.job(key);
    if (job == null) return;
    if (priority.index < job.priority.index) job.priority = priority;
    job.generation = _generation;
  }

  bool hasBackground(NotePage page) =>
      page.bgAssetId != null ||
      (page.pdfAssetId != null && page.pdfPageIndex != null);

  /// JPEG/PNG bytes of a page for Gemini vision (scans, photos, slides).
  ///
  /// Longest side is capped so a 12-page quiz request stays well under the
  /// HTTP payload limit. Callers own the returned bytes.
  Future<({Uint8List bytes, String mimeType})?> bytesForAiQuiz(
    NotePage page, {
    int maxSide = 768,
  }) async {
    ui.Image? owned;
    try {
      if (page.bgAssetId != null) {
        final raw = await _bytesFor(page.bgAssetId!);
        if (raw == null || raw.isEmpty) return null;
        final asset = await _assets.get(page.bgAssetId!);
        final mime = _guessImageMime(raw, asset?.mime);
        if (raw.lengthInBytes <= 280000) {
          return (bytes: raw, mimeType: mime);
        }
        owned = await _decode(raw, targetWidth: maxSide);
      } else if (page.pdfAssetId != null && page.pdfPageIndex != null) {
        owned = await loadThumbnail(
          page,
          targetWidth: maxSide.toDouble(),
        );
      }
      if (owned == null) return null;
      final png = await owned.toByteData(format: ui.ImageByteFormat.png);
      owned.dispose();
      owned = null;
      if (png == null) return null;
      return (bytes: png.buffer.asUint8List(), mimeType: 'image/png');
    } catch (e) {
      debugPrint('[bg] AI quiz bytes failed for ${page.id}: $e');
      owned?.dispose();
      return null;
    }
  }

  static String _guessImageMime(Uint8List bytes, String? stored) {
    if (stored != null && stored.startsWith('image/')) return stored;
    if (bytes.length >= 3 && bytes[0] == 0xFF && bytes[1] == 0xD8) {
      return 'image/jpeg';
    }
    if (bytes.length >= 8 &&
        bytes[0] == 0x89 &&
        bytes[1] == 0x50 &&
        bytes[2] == 0x4E &&
        bytes[3] == 0x47) {
      return 'image/png';
    }
    if (bytes.length >= 6 && bytes[0] == 0x47 && bytes[1] == 0x49) {
      return 'image/gif';
    }
    if (bytes.length >= 12 &&
        bytes[8] == 0x57 &&
        bytes[9] == 0x45 &&
        bytes[10] == 0x42 &&
        bytes[11] == 0x50) {
      return 'image/webp';
    }
    return 'image/jpeg';
  }

  /// Returns a *clone* of the cached image. Callers own the clone and must
  /// dispose it; that lets the cache dispose its own copy on eviction without
  /// pulling the texture out from under a widget that is still painting it.
  Future<ui.Image?> load(
    NotePage page, {
    PageRenderPriority priority = PageRenderPriority.visible,
    double viewScale = 1.0,
  }) {
    final existing = _cache[page.id];
    if (viewScale < _thumbScaleCutoff) {
      if (existing != null) {
        _touch(_cache, page.id);
        return Future.value(existing.clone());
      }
      return loadThumbnail(page);
    }
    final spec = _fullSpec(priority, viewScale);
    if (existing != null && _covers(existing, spec.maxSide)) {
      _touch(_cache, page.id);
      return Future.value(existing.clone());
    }
    final flightKey = '${page.id}:${spec.variant}';
    final inFlight = _inFlight[flightKey];
    if (inFlight != null) {
      _upgradeInFlight(page, priority, spec.variant);
      return inFlight;
    }
    return _inFlight.putIfAbsent(flightKey, () async {
      ui.Image? image;
      try {
        if (page.bgAssetId != null) {
          final bytes = await _bytesFor(page.bgAssetId!);
          if (bytes != null) image = await _decode(bytes);
        } else if (page.pdfAssetId != null && page.pdfPageIndex != null) {
          image = await _loadPdfPage(
            page,
            priority: priority,
            variant: spec.variant,
            maxRenderSide: spec.maxSide,
          );
        }
      } catch (e) {
        debugPrint('[bg] load failed for page ${page.id}: $e');
      } finally {
        _inFlight.remove(flightKey);
      }
      if (image != null) {
        final prev = _cache[page.id];
        _cache[page.id] = image;
        _touch(_cache, page.id);
        _trim(_cache, _maxCached);
        if (prev != null && !identical(prev, image)) prev.dispose();
        return image.clone();
      }
      return existing?.clone();
    });
  }

  ({String variant, double maxSide}) _fullSpec(
    PageRenderPriority priority,
    double viewScale,
  ) {
    if (priority == PageRenderPriority.visible &&
        viewScale > _hiResScaleCutoff) {
      return (
        variant: 's${_hiResRenderSide.round()}',
        maxSide: _hiResRenderSide,
      );
    }
    return (variant: kPageRenderFull, maxSide: _maxRenderSide);
  }

  bool _covers(ui.Image image, double maxSide) {
    final longest = image.width > image.height ? image.width : image.height;
    return longest >= maxSide * 0.85;
  }

  /// Small preview for the sidebar / library card. [targetWidth] should be the
  /// *physical* pixel width (logical width × devicePixelRatio) so thumbnails
  /// stay crisp on high-DPI screens instead of being upscaled.
  Future<ui.Image?> loadThumbnail(
    NotePage page, {
    double targetWidth = 300,
  }) async {
    final existing = _thumbs[page.id];
    if (existing != null) {
      _touch(_thumbs, page.id);
      return existing.clone();
    }
    ui.Image? image;
    try {
      final full = _cache[page.id];
      if (full != null) {
        image = await _downscale(full, targetWidth);
      } else if (page.bgAssetId != null) {
        final bytes = await _bytesFor(page.bgAssetId!);
        if (bytes != null) {
          image = await _decode(bytes, targetWidth: targetWidth.round());
        }
      } else if (page.pdfAssetId != null && page.pdfPageIndex != null) {
        image = await _loadPdfPage(
          page,
          targetWidth: targetWidth,
          variant: pageRenderThumbKey(targetWidth.round()),
          priority: PageRenderPriority.thumbnail,
        );
      }
    } catch (e) {
      debugPrint('[bg] thumb failed for page ${page.id}: $e');
    }
    if (image != null) {
      _thumbs[page.id] = image;
      _touch(_thumbs, page.id);
      _trim(_thumbs, _maxThumbs);
      return image.clone();
    }
    return null;
  }

  /// Moves [key] to the most-recent end so [_trim] evicts LRU, not insertion
  /// order. Dart's default [Map] is insertion-ordered.
  void _touch(Map<String, ui.Image> cache, String key) {
    final image = cache.remove(key);
    if (image != null) cache[key] = image;
  }

  /// Drops the least-recently used entries once [max] is exceeded, disposing
  /// the cache's handle. Widgets hold clones, so their copies stay valid
  /// until they too are disposed — the texture is freed once every holder
  /// lets go.
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
        Future<PdfDocument?> openFromDisk() async {
          final path = await _assets.localPathOf(assetId);
          if (path == null) return null;
          if (!await assetExists(localPath: path)) return null;
          try {
            return await PdfDocument.openFile(path);
          } catch (e) {
            debugPrint('[bg] openFile failed for $path: $e');
            return null;
          }
        }

        var doc = await openFromDisk();
        if (doc != null) return doc;

        // Metadata can sync before bytes land on disk — fetch from R2 first
        // rather than trying to hold a textbook in memory.
        final downloaded = await _files?.download(assetId) ?? false;
        if (downloaded) {
          doc = await openFromDisk();
          if (doc != null) return doc;
        }

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

  /// Disk image if this page has been drawn before; otherwise PDFium,
  /// then persist so the next open skips the renderer.
  Future<ui.Image?> _loadPdfPage(
    NotePage page, {
    double? targetWidth,
    String variant = kPageRenderFull,
    PageRenderPriority priority = PageRenderPriority.visible,
    double maxRenderSide = _maxRenderSide,
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
    return _enqueuePdfRender(
      assetId: page.pdfAssetId!,
      pageIndex: page.pdfPageIndex!,
      priority: priority,
      targetWidth: targetWidth,
      persistPageId: page.id,
      persistVariant: variant,
      maxRenderSide: maxRenderSide,
    );
  }

  Future<ui.Image?> _renderPdfPageLocked(
    PdfDocument doc,
    _PdfRenderJob job,
  ) async {
    if (job.pageIndex < 0 || job.pageIndex >= doc.pages.length) return null;
    var page = doc.pages[job.pageIndex];
    if (!page.isLoaded) page = await page.ensureLoaded();
    final token = page.createCancellationToken();
    job.cancelToken = token;
    if (token.isCanceled) return null;

    double scale;
    if (job.targetWidth != null) {
      scale = job.targetWidth! / page.width;
    } else {
      // ~2x for crisp text, capped so one page never becomes a huge texture.
      scale = 2.0;
      final longest = page.width > page.height ? page.width : page.height;
      if (longest * scale > job.maxRenderSide) {
        scale = job.maxRenderSide / longest;
      }
    }
    final fullWidth = page.width * scale;
    final fullHeight = page.height * scale;
    final rendered = await page.render(
      fullWidth: fullWidth,
      fullHeight: fullHeight,
      backgroundColor: 0xffffffff,
      cancellationToken: token,
    );
    if (rendered == null || token.isCanceled) {
      rendered?.dispose();
      return null;
    }
    try {
      final pixels = Uint8List.fromList(rendered.pixels);
      final image = await _imageFromBgra(
        rendered.width,
        rendered.height,
        pixels,
      );
      if (job.persistPageId != null) {
        unawaited(_persistRender(image, job.persistPageId!, job.persistVariant));
      }
      return image;
    } finally {
      rendered.dispose();
    }
  }

  Future<ui.Image> _imageFromBgra(int width, int height, Uint8List bgra) {
    final done = Completer<ui.Image>();
    ui.decodeImageFromPixels(
      bgra,
      width,
      height,
      ui.PixelFormat.bgra8888,
      done.complete,
    );
    return done.future;
  }

  /// Disk cache is decoded on the next open. PNG encode happens after the
  /// page is already on screen so it does not delay first paint.
  Future<void> _persistRender(
    ui.Image image,
    String pageId,
    String variant,
  ) async {
    final clone = image.clone();
    try {
      final bytes = await clone.toByteData(format: ui.ImageByteFormat.png);
      if (bytes == null) return;
      await writePageRender(pageId, variant, bytes.buffer.asUint8List());
    } catch (e) {
      debugPrint('[bg] persist failed for $pageId: $e');
    } finally {
      clone.dispose();
    }
  }

  Future<ui.Image> _downscale(ui.Image src, double targetWidth) async {
    final scale = targetWidth / src.width;
    if (scale >= 0.95) return src.clone();
    final w = targetWidth.round().clamp(1, 4096);
    final h = (src.height * scale).round().clamp(1, 4096);
    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder);
    canvas.drawImageRect(
      src,
      ui.Rect.fromLTWH(0, 0, src.width.toDouble(), src.height.toDouble()),
      ui.Rect.fromLTWH(0, 0, w.toDouble(), h.toDouble()),
      ui.Paint()..filterQuality = ui.FilterQuality.medium,
    );
    final picture = recorder.endRecording();
    try {
      return await picture.toImage(w, h);
    } finally {
      picture.dispose();
    }
  }

  /// Renders [pages] in the background without blocking the caller, so the
  /// next pages are ready by the time they scroll into view.
  void prefetch(Iterable<NotePage> pages) => prefetchAll(pages.take(3));

  /// Like [prefetch], but does not cap the set — used to warm nearby pages
  /// after the open-document overlay has already dismissed.
  void prefetchAll(Iterable<NotePage> pages) {
    // Keep this modest: each prefetched page occupies a cache slot, and the
    // cache is deliberately small to protect GPU memory.
    for (final page in pages) {
      if (!hasBackground(page)) continue;
      if (_cache.containsKey(page.id)) continue;
      var loading = false;
      for (final key in _inFlight.keys) {
        if (key.startsWith('${page.id}:')) {
          loading = true;
          break;
        }
      }
      if (loading) continue;
      // Fire and forget; the result is cached, and the returned clone is
      // released immediately since no widget is waiting on it yet.
      unawaited(
        load(page, priority: PageRenderPriority.prefetch).then((img) => img?.dispose()),
      );
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

  /// Drops cached PDF handles and page textures for [assetId] so a later
  /// attach / re-import is not stuck on the first "missing file" failure.
  void forgetAsset(String assetId) {
    final pending = _pdfDocs.remove(assetId);
    if (pending != null) {
      unawaited(
        pending.then((doc) => doc.dispose()).catchError((_) {}),
      );
    }
    _pdfQueues.remove(assetId)?.completeAll();
  }

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
        (await docFuture).dispose();
      } catch (_) {}
    }
    _pdfDocs.clear();
    for (final queue in _pdfQueues.values) {
      queue.completeAll();
    }
    _pdfQueues.clear();
  }
}

/// Visible pages jump the queue; fling prefetch and sidebar thumbs wait.
enum PageRenderPriority { visible, prefetch, thumbnail }

class _PdfRenderJob {
  _PdfRenderJob({
    required this.key,
    required this.assetId,
    required this.pageIndex,
    required this.priority,
    required this.generation,
    required this.targetWidth,
    required this.persistPageId,
    required this.persistVariant,
    required this.maxRenderSide,
  });

  final String key;
  final String assetId;
  final int pageIndex;
  PageRenderPriority priority;
  int generation;
  final double? targetWidth;
  final String? persistPageId;
  final String persistVariant;
  final double maxRenderSide;
  final Completer<ui.Image?> completer = Completer<ui.Image?>();
  PdfPageRenderCancellationToken? cancelToken;
}

class _PdfRenderQueue {
  final List<_PdfRenderJob> _pending = [];
  final List<_PdfRenderJob> _running = [];

  /// Web PDFium/wasm is happier serial; native can overlap two pages.
  static int get _maxActive => kIsWeb ? 1 : 2;

  int get activeCount => _running.length;
  bool get atCapacity => activeCount >= _maxActive;

  _PdfRenderJob? job(String key) {
    for (final item in _pending) {
      if (item.key == key) return item;
    }
    for (final item in _running) {
      if (item.key == key) return item;
    }
    return null;
  }

  void enqueue(_PdfRenderJob job) => _pending.add(job);

  void start(_PdfRenderJob job) => _running.add(job);

  void finish(_PdfRenderJob job) => _running.remove(job);

  void dropStale(int generation) {
    final kept = <_PdfRenderJob>[];
    for (final job in _pending) {
      if (job.priority == PageRenderPriority.visible ||
          job.generation >= generation) {
        kept.add(job);
      } else if (!job.completer.isCompleted) {
        job.completer.complete(null);
      }
    }
    _pending
      ..clear()
      ..addAll(kept);
    for (final job in _running) {
      if (job.priority == PageRenderPriority.visible) continue;
      if (job.generation < generation) job.cancelToken?.cancel();
    }
  }

  void completeAll() {
    for (final job in [..._pending, ..._running]) {
      job.cancelToken?.cancel();
      if (!job.completer.isCompleted) job.completer.complete(null);
    }
    _pending.clear();
    _running.clear();
  }

  _PdfRenderJob? takeNext() {
    if (_pending.isEmpty) return null;
    var best = 0;
    for (var i = 1; i < _pending.length; i++) {
      final a = _pending[i];
      final b = _pending[best];
      if (a.priority.index < b.priority.index ||
          (a.priority == b.priority && a.generation > b.generation)) {
        best = i;
      }
    }
    return _pending.removeAt(best);
  }
}
