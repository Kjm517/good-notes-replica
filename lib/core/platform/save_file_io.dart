import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

Future<String> saveBytes(
    Uint8List bytes, String filename, String mimeType) async {
  final dir = await getApplicationDocumentsDirectory();
  final file = File(p.join(dir.path, filename));
  await file.writeAsBytes(bytes, flush: true);
  return file.path;
}
