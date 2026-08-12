import 'dart:typed_data';

import 'save_file.dart';

/// Saves [bytes] as a PNG named [filename].
Future<String> savePng(Uint8List bytes, String filename) =>
    saveBytes(bytes, filename, 'image/png');
