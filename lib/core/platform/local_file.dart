import 'dart:typed_data';

import 'local_file_io.dart' if (dart.library.js_interop) 'local_file_web.dart'
    as impl;

/// Reads all bytes from a path on disk (native only).
Future<Uint8List> readLocalFile(String path) => impl.readLocalFile(path);
