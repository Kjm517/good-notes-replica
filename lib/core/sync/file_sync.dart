import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../../app/supabase_bootstrap.dart';
import '../db/database.dart';
import '../storage/asset_store.dart';
import 'background_keep_alive.dart';
import 'native_file_transfer.dart';

/// Uploads source files (PDFs, images) to Cloudflare R2 and fetches them back
/// on other devices.
///
/// Notes and annotations go to Supabase Postgres; these binaries do not,
/// because a single textbook can be 150 MB. R2 is 10 GB free with no egress
/// charge, and a small Worker (see `worker/`) guards it — the app never holds
/// R2 credentials, it just presents its Supabase access token.
class FileSync {
  FileSync({
    required AppDatabase db,
    required this.endpoint,
    http.Client? client,
    Future<String?> Function()? idToken,
  }) : _db = db,
       _client = client ?? http.Client(),
       _idToken = idToken;

  final AppDatabase _db;
  final http.Client _client;

  /// Supplies the bearer token. Injected in tests; defaults to Supabase session.
  final Future<String?> Function()? _idToken;

  /// Base URL of the Worker. Empty disables file sync entirely, which is the
  /// default until one is deployed.
  final String endpoint;

  bool get enabled => endpoint.isNotEmpty;

  /// Last download failure reason, for the sync toolbar.
  String? lastDownloadError;

  /// Files at or below this go up as one request; larger ones are split.
  /// R2 requires every part except the last to be the same size, and at least
  /// 5 MB, so the part size doubles as the threshold.
  static const int _partBytes = 8 * 1024 * 1024;

  /// Attempts per part before the upload is abandoned and retried next run.
  static const int _partAttempts = 3;

  /// Cellular / slow Wi‑Fi textbooks can take minutes; the default client
  /// timeout is much shorter and left downloads looking permanently stuck.
  static const Duration _transferTimeout = Duration(minutes: 20);

  /// Uploads every asset that has bytes locally but no remote copy yet.
  ///
  /// Returns the last failure, or null if nothing failed. Swallowing these
  /// entirely is what made a broken upload indistinguishable from a slow one:
  /// the row stays pending either way, so without the reason the UI can only
  /// say "still uploading" forever.
  Future<String?> uploadPending({
    void Function(String assetId, double progress)? onProgress,
  }) async {
    if (!enabled) return null;
    // Rows without local bytes are skipped in SQL rather than mid-loop: they
    // belong to the device that imported the file, and this one has nothing
    // to send for them.
    final pending = await (_db.select(_db.assets)
          ..where((a) =>
              a.remoteKey.isNull() &
              a.deletedAt.isNull() &
              (a.localPath.isNotNull() | a.data.isNotNull())))
        .get();

    String? lastError;
    await BackgroundKeepAlive.acquire();
    try {
    for (final asset in pending) {
      final size = asset.sizeBytes ?? 0;
      final path = asset.localPath;
      final mime = asset.mime ?? 'application/octet-stream';
      final key = _keyFor(asset);
      try {
        if (size > _partBytes && path != null && supportsFileStorage) {
          // Big enough to matter: sent a part at a time, straight off the
          // disk. Nothing larger than one part is ever in memory, so a 150 MB
          // textbook uploads from a phone that could not hold it.
          await _putInParts(key, path, size, mime, (fraction) {
            onProgress?.call(asset.id, fraction);
          });
        } else {
          final bytes = await readAsset(
            localPath: asset.localPath,
            base64: asset.data,
          );
          if (bytes == null) continue;
          await _put(key, bytes, mime);
        }
        await (_db.update(_db.assets)..where((a) => a.id.equals(asset.id)))
            .write(AssetsCompanion(
          remoteKey: Value(key),
          // Metadata was often pushed *before* this write, with remoteKey
          // still null, then marked clean — other devices could never
          // download. Keep the row dirty so the next upsert ships the key.
          dirty: const Value(true),
          updatedAt: Value(DateTime.now()),
        ));
        onProgress?.call(asset.id, 1);
      } catch (e) {
        debugPrint('Upload failed for ${asset.id} to $endpoint: $e');
        lastError = _briefly('$e');
        // Leave remoteKey null so the next run retries.
      }
    }
    return lastError;
    } finally {
      await BackgroundKeepAlive.release();
    }
  }

