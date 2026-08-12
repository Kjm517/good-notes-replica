import 'dart:typed_data';

import 'save_file_io.dart' if (dart.library.js_interop) 'save_file_web.dart'
    as impl;

/// Saves [bytes] as [filename]. On web this triggers a browser download; on
/// native it writes to the app documents directory. Returns a short
/// human-readable description of where the file went.
Future<String> saveBytes(Uint8List bytes, String filename, String mimeType) =>
    impl.saveBytes(bytes, filename, mimeType);
