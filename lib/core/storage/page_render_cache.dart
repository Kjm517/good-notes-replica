import 'dart:typed_data';

import 'page_render_cache_io.dart'
    if (dart.library.js_interop) 'page_render_cache_web.dart'
    as impl;

/// Disk cache of already-rendered PDF page images.
///
/// The original PDF stays on disk as the source of truth. The first time a
/// page is drawn we JPEG it here; later opens decode that file instead of
/// running PdfRenderer again. Not synced — these are local speed copies only.
/// Web has no filesystem, so every call is a no-op there.
const String kPageRenderFull = 'full';

String pageRenderThumbKey(int width) => 't$width';

Future<Uint8List?> readPageRender(String pageId, String variant) =>
    impl.readPageRender(pageId, variant);

Future<void> writePageRender(
  String pageId,
  String variant,
  Uint8List bytes,
) =>
    impl.writePageRender(pageId, variant, bytes);

Future<void> deletePageRenders(String pageId) =>
    impl.deletePageRenders(pageId);
