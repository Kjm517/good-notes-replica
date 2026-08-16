import 'dart:async';

import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';

import '../db/database.dart';
import '../ink/ink_page_codec.dart';
import '../models/enums.dart';
import '../models/margin_spec.dart';
import 'file_sync.dart';
import 'remote_store.dart';
import 'sync_fields.dart';
import 'sync_state.dart';

/// Pushes local changes to the cloud and pulls remote ones back.
///
/// The local database stays the source of truth; the cloud is a replica.
/// Records carry `updatedAt` / `deletedAt` / `dirty`, and conflicts resolve
/// last-write-wins (see [remoteWins]).
///
/// Ink is synced **per page** as one packed blob rather than one record per
/// stroke: a page can hold hundreds of strokes and Firestore's free tier
/// allows only 20k writes a day.
class SyncEngine {
  SyncEngine({
    required AppDatabase db,
    required RemoteStore remote,
    required this.uid,
    FileSync? files,
    this.onStatus,
  })  : _db = db,
        _remote = remote,
        _files = files;

  /// Account this engine syncs for. Pulled documents are tagged with it so
  /// they stay hidden from other accounts on the same device.
  final String uid;

  final AppDatabase _db;
  final RemoteStore _remote;

  /// Uploads source PDFs/images to R2. Null or disabled means notes sync but
  /// the big files stay on this device.
  final FileSync? _files;
  final void Function(SyncStatus status)? onStatus;

  DateTime? _lastSyncedAt;
  bool _running = false;
  Timer? _debounce;
  StreamSubscription<void>? _watch;

  /// True if something changed while a sync was already running, so the run
  /// that follows doesn't miss it.
  bool _missedUpdate = false;

  /// How long to wait after the last change before syncing. Long enough that a
  /// burst of strokes becomes one upload, short enough to feel automatic.
  static const Duration _quietPeriod = Duration(milliseconds: 1200);

  /// Watches the database and syncs after any change, so callers never have to
  /// remember to trigger it.
  ///
  /// Sync's own writes (clearing dirty flags, applying pulled records) happen
  /// while [_running] is true and are ignored — otherwise the engine would
  /// retrigger itself forever.
  void startAutoSync() {
    _watch ??= _db
        .tableUpdates(TableUpdateQuery.onAllTables([
          _db.documents,
          _db.notePages,
          _db.strokes,
          _db.canvasElements,
          _db.assets,
        ]))
        .listen((_) {
      if (_running) {
        _missedUpdate = true;
        return;
      }
      scheduleSync();
    });
  }

  /// Coalesces bursts of edits into one sync run.
  void scheduleSync({Duration? delay}) {
    _debounce?.cancel();
    _debounce = Timer(delay ?? _quietPeriod, () => unawaited(syncNow()));
  }

  void dispose() {
    _debounce?.cancel();
    unawaited(_watch?.cancel());
  }

  /// Runs a full push + pull. Safe to call repeatedly; overlapping calls are
  /// ignored rather than queued.
  Future<void> syncNow() async {
    if (_running) return;
    _running = true;
    _emit(const SyncStatus(phase: SyncPhase.syncing));
    try {
      await _push();
      await _pull();
      _lastSyncedAt = DateTime.now();
      _emit(SyncStatus(
        phase: SyncPhase.idle,
        lastSyncedAt: _lastSyncedAt,
      ));
    } catch (e) {
      debugPrint('Sync failed: $e');
      _emit(SyncStatus(
        phase: SyncPhase.error,
        message: '$e',
        lastSyncedAt: _lastSyncedAt,
      ));
    } finally {
      _running = false;
      // Edits made mid-run were skipped above; pick them up now.
      if (_missedUpdate) {
        _missedUpdate = false;
        scheduleSync();
      }
    }
  }

  void _emit(SyncStatus status) => onStatus?.call(status);

  // ---- Push ----------------------------------------------------------------

  Future<void> _push() async {
    await _pushDocuments();
    await _pushPages();
    await _pushElements();
    await _pushInk();
    await _pushAssets();
  }

  /// Records assets in the cloud and uploads any bytes not there yet.
  Future<void> _pushAssets() async {
    final rows =
        await (_db.select(_db.assets)..where((a) => a.dirty.equals(true)))
            .get();
    if (rows.isNotEmpty) {
      await _remote.upsert(
        RemoteCollection.assets,
        [
          for (final a in rows)
            RemoteRecord(
              id: a.id,
              updatedAt: a.updatedAt,
              deletedAt: a.deletedAt,
              data: {
                'kind': a.kind,
                'path': a.path,
                'mime': a.mime,
                'sha256': a.sha256,
                'sizeBytes': a.sizeBytes,
                'remoteKey': a.remoteKey,
              },
            ),
        ],
      );
      await _clearDirty(_db.assets, rows.map((a) => a.id));
    }
    // Upload bytes after the metadata, so a failed upload still leaves a
    // record the next run can retry.
    await _files?.uploadPending();
  }

