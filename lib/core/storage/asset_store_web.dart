import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:web/web.dart' as web;

import 'asset_store.dart';

/// Browser asset storage, backed by the Origin Private File System.
///
/// The database used to hold every asset as base64 in a TEXT column. For a
/// 100 MB PDF that measured, in Chrome, ~2.8 s to build the binary string and
/// ~0.4 s to encode — all on the thread the UI runs on — producing 140 MB of
/// text to write into SQLite. The write failed, the download restarted, and a
/// synced textbook cycled between "Downloading 74%" and "63%" forever while
/// taps went missing.
///
/// OPFS is a real filesystem for the origin: bytes stream in a chunk at a
/// time, nothing is encoded, and [readAssetSlice] can serve byte ranges, which
/// is what lets uploads go multipart here as they do on native.
///
/// One thing it does not buy: pdfrx's web backend has no `openCustom`, so a
/// PDF is still opened from a full in-memory list. Storage is no longer the
/// ceiling; the renderer is.
const bool supportsFileStorage = true;

/// Everything lives in one flat directory so [findStoredAssetPath] can recover
/// a row whose `localPath` was lost without walking a tree.
const String _dirName = 'notably_assets';

/// `localPath` on web is this file's name inside [_dirName] — there are no
/// real paths in a browser, and storing a fake absolute one would leak into
/// sync and mean nothing on the next device.
String _fileName(String id, String extension) => '$id.$extension';

Future<web.FileSystemDirectoryHandle> _dir() async {
  final root = await web.window.navigator.storage.getDirectory().toDart;
  return root
      .getDirectoryHandle(
        _dirName,
        web.FileSystemGetDirectoryOptions(create: true),
      )
      .toDart;
}

Future<web.FileSystemFileHandle?> _handle(
  String name, {
  bool create = false,
}) async {
  try {
    final dir = await _dir();
    return await dir
        .getFileHandle(name, web.FileSystemGetFileOptions(create: create))
        .toDart;
  } catch (_) {
    // NotFoundError when create is false, or the whole API being unavailable.
    return null;
  }
}

Future<web.File?> _file(String name) async {
  final handle = await _handle(name);
  if (handle == null) return null;
  try {
    return await handle.getFile().toDart;
  } catch (_) {
    return null;
  }
}

Future<StoredAsset> writeAsset(
  String id,
  Uint8List bytes, {
  String extension = 'bin',
}) async {
  final name = _fileName(id, extension);
  final handle = await _handle(name, create: true);
  if (handle == null) {
    // No OPFS (very old browser, or storage denied). The database fallback is
    // worse in every way but still better than losing the import.
    return StoredAsset(base64: base64Encode(bytes));
  }
  final writable = await handle.createWritable().toDart;
  try {
    await writable.write(bytes.toJS).toDart;
  } finally {
    await writable.close().toDart;
  }
  return StoredAsset(localPath: name);
}

/// Streams [bytes] to a file without ever holding the whole asset.
///
/// This is the path a synced textbook takes. Buffering it — which is what the
/// old inline implementation did — is the bug this file exists to remove, so
/// chunks are written straight through.
Future<StoredAsset> writeAssetStream(
  String id,
  Stream<List<int>> bytes, {
  String extension = 'bin',
}) async {
  final name = _fileName(id, extension);
  final handle = await _handle(name, create: true);
  if (handle == null) {
    final builder = BytesBuilder(copy: false);
    await for (final chunk in bytes) {
      builder.add(chunk);
    }
    return writeAsset(id, builder.takeBytes(), extension: extension);
  }
  final writable = await handle.createWritable().toDart;
  try {
    await for (final chunk in bytes) {
      final data = chunk is Uint8List ? chunk : Uint8List.fromList(chunk);
      await writable.write(data.toJS).toDart;
    }
  } catch (e) {
    // A half-written file would look present to [assetExists] and then fail
    // to parse, which is indistinguishable from a corrupt download.
    await writable.close().toDart;
    await deleteAsset(name);
    rethrow;
  }
  await writable.close().toDart;
  return StoredAsset(localPath: name);
}

Future<int?> assetFileSize(String localPath) async {
  final file = await _file(localPath);
  return file?.size;
}

/// Byte range from the stored file — the reason uploads can go multipart here.
Stream<List<int>> readAssetSlice(String localPath, int start, int end) async* {
  final file = await _file(localPath);
  if (file == null) return;
  final blob = file.slice(start, end);
  final buffer = await blob.arrayBuffer().toDart;
  yield buffer.toDart.asUint8List();
}

Future<CopiedAsset> copyAssetFromFile(
  String id,
  String sourcePath, {
  String extension = 'bin',
}) => throw UnsupportedError('No source file paths in a browser');

Future<CopiedAsset> probeFile(String sourcePath) =>
    throw UnsupportedError('No source file paths in a browser');

/// The name a future [writeAsset] will use. Nothing is created here.
Future<String> plannedAssetPath(String id, {String extension = 'bin'}) async =>
    _fileName(id, extension);

Future<bool> assetExists({
  String? localPath,
  bool hasInlineData = false,
}) async {
  if (localPath != null && localPath.isNotEmpty) {
    final file = await _file(localPath);
    // A zero-length file is an interrupted write, not an asset.
    if (file != null && file.size > 0) return true;
  }
  return hasInlineData;
}

Future<Uint8List?> readAsset({String? localPath, String? base64}) async {
  if (localPath != null && localPath.isNotEmpty) {
    final file = await _file(localPath);
    if (file != null) {
      final buffer = await file.arrayBuffer().toDart;
      return buffer.toDart.asUint8List();
    }
  }
  // Rows written before OPFS, and the no-OPFS fallback above.
  return base64 == null ? null : base64Decode(base64);
}

Future<void> deleteAsset(String? localPath) async {
  if (localPath == null || localPath.isEmpty) return;
  try {
    final dir = await _dir();
    await dir.removeEntry(localPath).toDart;
  } catch (e) {
    debugPrint('OPFS delete failed for $localPath: $e');
  }
}

/// Finds a stored file for [id] when the row lost its `localPath`.
///
/// The extension is part of the name and the row no longer knows it, so the
/// handful the app actually writes are probed. Iterating the directory would
/// be exact, but OPFS exposes that as an async iterator that is far more
/// awkward through js_interop than nine cheap lookups.
Future<String?> findStoredAssetPath(String id) async {
  const extensions = [
    'pdf', 'img', 'bin', 'png', 'jpg', 'jpeg', 'webp', 'gif', 'heic',
  ];
  for (final extension in extensions) {
    final name = _fileName(id, extension);
    final file = await _file(name);
    if (file != null && file.size > 0) return name;
  }
  return null;
}
