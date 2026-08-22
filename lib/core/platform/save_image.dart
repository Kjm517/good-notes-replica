import 'dart:typed_data';

import 'package:flutter/foundation.dart';

import 'save_file.dart';
import 'share_bytes.dart';

bool get _shareOnMobile =>
    !kIsWeb &&
    (defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.android);

/// Saves or shares a PNG. On mobile, opens the share sheet; elsewhere writes
/// to the app documents directory and returns the path.
Future<String> savePng(Uint8List bytes, String filename) async {
  if (_shareOnMobile) {
    await shareBytes(bytes, filename, 'image/png');
    return filename;
  }
  return saveBytes(bytes, filename, 'image/png');
}