  Future<void> _pushDocuments() async {
    final rows = await (_db.select(_db.documents)
          ..where((d) => d.dirty.equals(true) & d.ownerUid.equals(uid)))
        .get();
    if (rows.isEmpty) return;

    await _remote.upsert(
      RemoteCollection.documents,
      [
        for (final d in rows)
          RemoteRecord(
            id: d.id,
            updatedAt: d.updatedAt,
            deletedAt: d.deletedAt,
            data: {
              'type': d.type.index,
              'title': d.title,
              'parentId': d.parentId,
              'coverStyle': d.coverStyle,
              'orientation': d.orientation.index,
              'pageSize': d.pageSize.index,
              'starred': d.starred,
              'trashedAt': d.trashedAt?.millisecondsSinceEpoch,
              'sortIndex': d.sortIndex,
              'createdAt': d.createdAt.millisecondsSinceEpoch,
              // Ships with the row so a device that has never seen the source
              // PDF can still draw the card; re-rendering it would mean
              // downloading the whole file first.
              'coverThumb': d.coverThumb,
            },
          ),
      ],
    );
    await _clearDirty(_db.documents, rows.map((d) => d.id));
  }

  Future<void> _pushPages() async {
    final rows =
        await (_db.select(_db.notePages)..where((p) => p.dirty.equals(true)))
            .get();
    if (rows.isEmpty) return;

    // Pages are nested under their document, so group before writing.
    final byDocument = <String, List<NotePage>>{};
    for (final page in rows) {
      byDocument.putIfAbsent(page.documentId, () => []).add(page);
    }

    for (final entry in byDocument.entries) {
      await _remote.upsert(
        RemoteCollection.pages,
        [
          for (final p in entry.value)
            RemoteRecord(
              id: p.id,
              updatedAt: p.updatedAt,
              deletedAt: p.deletedAt,
              data: {
                'documentId': p.documentId,
                'pageIndex': p.pageIndex,
                'template': p.template.index,
                'paperColor': p.paperColor.index,
                'marginSpec': p.marginSpec.toJson(),
                'pdfAssetId': p.pdfAssetId,
                'pdfPageIndex': p.pdfPageIndex,
                'bgAssetId': p.bgAssetId,
                'pageW': p.pageW,
                'pageH': p.pageH,
                'bookmarkTitle': p.bookmarkTitle,
              },
            ),
        ],
        parentId: entry.key,
      );
    }
    await _clearDirty(_db.notePages, rows.map((p) => p.id));
  }

  Future<void> _pushElements() async {
    final rows = await (_db.select(_db.canvasElements)
          ..where((e) => e.dirty.equals(true)))
        .get();
    if (rows.isEmpty) return;

    await _remote.upsert(
      RemoteCollection.elements,
      [
        for (final e in rows)
          RemoteRecord(
            id: e.id,
            updatedAt: e.updatedAt,
            deletedAt: e.deletedAt,
            data: {
              'pageId': e.pageId,
              'type': e.type.index,
              'data': e.data,
              'x': e.x,
              'y': e.y,
              'width': e.width,
              'height': e.height,
              'scale': e.scale,
              'rotation': e.rotation,
              'z': e.z,
            },
          ),
      ],
    );
    await _clearDirty(_db.canvasElements, rows.map((e) => e.id));
  }

  /// Uploads ink for every page that has dirty strokes — one blob per page.
  Future<void> _pushInk() async {
    final dirtyStrokes =
        await (_db.select(_db.strokes)..where((s) => s.dirty.equals(true)))
            .get();
    if (dirtyStrokes.isEmpty) return;

    final pageIds = dirtyStrokes.map((s) => s.pageId).toSet();
    for (final pageId in pageIds) {
      final strokes = await (_db.select(_db.strokes)
            ..where((s) => s.pageId.equals(pageId) & s.deletedAt.isNull())
            ..orderBy([(s) => OrderingTerm.asc(s.seq)]))
          .get();
      final blob = encodeInkPage(strokes);
      await _remote.putInk(pageId, blob, DateTime.now());
    }
    await _clearDirty(_db.strokes, dirtyStrokes.map((s) => s.id));
  }