  /// Fetches an asset's bytes from R2 and stores them locally.
  ///
  /// Used when a document is opened on a device that has the notes but not the
  /// file yet. Returns false if the file isn't available.
  Future<bool> download(
    String assetId, {
    void Function(double fraction)? onProgress,
  }) async {
    if (!enabled) return false;
    final asset = await (_db.select(
      _db.assets,
    )..where((a) => a.id.equals(assetId))).getSingleOrNull();
    if (asset == null) return false;

    // Already here? Stat it — reading a large PDF back just to find out would
    // cost more memory than the process is allowed.
    final present = await assetExists(
      localPath: asset.localPath,
      hasInlineData: asset.data != null,
    );
    if (present) {
      onProgress?.call(1);
      return true;
    }

    final recovered = await findStoredAssetPath(assetId);
    if (recovered != null) {
      await (_db.update(_db.assets)..where((a) => a.id.equals(assetId))).write(
        AssetsCompanion(localPath: Value(recovered)),
      );
      onProgress?.call(1);
      return true;
    }

    final key = asset.remoteKey;
    if (key == null) return false;

    await BackgroundKeepAlive.acquire();
    try {
      final url =
          '$endpoint/file?key=${Uri.encodeQueryComponent(key)}';
      final headers = await _headers();
      if (NativeFileTransfer.isSupported && supportsFileStorage) {
        final dest = await plannedAssetPath(
          asset.id,
          extension: asset.kind == 1 ? 'pdf' : 'img',
        );
        final ok = await NativeFileTransfer.download(
          url: url,
          headers: headers,
          destPath: dest,
          onProgress: onProgress,
        );
        if (ok) {
          await (_db.update(_db.assets)..where((a) => a.id.equals(asset.id)))
              .write(
            AssetsCompanion(
              localPath: Value(dest),
              sizeBytes: Value(asset.sizeBytes),
            ),
          );
          onProgress?.call(1);
          lastDownloadError = null;
          return true;
        }
      }
      // Streamed to disk rather than buffered: the download side had the same
      // ceiling as the upload side, so a textbook that finally uploaded would
      // have killed the process on the way back down.
      final request = http.Request('GET', Uri.parse(url))
        ..headers.addAll(headers);
      final response = await _client.send(request).timeout(_transferTimeout);
      if (response.statusCode == 404) {
        // The key is deliberately left alone. Clearing it here looked like a
        // fix — the row would go back in the upload queue — but this device
        // has no bytes to upload, and publishing the null overwrote the key
        // in Postgres. If the device that *does* have the file had already
        // re-uploaded by then, that erased the good key while its own row
        // stayed clean, so nothing ever published it again. Recovery belongs
        // to [verifyRemoteCopies] on the device holding the bytes; this side
        // just keeps retrying under the caller's backoff.
        lastDownloadError = 'File missing from cloud storage';
        return false;
      }
      if (response.statusCode >= 300) {
        throw StateError('Download rejected (${response.statusCode}).');
      }
      final total = response.contentLength ?? 0;
      var received = 0;
      onProgress?.call(0);
      final progressStream = response.stream.timeout(_transferTimeout).map((chunk) {
        received += chunk.length;
        if (total > 0) {
          onProgress?.call((received / total).clamp(0.0, 1.0));
        }
        return chunk;
      });
      final stored = await writeAssetStream(
        asset.id,
        progressStream,
        extension: asset.kind == 1 ? 'pdf' : 'img',
      ).timeout(_transferTimeout);
      await (_db.update(_db.assets)..where((a) => a.id.equals(asset.id))).write(
        AssetsCompanion(
          localPath: Value(stored.localPath),
          data: Value(stored.base64),
          sizeBytes: Value(response.contentLength ?? asset.sizeBytes),
        ),
      );
      onProgress?.call(1);
      lastDownloadError = null;
      return true;
    } catch (e) {
      // Naming the endpoint here turns "the file just never arrives" into a
      // one-line diagnosis when it is pointed at the wrong worker.
      lastDownloadError = _briefly('$e');
      debugPrint('Download failed for $assetId from $endpoint: $e');
      return false;
    } finally {
      await BackgroundKeepAlive.release();
    }
  }

  /// Uploads arbitrary bytes (e.g. oversized ink) under [key].
  Future<void> putBytes(
    String key,
    Uint8List bytes, {
    String mime = 'application/octet-stream',
  }) async {
    if (!enabled) throw StateError('File sync disabled');
    await _put(key, bytes, mime);
  }

  /// Downloads raw bytes for an R2 [key] (used for oversized ink blobs).
  Future<Uint8List?> getBytes(String key) async {
    if (!enabled) return null;
    try {
      final response = await _client.get(
        Uri.parse('$endpoint/file?key=${Uri.encodeQueryComponent(key)}'),
        headers: await _headers(),
      );
      if (response.statusCode == 404) return null;
      if (response.statusCode >= 300) {
        throw StateError('Download rejected (${response.statusCode}).');
      }
      return response.bodyBytes;
    } catch (e) {
      debugPrint('getBytes failed for $key from $endpoint: $e');
      return null;
    }
  }

