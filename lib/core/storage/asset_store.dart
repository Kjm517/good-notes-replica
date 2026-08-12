import 'dart:typed_data';

import 'asset_store_io.dart'
    if (dart.library.js_interop) 'asset_store_web.dart' as impl;

/// Where an asset's bytes ended up.
///
/// On native platforms bytes are written to a file and [localPath] is set. On
/// web there is no filesystem, so [base64] carries the data instead and the
/// row keeps storing it in the database (the pre-existing behaviour).
class StoredAsset {
  const StoredAsset({this.localPath, this.base64});
  final String? localPath;
  final String? base64;
}

/// An asset copied in from a file already on disk.
///
/// Carries the hash and size measured during the copy, so callers never have
/// to read the bytes back just to describe them.
class CopiedAsset {
  const CopiedAsset({
    required this.localPath,
    required this.sha256,
    required this.sizeBytes,
  });

  final String localPath;
  final String sha256;
  final int sizeBytes;
}

/// True when this platform can write asset files to disk.
bool get supportsFileStorage => impl.supportsFileStorage;

/// Persists [bytes] for the asset [id]. [extension] is used for the filename.
Future<StoredAsset> writeAsset(String id, Uint8List bytes,
        {String extension = 'bin'}) =>
    impl.writeAsset(id, bytes, extension: extension);

/// Copies the file at [sourcePath] into asset storage without ever holding it
/// in memory, hashing it chunk by chunk on the way through.
///
/// This is the only safe route for large imports: a 210 MB PDF read into a
/// single allocation exceeds Android's per-app heap limit and kills the
/// process. Only available where [supportsFileStorage] is true.
Future<CopiedAsset> copyAssetFromFile(String id, String sourcePath,
        {String extension = 'bin'}) =>
    impl.copyAssetFromFile(id, sourcePath, extension: extension);

/// Streaming hash + size of a file, without reading it into memory.
Future<CopiedAsset> probeFile(String sourcePath) => impl.probeFile(sourcePath);

/// Reads an asset back, given whichever location it was stored in.
Future<Uint8List?> readAsset({String? localPath, String? base64}) =>
    impl.readAsset(localPath: localPath, base64: base64);

/// Deletes the on-disk file for an asset, if any.
Future<void> deleteAsset(String? localPath) => impl.deleteAsset(localPath);