  Future<void> _clearDirty(TableInfo table, Iterable<String> ids) async {
    if (ids.isEmpty) return;
    // Only clear rows that haven't changed again since we read them.
    final now = DateTime.now();
    await _db.customUpdate(
      'UPDATE ${table.actualTableName} SET dirty = 0, remote_updated_at = ? '
      'WHERE id IN (${List.filled(ids.length, '?').join(',')})',
      variables: [
        Variable.withDateTime(now),
        ...ids.map(Variable.withString),
      ],
      updates: {table},
    );
  }

  // ---- Pull ----------------------------------------------------------------

  Future<void> _pull() async {
    final since = _lastSyncedAt;
    await _pullDocuments(since);
  }

  Future<void> _pullDocuments(DateTime? since) async {
    final remoteDocs =
        await _remote.fetchChanged(RemoteCollection.documents, since: since);

    for (final record in remoteDocs) {
      final local = await (_db.select(_db.documents)
            ..where((d) => d.id.equals(record.id)))
          .getSingleOrNull();

      if (local != null &&
          !remoteWins(
            localUpdatedAt: local.updatedAt,
            remoteUpdatedAt: record.updatedAt,
            remoteDeletedAt: record.deletedAt,
          )) {
        continue; // local copy is newer
      }

      // A thumb absent from the payload leaves the column alone rather than
      // clearing it: an older client that doesn't send one shouldn't wipe the
      // cover this device already rendered.
      final thumb = record.data['coverThumb'] as String?;
      final createdAt = _millis(record.data['createdAt']);

      final companion = DocumentsCompanion.insert(
        id: record.id,
        type: DocumentType.values[(record.data['type'] as num?)?.toInt() ?? 1],
        title: Value(record.data['title'] as String? ?? 'Untitled'),
        parentId: Value(record.data['parentId'] as String?),
        coverStyle: Value((record.data['coverStyle'] as num?)?.toInt() ?? 0),
        orientation: Value(PageOrientation
            .values[(record.data['orientation'] as num?)?.toInt() ?? 0]),
        pageSize: Value(PageSizePreset
            .values[(record.data['pageSize'] as num?)?.toInt() ?? 0]),
        starred: Value(record.data['starred'] as bool? ?? false),
        coverThumb: thumb == null ? const Value.absent() : Value(thumb),
        trashedAt: Value(_millis(record.data['trashedAt'])),
        sortIndex: Value((record.data['sortIndex'] as num?)?.toInt() ?? 0),
        createdAt:
            createdAt == null ? const Value.absent() : Value(createdAt),
        ownerUid: Value(uid),
        updatedAt: Value(record.updatedAt),
        deletedAt: Value(record.deletedAt),
        dirty: const Value(false),
        remoteUpdatedAt: Value(record.updatedAt),
      );
      await _db.into(_db.documents).insertOnConflictUpdate(companion);

      // Pull that document's pages and ink.
      await _pullPages(record.id, since);
    }
  }

  Future<void> _pullPages(String documentId, DateTime? since) async {
    final pages = await _remote.fetchChanged(
      RemoteCollection.pages,
      since: since,
      parentId: documentId,
    );

    final ensuredAssets = <String>{};
    for (final record in pages) {
      final local = await (_db.select(_db.notePages)
            ..where((p) => p.id.equals(record.id)))
          .getSingleOrNull();
      if (local != null &&
          !remoteWins(
            localUpdatedAt: local.updatedAt,
            remoteUpdatedAt: record.updatedAt,
            remoteDeletedAt: record.deletedAt,
          )) {
        continue;
      }

      await _db.into(_db.notePages).insertOnConflictUpdate(
            NotePagesCompanion.insert(
              id: record.id,
              documentId: documentId,
              pageIndex: (record.data['pageIndex'] as num?)?.toInt() ?? 0,
              template: Value(PaperTemplate
                  .values[(record.data['template'] as num?)?.toInt() ?? 0]),
              paperColor: Value(PaperColor
                  .values[(record.data['paperColor'] as num?)?.toInt() ?? 0]),
              marginSpec: Value(_margins(record.data['marginSpec'])),
              pdfAssetId: Value(record.data['pdfAssetId'] as String?),
              pdfPageIndex:
                  Value((record.data['pdfPageIndex'] as num?)?.toInt()),
              bgAssetId: Value(record.data['bgAssetId'] as String?),
              pageW: Value((record.data['pageW'] as num?)?.toDouble()),
              pageH: Value((record.data['pageH'] as num?)?.toDouble()),
              bookmarkTitle: Value(record.data['bookmarkTitle'] as String?),
              updatedAt: Value(record.updatedAt),
              deletedAt: Value(record.deletedAt),
              dirty: const Value(false),
              remoteUpdatedAt: Value(record.updatedAt),
            ),
          );

      if (!record.isDeleted) await _pullInk(record.id);

      // PDF / image pages point at an asset; make sure its metadata (and, when
      // possible, its bytes) land on this device — otherwise the editor paints
      // blank pages and logs "Missing PDF asset".
      final pdfId = record.data['pdfAssetId'] as String?;
      final bgId = record.data['bgAssetId'] as String?;
      if (pdfId != null && ensuredAssets.add(pdfId)) {
        await _ensureAsset(pdfId);
      }
      if (bgId != null && ensuredAssets.add(bgId)) {
        await _ensureAsset(bgId);
      }
    }
  }

