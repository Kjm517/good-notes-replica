import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Cap so a 4,000-page textbook cannot fill the phone if the user scrolls it
/// end to end. Oldest files (by mtime) go first; visiting a page again
/// re-renders and rewrites it.
const int _maxFiles = 400;

int _writesSinceTrim = 0;

Future<Directory> _dir() async {
  final base = await getApplicationSupportDirectory();
  final dir = Directory(p.join(base.path, 'page_renders'));
  if (!await dir.exists()) await dir.create(recursive: true);
  return dir;
}

File _file(Directory dir, String pageId, String variant) =>
    File(p.join(dir.path, '$pageId.$variant.jpg'));

Future<Uint8List?> readPageRender(String pageId, String variant) async {
  final file = _file(await _dir(), pageId, variant);
  if (!await file.exists()) return null;
  try {
    return await file.readAsBytes();
  } catch (_) {
    return null;
  }
}

Future<void> writePageRender(
  String pageId,
  String variant,
  Uint8List bytes,
) async {
  try {
    final dir = await _dir();
    await _file(dir, pageId, variant).writeAsBytes(bytes, flush: false);
    _writesSinceTrim++;
    if (_writesSinceTrim >= 8) {
      _writesSinceTrim = 0;
      await _trim(dir);
    }
  } catch (_) {
    // Cache is a speed hint; failing to write must not break the editor.
  }
}

Future<void> deletePageRenders(String pageId) async {
  try {
    final dir = await _dir();
    if (!await dir.exists()) return;
    await for (final entity in dir.list(followLinks: false)) {
      if (entity is! File) continue;
      if (p.basename(entity.path).startsWith('$pageId.')) {
        await entity.delete();
      }
    }
  } catch (_) {}
}

Future<void> _trim(Directory dir) async {
  final files = <File>[];
  await for (final entity in dir.list(followLinks: false)) {
    if (entity is File) files.add(entity);
  }
  final extra = files.length - _maxFiles;
  if (extra <= 0) return;
  final dated = await Future.wait(files.map((file) async {
    final modified = (await file.stat()).modified;
    return (file, modified);
  }));
  dated.sort((a, b) => a.$2.compareTo(b.$2));
  for (final entry in dated.take(extra)) {
    try {
      await entry.$1.delete();
    } catch (_) {}
  }
}