  /// Content-addressed key, so importing the same PDF twice stores one object.
  /// Keys this device has already confirmed the bucket holds, so a long
  /// library costs one HEAD per asset per launch rather than per sync.
  final Set<String> _verifiedKeys = {};

  /// Re-checks that the bucket still holds what this device uploaded.
  ///
  /// A device with local bytes never runs [download], so nothing else would
  /// ever tell it that its object went missing — the failure surfaces only on
  /// the *other* device, which is exactly the one that cannot fix it. Assets
  /// with no local bytes are skipped: this device has nothing to re-send for
  /// them, and clearing their key would only hide a key that is still good.
  Future<void> verifyRemoteCopies() async {
    if (!enabled) return;
    final rows = await (_db.select(_db.assets)
          ..where((a) =>
              a.remoteKey.isNotNull() &
              a.deletedAt.isNull() &
              (a.localPath.isNotNull() | a.data.isNotNull())))
        .get();
    for (final asset in rows) {
      final key = asset.remoteKey;
      if (key == null || _verifiedKeys.contains(key)) continue;
      final exists = await _remoteObjectExists(key);
      // Null means the check itself failed (offline, auth, worker down).
      // Treating that as "missing" would clear good keys and re-upload a
      // library over a flaky connection.
      if (exists == null) continue;
      if (exists) {
        _verifiedKeys.add(key);
        // The object is there, so make sure the key that points at it is what
        // Postgres holds. A device that failed to download can have published
        // a null for this asset, and this row — clean, and never re-read
        // because it has its bytes locally — is the only remaining copy of
        // the truth. Re-upserting an already-correct key costs one row.
        if (!asset.dirty) {
          await (_db.update(_db.assets)..where((a) => a.id.equals(asset.id)))
              .write(const AssetsCompanion(dirty: Value(true)));
        }
        continue;
      }
      debugPrint('Remote copy of ${asset.id} is gone ($key) — re-uploading.');
      await _forgetRemoteCopy(asset.id);
    }
  }

  /// True/false if the bucket answered, null if the check could not be made.
  Future<bool?> _remoteObjectExists(String key) async {
    try {
      final response = await _client
          .get(
            Uri.parse('$endpoint/head?key=${Uri.encodeQueryComponent(key)}'),
            headers: await _headers(),
          )
          .timeout(const Duration(seconds: 20));
      if (response.statusCode >= 300) return null;
      final body = jsonDecode(response.body);
      if (body is Map && body['exists'] is bool) return body['exists'] as bool;
      return null;
    } catch (e) {
      debugPrint('Could not verify $key: $e');
      return null;
    }
  }