  /// Hydrates an asset row from the cloud and downloads its bytes when R2 is
  /// configured. Safe to call repeatedly — already-local content is a no-op.
  Future<void> _ensureAsset(String assetId) async {
    final local = await (_db.select(_db.assets)
          ..where((a) => a.id.equals(assetId)))
        .getSingleOrNull();
    final hasBytes = local != null &&
        (local.localPath != null ||
            (local.data != null && local.data!.isNotEmpty));
    if (hasBytes) return;

    if (local == null || local.remoteKey == null) {
      final record =
          await _remote.fetchById(RemoteCollection.assets, assetId);
      if (record == null || record.isDeleted) return;
      await _db.into(_db.assets).insertOnConflictUpdate(
            AssetsCompanion.insert(
              id: assetId,
              kind: (record.data['kind'] as num?)?.toInt() ?? 1,
              path: Value(record.data['path'] as String? ?? ''),
              mime: Value(record.data['mime'] as String?),
              sha256: Value(record.data['sha256'] as String?),
              sizeBytes: Value((record.data['sizeBytes'] as num?)?.toInt()),
              remoteKey: Value(record.data['remoteKey'] as String?),
              updatedAt: Value(record.updatedAt),
              deletedAt: Value(record.deletedAt),
              dirty: const Value(false),
              remoteUpdatedAt: Value(record.updatedAt),
            ),
          );
    }

    await _files?.download(assetId);
  }

  /// Called when opening a document so pages whose PDF was synced as metadata
  /// only (or lost locally) try again to fetch the file before the canvas
  /// paints blank sheets.
  Future<void> ensureDocumentAssets(String documentId) async {
    final pages = await (_db.select(_db.notePages)
          ..where((p) =>
              p.documentId.equals(documentId) & p.deletedAt.isNull()))
        .get();
    final ids = <String>{
      for (final p in pages) ...[
        if (p.pdfAssetId != null) p.pdfAssetId!,
        if (p.bgAssetId != null) p.bgAssetId!,
      ],
    };
    for (final id in ids) {
      await _ensureAsset(id);
    }
  }

  /// Replaces a page's strokes with the cloud copy. Whole-page granularity is
  /// deliberate: it matches how ink is pushed.
  Future<void> _pullInk(String pageId) async {
    final blob = await _remote.fetchInk(pageId);
    if (blob == null || blob.isEmpty) return;
    final strokes = decodeInkPage(blob);

    await _db.transaction(() async {
      await (_db.delete(_db.strokes)..where((s) => s.pageId.equals(pageId)))
          .go();
      for (final stroke in strokes) {
        final bounds = stroke.bounds;
        await _db.into(_db.strokes).insert(
              StrokesCompanion.insert(
                id: stroke.id,
                pageId: pageId,
                tool: stroke.tool,
                color: stroke.color,
                width: stroke.width,
                opacity: Value(stroke.opacity),
                points: stroke.packPoints(),
                style: Value(stroke.style),
                filled: Value(stroke.filled),
                tip: Value(stroke.tip),
                bboxL: bounds.left,
                bboxT: bounds.top,
                bboxR: bounds.right,
                bboxB: bounds.bottom,
                seq: stroke.seq,
                dirty: const Value(false),
              ),
              mode: InsertMode.insertOrReplace,
            );
      }
    });
  }

  DateTime? _millis(Object? value) => value is num
      ? DateTime.fromMillisecondsSinceEpoch(value.toInt())
      : null;

  MarginSpec _margins(Object? value) {
    if (value is String && value.isNotEmpty) {
      try {
        return MarginSpec.fromJson(value);
      } catch (_) {}
    }
    return MarginSpec.none;
  }
}
