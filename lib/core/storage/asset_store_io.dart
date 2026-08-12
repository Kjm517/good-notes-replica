import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'asset_store.dart';

const bool supportsFileStorage = true;

Future<Directory> _assetsDir() async {
  final base = await getApplicationSupportDirectory();
  final dir = Directory(p.join(base.path, 'assets'));
  if (!await dir.exists()) await dir.create(recursive: true);
  return dir;
}

Future<StoredAsset> writeAsset(String id, Uint8List bytes,
    {String extension = 'bin'}) async {
  final dir = await _assetsDir();
  final file = File(p.join(dir.path, '$id.$extension'));
  await file.writeAsBytes(bytes, flush: true);
  return StoredAsset(localPath: file.path);
}

/// Hashes [sourcePath] while streaming it, so nothing larger than one chunk is
/// ever resident. Returns the source's own path — nothing has been copied yet.
Future<CopiedAsset> probeFile(String sourcePath) async {
  final file = File(sourcePath);
  final digest = await sha256.bind(file.openRead()).first;
  return CopiedAsset(
    localPath: sourcePath,
    sha256: digest.toString(),
    sizeBytes: await file.length(),
  );
}

Future<CopiedAsset> copyAssetFromFile(String id, String sourcePath,
    {String extension = 'bin'}) async {
  final probe = await probeFile(sourcePath);
  final dir = await _assetsDir();
  final dest = File(p.join(dir.path, '$id.$extension'));
  // File.copy streams through the OS; the bytes never enter our heap.
  await File(sourcePath).copy(dest.path);
  return CopiedAsset(
    localPath: dest.path,
    sha256: probe.sha256,
    sizeBytes: probe.sizeBytes,
  );
}

Future<Uint8List?> readAsset({String? localPath, String? base64}) async {
  if (localPath != null) {
    final file = File(localPath);
    if (await file.exists()) return file.readAsBytes();
  }
  // Fall back to a row that predates file storage.
  if (base64 != null) return base64Decode(base64);
  return null;
}

Future<void> deleteAsset(String? localPath) async {
  if (localPath == null) return;
  final file = File(localPath);
  if (await file.exists()) await file.delete();
}
