import 'dart:typed_data';

import 'save_file_web.dart' as save;

Future<void> shareBytes(
  Uint8List bytes,
  String filename,
  String mimeType,
) =>
    save.saveBytes(bytes, filename, mimeType).then((_) {});

Future<void> shareMany(
  List<({Uint8List bytes, String filename, String mimeType})> files,
) async {
  for (final file in files) {
    await save.saveBytes(file.bytes, file.filename, file.mimeType);
  }
}
