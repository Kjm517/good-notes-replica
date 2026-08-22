import 'dart:typed_data';

import 'share_bytes_io.dart' if (dart.library.js_interop) 'share_bytes_web.dart'
    as impl;

/// Opens the platform share sheet for a single file ([bytes] as [filename]).
Future<void> shareBytes(
  Uint8List bytes,
  String filename,
  String mimeType,
) =>
    impl.shareBytes(bytes, filename, mimeType);

/// Shares multiple files in one sheet (mobile) or saves sequentially (web).
Future<void> shareMany(
  List<({Uint8List bytes, String filename, String mimeType})> files,
) =>
    impl.shareMany(files);
