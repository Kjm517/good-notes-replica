import 'dart:convert';
import 'dart:typed_data';

import 'package:drift/drift.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../db/database.dart';
import '../storage/asset_store.dart';

/// Uploads source files (PDFs, images) to Cloudflare R2 and fetches them back
/// on other devices.
///
/// Notes and annotations go to Firestore; these binaries do not, because a
/// single textbook can be 150 MB. R2 is 10 GB free with no egress charge, and
/// a small Worker (see `worker/`) guards it — the app never holds R2
/// credentials, it just presents its Firebase ID token.
class FileSync {
  FileSync({
    required AppDatabase db,
    required this.endpoint,
    http.Client? client,
    FirebaseAuth? auth,
  })  : _db = db,
        _client = client ?? http.Client(),
        _auth = auth ?? FirebaseAuth.instance;

  final AppDatabase _db;
  final http.Client _client;
  final FirebaseAuth _auth;

  /// Base URL of the Worker. Empty disables file sync entirely, which is the
  /// default until one is deployed.
  final String endpoint;

  bool get enabled => endpoint.isNotEmpty;

  /// Uploads every asset that has bytes locally but no remote copy yet.
  Future<void> uploadPending({
    void Function(String assetId, double progress)? onProgress,
  }) async {
    if (!enabled) return;
    final pending = await (_db.select(_db.assets)
          ..where((a) => a.remoteKey.isNull() & a.deletedAt.isNull()))
        .get();

    for (final asset in pending) {
      final bytes =
          await readAsset(localPath: asset.localPath, base64: asset.data);
      if (bytes == null) continue;
      try {
        final key = _keyFor(asset);
        await _put(key, bytes, asset.mime ?? 'application/octet-stream');
        await (_db.update(_db.assets)..where((a) => a.id.equals(asset.id)))
            .write(AssetsCompanion(remoteKey: Value(key)));
        onProgress?.call(asset.id, 1);
      } catch (e) {
        debugPrint('Upload failed for ${asset.id}: $e');
        // Leave remoteKey null so the next run retries.
      }
    }
  }

  /// Fetches an asset's bytes from R2 and stores them locally.
  ///
  /// Used when a document is opened on a device that has the notes but not the
  /// file yet. Returns false if the file isn't available.
  Future<bool> download(String assetId) async {
    if (!enabled) return false;
    final asset = await (_db.select(_db.assets)
          ..where((a) => a.id.equals(assetId)))
        .getSingleOrNull();
    if (asset == null) return false;

    // Already here?
    final existing =
        await readAsset(localPath: asset.localPath, base64: asset.data);
    if (existing != null) return true;

    final key = asset.remoteKey;
    if (key == null) return false;

    try {
      final bytes = await _get(key);
      if (bytes == null) return false;
      final stored = await writeAsset(
        asset.id,
        bytes,
        extension: asset.kind == 1 ? 'pdf' : 'img',
      );
      await (_db.update(_db.assets)..where((a) => a.id.equals(asset.id)))
          .write(AssetsCompanion(
        localPath: Value(stored.localPath),
        data: Value(stored.base64),
        sizeBytes: Value(bytes.length),
      ));
      return true;
    } catch (e) {
      debugPrint('Download failed for $assetId: $e');
      return false;
    }
  }

  /// Content-addressed key, so importing the same PDF twice stores one object.
  String _keyFor(Asset asset) {
    final hash = asset.sha256;
    final suffix = asset.kind == 1 ? 'pdf' : 'img';
    return hash == null ? '${asset.id}.$suffix' : 'sha/$hash.$suffix';
  }

  Future<Map<String, String>> _headers() async {
    final token = await _auth.currentUser?.getIdToken();
    if (token == null) throw StateError('Not signed in.');
    return {'Authorization': 'Bearer $token'};
  }

  Future<void> _put(String key, Uint8List bytes, String mime) async {
    final response = await _client.put(
      Uri.parse('$endpoint/file?key=${Uri.encodeQueryComponent(key)}'),
      headers: {...await _headers(), 'Content-Type': mime},
      body: bytes,
    );
    if (response.statusCode >= 300) {
      throw StateError('Upload rejected (${response.statusCode}): '
          '${_briefly(response.body)}');
    }
  }

  Future<Uint8List?> _get(String key) async {
    final response = await _client.get(
      Uri.parse('$endpoint/file?key=${Uri.encodeQueryComponent(key)}'),
      headers: await _headers(),
    );
    if (response.statusCode == 404) return null;
    if (response.statusCode >= 300) {
      throw StateError('Download rejected (${response.statusCode}): '
          '${_briefly(response.body)}');
    }
    return response.bodyBytes;
  }

  String _briefly(String body) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map && decoded['error'] != null) return '${decoded['error']}';
    } catch (_) {}
    return body.length > 120 ? '${body.substring(0, 120)}…' : body;
  }
}
