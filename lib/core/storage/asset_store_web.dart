import 'dart:convert';
import 'dart:typed_data';

import 'asset_store.dart';

/// Browsers have no filesystem available to us here, so bytes stay in the
/// database as base64 (see the Assets table doc comment).
const bool supportsFileStorage = false;

Future<StoredAsset> writeAsset(
  String id,
  Uint8List bytes, {
  String extension = 'bin',
}) async => StoredAsset(base64: base64Encode(bytes));

/// Unreachable on web: there is no file path to copy from, so imports there
/// go through the in-memory route instead.
/// No filesystem on web, so the stream is collected and stored inline. Large
/// files are skipped before reaching here.
Future<StoredAsset> writeAssetStream(
  String id,
  Stream<List<int>> bytes, {
  String extension = 'bin',
}) async {
  final builder = BytesBuilder(copy: false);
  await for (final chunk in bytes) {
    builder.add(chunk);
  }
  return writeAsset(id, builder.takeBytes(), extension: extension);
}

/// No filesystem on web, so nothing to measure.
Future<int?> assetFileSize(String localPath) async => null;

/// Web assets live in the database, not on disk, so there is no file to slice.
Stream<List<int>> readAssetSlice(String localPath, int start, int end) =>
    const Stream<List<int>>.empty();

Future<CopiedAsset> copyAssetFromFile(
  String id,
  String sourcePath, {
  String extension = 'bin',
}) => throw UnsupportedError('Asset files are not available on web');

Future<CopiedAsset> probeFile(String sourcePath) =>
    throw UnsupportedError('Asset files are not available on web');

Future<bool> assetExists({
  String? localPath,
  bool hasInlineData = false,
}) async => hasInlineData;

Future<Uint8List?> readAsset({String? localPath, String? base64}) async =>
    base64 == null ? null : base64Decode(base64);

Future<void> deleteAsset(String? localPath) async {}
