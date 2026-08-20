import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:drift/drift.dart';

import '../../../core/db/database.dart';
import '../../../core/storage/asset_store.dart';

/// Reads/writes binary assets (image & PDF bytes).
///
/// Bytes live in a file on disk on native platforms and as base64 in the
/// database on web; [AssetStore] hides the difference.
class AssetRepository {
  AssetRepository(this._db);
  final AppDatabase _db;

  Future<Uint8List?> getBytes(String id) async {
    final row = await (_db.select(
      _db.assets,
    )..where((a) => a.id.equals(id))).getSingleOrNull();
    if (row == null) return null;
    return readAsset(localPath: row.localPath, base64: row.data);
  }

  Future<Asset?> get(String id) =>
      (_db.select(_db.assets)..where((a) => a.id.equals(id))).getSingleOrNull();

  /// Whether [id]'s bytes are on this device, without reading them.
  ///
  /// Answering this with [getBytes] allocates the entire file, which for an
  /// imported textbook is hundreds of megabytes spent to compare against null.
  /// Only the path and the inline flag are selected, so the legacy base64 blob
  /// never leaves SQLite either.
  Future<bool> hasBytes(String id) async {
    final hasInline = _db.assets.data.isNotNull();
    final row =
        await (_db.selectOnly(_db.assets)
              ..addColumns([_db.assets.localPath, hasInline])
              ..where(_db.assets.id.equals(id)))
            .getSingleOrNull();
    if (row == null) return false;
    return assetExists(
      localPath: row.read(_db.assets.localPath),
      hasInlineData: row.read(hasInline) ?? false,
    );
  }

  /// Stored size of [id] in bytes, for deciding whether it can be held in
  /// memory at all. Null when the asset is unknown.
  Future<int?> sizeOf(String id) async {
    final row =
        await (_db.selectOnly(_db.assets)
              ..addColumns([_db.assets.sizeBytes])
              ..where(_db.assets.id.equals(id)))
            .getSingleOrNull();
    return row?.read(_db.assets.sizeBytes);
  }

  /// Live total of stored asset bytes, for the library's storage readout.
  ///
  /// Tombstoned rows are excluded — they're pending deletions on the server,
  /// not space the user is still using.
  Stream<int> watchTotalBytes() {
    final total = _db.assets.sizeBytes.sum();
    final query = _db.selectOnly(_db.assets)
      ..addColumns([total])
      ..where(_db.assets.deletedAt.isNull());
    return query.map((row) => row.read(total) ?? 0).watchSingle();
  }

  /// Path to the asset's file on disk, if it has one (native only).
  ///
  /// Lets consumers stream a large file instead of pulling every byte into
  /// memory — a 150 MB PDF should not become a 150 MB allocation.
  Future<String?> localPathOf(String id) async {
    final row = await (_db.select(
      _db.assets,
    )..where((a) => a.id.equals(id))).getSingleOrNull();
    return row?.localPath;
  }

  /// Stores [bytes] and inserts the asset row. Returns its id.
  ///
  /// [kind]: 0 = image, 1 = pdf. Identical content reuses the existing asset
  /// rather than storing a second copy.
  Future<String> store({
    required String id,
    required Uint8List bytes,
    required int kind,
    required String filename,
    String? mime,
  }) async {
    final digest = sha256.convert(bytes).toString();

    // Dedupe: the same file imported twice keeps one copy.
    final existing =
        await (_db.select(_db.assets)
              ..where((a) => a.sha256.equals(digest) & a.deletedAt.isNull())
              ..limit(1))
            .getSingleOrNull();
    if (existing != null) {
      // A synced row can share this hash without having bytes on *this*
      // device. Reusing it as-is leaves every page that points at it blank.
      if (await _hasBytes(existing)) return existing.id;
      await replaceBytes(
        id: existing.id,
        bytes: bytes,
        kind: kind,
        filename: filename,
        mime: mime,
      );
      return existing.id;
    }

    final stored = await writeAsset(
      id,
      bytes,
      extension: kind == 1 ? 'pdf' : 'img',
    );
    await _db
        .into(_db.assets)
        .insert(
          AssetsCompanion.insert(
            id: id,
            kind: kind,
            path: Value(filename),
            mime: Value(mime),
            data: Value(stored.base64),
            localPath: Value(stored.localPath),
            sha256: Value(digest),
            sizeBytes: Value(bytes.length),
          ),
        );
    return id;
  }

