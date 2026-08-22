import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

Future<void> shareBytes(
  Uint8List bytes,
  String filename,
  String mimeType,
) async {
  await shareMany([(bytes: bytes, filename: filename, mimeType: mimeType)]);
}

Future<void> shareMany(
  List<({Uint8List bytes, String filename, String mimeType})> files,
) async {
  if (files.isEmpty) return;
  final dir = await getTemporaryDirectory();
  final xfiles = <XFile>[];
  for (final file in files) {
    final out = File(p.join(dir.path, file.filename));
    await out.writeAsBytes(file.bytes, flush: true);
    xfiles.add(XFile(out.path, mimeType: file.mimeType, name: file.filename));
  }
  await SharePlus.instance.share(ShareParams(files: xfiles));
}
