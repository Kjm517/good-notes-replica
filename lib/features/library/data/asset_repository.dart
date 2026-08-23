import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:drift/drift.dart';

import '../../../core/db/database.dart';
import '../../../core/storage/asset_store.dart';
import '../../../core/storage/storage_quota.dart';

/// Reads/writes binary assets (image & PDF bytes).
///
/// Bytes live in a file on disk on native platforms and as base64 in the
/// database on web; [AssetStore] hides the difference.
class AssetRepository {
  AssetRepository(this._db, {required this.storageQuotaBytes});

  final AppDatabase _db;

  /// Per-person import cap — 5 GB (free & trial) or 15 GB (paid Premium).
  final int storageQuotaBytes;

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

  /// Sum of distinct asset bytes referenced by [documentId]'s pages.
  Future<int> bytesForDocument(String documentId) async {
    final row = await _documentBytesQuery(documentId).getSingle();
    return row.read<int>('total');
  }

  Selectable<QueryRow> _documentBytesQuery(String documentId) {
    return _db.customSelect(
      '''
      SELECT COALESCE(SUM(a.size_bytes), 0) AS total
      FROM assets AS a
      WHERE a.deleted_at IS NULL
        AND a.size_bytes IS NOT NULL
        AND a.id IN (
          SELECT p.pdf_asset_id FROM note_pages AS p
          WHERE p.document_id = ?1 AND p.deleted_at IS NULL
            AND p.pdf_asset_id IS NOT NULL
          UNION
          SELECT p.bg_asset_id FROM note_pages AS p
          WHERE p.document_id = ?1 AND p.deleted_at IS NULL
            AND p.bg_asset_id IS NOT NULL
        )
      ''',
      variables: [Variable<String>(documentId)],
      readsFrom: {_db.assets, _db.notePages},
    );
  }

  /// Sum of asset bytes for documents in the active library (not trashed,
  /// not permanently deleted). Used by the sidebar meter.
  Future<int> activeLibraryBytes() async {
    final row = await _activeLibraryBytesQuery().getSingle();
    return row.read<int>('total');
  }

  /// All non-tombstoned asset bytes on disk — includes trash until emptied.
  /// Used for the 5 GB import cap.
  Future<int> totalBytes() async {
    final total = _db.assets.sizeBytes.sum();
    final query = _db.selectOnly(_db.assets)
      ..addColumns([total])
      ..where(_db.assets.deletedAt.isNull());
    final row = await query.getSingle();
    return row.read(total) ?? 0;
  }

  /// Throws [StorageQuotaExceeded] if [additionalBytes] would push past the
  /// per-person ceiling.
  Future<void> ensureFits(int additionalBytes) async {
    if (additionalBytes <= 0) return;
    final used = await totalBytes();
    if (used + additionalBytes > storageQuotaBytes) {
      throw StorageQuotaExceeded(
        usedBytes: used,
        neededBytes: additionalBytes,
        quotaBytes: storageQuotaBytes,
      );
    }
  }

  /// Live byte total for the sidebar meter — drops when a file is trashed or
  /// removed, rises again on restore/import.
  Stream<int> watchTotalBytes() {
    return _activeLibraryBytesQuery()
        .watch()
        .map((rows) => rows.first.read<int>('total'));
  }

  Selectable<QueryRow> _activeLibraryBytesQuery() {
    return _db.customSelect(
      '''
      SELECT COALESCE(SUM(a.size_bytes), 0) AS total
      FROM assets AS a
      WHERE a.deleted_at IS NULL
        AND a.size_bytes IS NOT NULL
        AND a.id IN (
          SELECT p.pdf_asset_id FROM note_pages AS p
          INNER JOIN documents AS d ON d.id = p.document_id
          WHERE d.deleted_at IS NULL AND d.trashed_at IS NULL
            AND p.deleted_at IS NULL AND p.pdf_asset_id IS NOT NULL
          UNION
          SELECT p.bg_asset_id FROM note_pages AS p
          INNER JOIN documents AS d ON d.id = p.document_id
          WHERE d.deleted_at IS NULL AND d.trashed_at IS NULL
            AND p.deleted_at IS NULL AND p.bg_asset_id IS NOT NULL
        )
      ''',
      readsFrom: {_db.assets, _db.notePages, _db.documents},
    );
  }

  /// Deletes local files for assets no longer referenced by any document
  /// (including trash). Call after permanent delete or empty trash.
  Future<void> releaseOrphanedAssets() async {
    final rows =
        await (_db.select(_db.assets)..where((a) => a.deletedAt.isNull()))
            .get();
    for (final asset in rows) {
      if (await _isReferencedByRetainedDocument(asset.id)) continue;
      await _purgeAsset(asset);
    }
  }

  Future<bool> _isReferencedByRetainedDocument(String assetId) async {
    final count = _db.notePages.id.count();
    final pages = _db.selectOnly(_db.notePages)
      ..addColumns([count])
      ..join([
        innerJoin(
          _db.documents,
          _db.documents.id.equalsExp(_db.notePages.documentId),
        ),
      ])
      ..where(_db.documents.deletedAt.isNull())
      ..where(_db.notePages.deletedAt.isNull())
      ..where(
        _db.notePages.pdfAssetId.equals(assetId) |
            _db.notePages.bgAssetId.equals(assetId),
      );
    final row = await pages.getSingle();
    return (row.read(count) ?? 0) > 0;
  }

  Future<void> _purgeAsset(Asset asset) async {
    await deleteAsset(asset.localPath);
    final now = DateTime.now();
    await (_db.update(_db.assets)..where((a) => a.id.equals(asset.id))).write(
      AssetsCompanion(
        deletedAt: Value(now),
        updatedAt: Value(now),
        dirty: const Value(true),
        localPath: const Value(null),
        data: const Value(null),
        sizeBytes: const Value(null),
      ),
    );
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

    await ensureFits(bytes.length);
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

    await ensureFits(probe.sizeBytes);
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
    await ensureFits(bytes.length);
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
        // These are different bytes, so the copy in the cloud is stale.
        // Clearing the key is what queues the new file for upload; leaving it
        // set would keep every other device on the old PDF forever.
        remoteKey: const Value(null),
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
    final probe = await probeFile(sourcePath);
    await ensureFits(probe.sizeBytes);
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
        // As above: new bytes, so the cloud copy has to be replaced.
        remoteKey: const Value(null),
        dirty: const Value(true),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }
}