  /// Stores the file at [sourcePath] by streaming it into asset storage, so a
  /// large import never has to fit in memory. Returns the asset id.
  ///
  /// Same dedupe contract as [store]: identical content reuses the existing
  /// asset. If that row has no bytes on this device, the file is copied in.
  Future<String> storeFile({
    required String id,
    required String sourcePath,
    required int kind,
    required String filename,
    String? mime,
  }) async {
    // Hash first so a re-import of the same file costs a read, not a copy.
    final probe = await probeFile(sourcePath);

    final existing =
        await (_db.select(_db.assets)
              ..where(
                (a) => a.sha256.equals(probe.sha256) & a.deletedAt.isNull(),
              )
              ..limit(1))
            .getSingleOrNull();
    if (existing != null) {
      if (await _hasBytes(existing)) return existing.id;
      await replaceFromFile(
        id: existing.id,
        sourcePath: sourcePath,
        kind: kind,
        filename: filename,
        mime: mime,
      );
      return existing.id;
    }

    final copied = await copyAssetFromFile(
      id,
      sourcePath,
      extension: kind == 1 ? 'pdf' : 'img',
    );
    await _db
        .into(_db.assets)
        .insert(
          AssetsCompanion.insert(
            id: id,
            kind: kind,
            path: Value(filename),
            mime: Value(mime),
            localPath: Value(copied.localPath),
            sha256: Value(copied.sha256),
            sizeBytes: Value(copied.sizeBytes),
          ),
        );
    return id;
  }

  /// Legacy rows stored their bytes as base64 in the database. Move them to
  /// files so large PDFs stop bloating (and slowing down) SQLite.
  Future<int> migrateInlineAssetsToDisk() async {
    if (!supportsFileStorage) return 0;
    // Decoding needs the base64 text and the bytes it expands to resident at
    // once, and base64 inflates by 4/3 — so a legacy row holding a textbook
    // cannot be migrated in one piece on a phone. This runs during startup,
    // where that allocation ends the process before the first frame, so
    // oversized rows are filtered out in SQL and left inline.
    const maxEncodedLength = kMaxInMemoryAssetBytes * 4 ~/ 3;
    final rows =
        await (_db.select(_db.assets)..where(
              (a) =>
                  a.localPath.isNull() &
                  a.data.isNotNull() &
                  a.data.length.isSmallerOrEqualValue(maxEncodedLength),
            ))
            .get();
    var moved = 0;
    for (final row in rows) {
      final data = row.data;
      if (data == null) continue;
      final bytes = base64Decode(data);
      final stored = await writeAsset(
        row.id,
        bytes,
        extension: row.kind == 1 ? 'pdf' : 'img',
      );
      await (_db.update(_db.assets)..where((a) => a.id.equals(row.id))).write(
        AssetsCompanion(
          localPath: Value(stored.localPath),
          data: const Value(null), // reclaim the space
          sha256: Value(sha256.convert(bytes).toString()),
          sizeBytes: Value(bytes.length),
        ),
      );
      moved++;
    }
    return moved;
  }

  Future<bool> _hasBytes(Asset row) => assetExists(
        localPath: row.localPath,
        hasInlineData: row.data != null && row.data!.isNotEmpty,
      );

  /// Writes [bytes] onto an existing asset row (the one pages already point
  /// at). Used when this device has the metadata from sync but not the file.
  Future<void> replaceBytes({
    required String id,
    required Uint8List bytes,
    required int kind,
    required String filename,
    String? mime,
  }) async {
    final digest = sha256.convert(bytes).toString();
    final stored = await writeAsset(
      id,
      bytes,
      extension: kind == 1 ? 'pdf' : 'img',
    );
    await (_db.update(_db.assets)..where((a) => a.id.equals(id))).write(
      AssetsCompanion(
        path: Value(filename),
        mime: Value(mime),
        data: Value(stored.base64),
        localPath: Value(stored.localPath),
        sha256: Value(digest),
        sizeBytes: Value(bytes.length),
        dirty: const Value(true),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  /// Same as [replaceBytes] for a file on disk, so a textbook never has to
  /// sit in memory.
  Future<void> replaceFromFile({
    required String id,
    required String sourcePath,
    required int kind,
    required String filename,
    String? mime,
  }) async {
    final copied = await copyAssetFromFile(
      id,
      sourcePath,
      extension: kind == 1 ? 'pdf' : 'img',
    );
    await (_db.update(_db.assets)..where((a) => a.id.equals(id))).write(
      AssetsCompanion(
        path: Value(filename),
        mime: Value(mime),
        localPath: Value(copied.localPath),
        sha256: Value(copied.sha256),
        sizeBytes: Value(copied.sizeBytes),
        dirty: const Value(true),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }
}