  /// Drops a `remoteKey` the bucket turned out not to honour.
  ///
  /// [uploadPending] only ever looks at rows with no key, so a key that
  /// outlives its object used to be terminal: the one device still holding the
  /// bytes would never re-send them, and every later open failed the same way
  /// forever. Clearing it (dirty, so the next push writes the null out) puts
  /// the asset back in the upload queue on whichever device still has bytes,
  /// and this one picks the file up on a later pass under the existing
  /// download backoff.
  Future<void> _forgetRemoteCopy(String assetId) async {
    await (_db.update(_db.assets)..where((a) => a.id.equals(assetId))).write(
      AssetsCompanion(
        remoteKey: const Value(null),
        dirty: const Value(true),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  String _keyFor(Asset asset) {
    final hash = asset.sha256;
    final suffix = asset.kind == 1 ? 'pdf' : 'img';
    return hash == null ? '${asset.id}.$suffix' : 'sha/$hash.$suffix';
  }

  Future<Map<String, String>> _headers() async {
    final provider = _idToken;
    final token = provider != null
        ? await provider()
        : await supabaseAccessToken();
    if (token == null || token.isEmpty) throw StateError('Not signed in.');
    return {'Authorization': 'Bearer $token'};
  }

  /// Uploads one file as a series of parts, which R2 stitches back together.
  ///
  /// A Worker request body is capped well below the size of a textbook, and
  /// the phone could not hold one anyway. Each part is read from disk, sent,
  /// and dropped.
  Future<void> _putInParts(
    String key,
    String localPath,
    int size,
    String mime,
    void Function(double fraction) onProgress,
  ) async {
    final uploadId = await _createUpload(key, mime);
    final parts = <Map<String, Object?>>[];
    try {
      var partNumber = 1;
      for (var start = 0; start < size; start += _partBytes) {
        final end = math.min(start + _partBytes, size);
        final chunk = await _slice(localPath, start, end);
        if (chunk.isEmpty) {
          throw StateError('Could not read bytes $start–$end of $localPath.');
        }
        parts.add({
          'partNumber': partNumber,
          'etag': await _uploadPart(key, uploadId, partNumber, chunk),
        });
        onProgress(end / size);
        partNumber++;
      }
      await _completeUpload(key, uploadId, parts);
    } catch (_) {
      // Leave no half-finished upload behind to be billed for.
      await _abortUpload(key, uploadId);
      rethrow;
    }
  }

  Future<Uint8List> _slice(String localPath, int start, int end) async {
    final builder = BytesBuilder(copy: false);
    await for (final chunk in readAssetSlice(localPath, start, end)) {
      builder.add(chunk);
    }
    return builder.takeBytes();
  }

  Future<String> _createUpload(String key, String mime) async {
    final response = await _client.post(
      Uri.parse('$endpoint/multipart/create'
          '?key=${Uri.encodeQueryComponent(key)}'
          '&mime=${Uri.encodeQueryComponent(mime)}'),
      headers: await _headers(),
    );
    if (response.statusCode == 404) {
      throw StateError(
        'The file worker does not support large uploads yet — '
        'redeploy the worker in worker/ to enable them.',
      );
    }
    if (response.statusCode >= 300) {
      throw StateError(
        'Upload could not start (${response.statusCode}): '
        '${_briefly(response.body)}',
      );
    }
    final id = (jsonDecode(response.body) as Map)['uploadId'];
    if (id is! String || id.isEmpty) {
      throw StateError('Upload could not start: no id returned.');
    }
    return id;
  }

  /// One part, retried a couple of times — a dropped connection partway
  /// through a 150 MB upload should cost one part, not the whole file.
  Future<String> _uploadPart(
    String key,
    String uploadId,
    int partNumber,
    Uint8List bytes,
  ) async {
    Object? failure;
    for (var attempt = 1; attempt <= _partAttempts; attempt++) {
      try {
        final response = await _client.put(
          Uri.parse('$endpoint/multipart/part'
              '?key=${Uri.encodeQueryComponent(key)}'
              '&uploadId=${Uri.encodeQueryComponent(uploadId)}'
              '&part=$partNumber'),
          headers: {...await _headers(), 'Content-Type': 'application/octet-stream'},
          body: bytes,
        );
        if (response.statusCode >= 300) {
          throw StateError(
            'Part $partNumber rejected (${response.statusCode}): '
            '${_briefly(response.body)}',
          );
        }
        final etag = (jsonDecode(response.body) as Map)['etag'];
        if (etag is! String || etag.isEmpty) {
          throw StateError('Part $partNumber returned no etag.');
        }
        return etag;
      } catch (e) {
        failure = e;
        if (attempt < _partAttempts) {
          await Future<void>.delayed(Duration(seconds: attempt));
        }
      }
    }
    throw StateError('Part $partNumber failed: $failure');
  }

  Future<void> _completeUpload(
    String key,
    String uploadId,
    List<Map<String, Object?>> parts,
  ) async {
    final response = await _client.post(
      Uri.parse('$endpoint/multipart/complete'
          '?key=${Uri.encodeQueryComponent(key)}'
          '&uploadId=${Uri.encodeQueryComponent(uploadId)}'),
      headers: {...await _headers(), 'Content-Type': 'application/json'},
      body: jsonEncode({'parts': parts}),
    );
    if (response.statusCode >= 300) {
      throw StateError(
        'Upload could not be completed (${response.statusCode}): '
        '${_briefly(response.body)}',
      );
    }
  }

  Future<void> _abortUpload(String key, String uploadId) async {
    try {
      await _client.post(
        Uri.parse('$endpoint/multipart/abort'
            '?key=${Uri.encodeQueryComponent(key)}'
            '&uploadId=${Uri.encodeQueryComponent(uploadId)}'),
        headers: await _headers(),
      );
    } catch (e) {
      debugPrint('Could not abort upload for $key: $e');
    }
  }

  Future<void> _put(String key, Uint8List bytes, String mime) async {
    final response = await _client.put(
      Uri.parse('$endpoint/file?key=${Uri.encodeQueryComponent(key)}'),
      headers: {...await _headers(), 'Content-Type': mime},
      body: bytes,
    );
    if (response.statusCode >= 300) {
      throw StateError(
        'Upload rejected (${response.statusCode}): '
        '${_briefly(response.body)}',
      );
    }
  }

  String _briefly(String body) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map && decoded['error'] != null) {
        return '${decoded['error']}';
      }
    } catch (_) {}
    return body.length > 120 ? '${body.substring(0, 120)}…' : body;
  }
}
