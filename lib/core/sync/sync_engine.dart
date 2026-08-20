import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';

import '../db/database.dart';
import '../ink/ink_page_codec.dart';
import '../models/enums.dart';
import '../models/image_element.dart';
import '../models/margin_spec.dart';
import '../network/network_status.dart';
import '../storage/asset_store.dart';
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
    Future<bool> Function()? isOnline,
  })  : _db = db,
        _remote = remote,
        _files = files,
        _isOnline = isOnline;

  /// Account this engine syncs for. Pulled documents are tagged with it so
  /// they stay hidden from other accounts on the same device.
  final String uid;

  final AppDatabase _db;
  final RemoteStore _remote;

  /// Uploads source PDFs/images to R2. Null or disabled means notes sync but
  /// the big files stay on this device.
  final FileSync? _files;
  final void Function(SyncStatus status)? onStatus;
  final Future<bool> Function()? _isOnline;

  DateTime? _lastSyncedAt;
  bool _running = false;
  bool _paused = false;
  Timer? _debounce;
  StreamSubscription<void>? _watch;
  StreamSubscription<void>? _remoteWatch;
  StreamSubscription<List<ConnectivityResult>>? _net;

  /// True if something changed while a sync was already running, so the run
  /// that follows doesn't miss it.
  bool _missedUpdate = false;

  /// How long to wait after the last change before syncing. Long enough that a
  /// burst of strokes becomes one upload, short enough to feel automatic.
  static const Duration _quietPeriod = Duration(milliseconds: 500);

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
    // Another device's import never touches *this* SQLite, so local table
    // watches alone leave the library empty until resume or a manual tap.
    _remoteWatch ??= _remote.watchChanges().listen((_) {
      if (_running) {
        _missedUpdate = true;
        return;
      }
      scheduleSync(delay: const Duration(milliseconds: 400));
    });
    _net ??= Connectivity().onConnectivityChanged.listen(_onConnectivity);
    unawaited(_refreshConnectivity());
  }

  Future<bool> _online() async {
    final check = _isOnline;
    if (check != null) return check();
    return true;
  }

  SyncStatus get _offlineStatus => SyncStatus(
        phase: SyncPhase.offline,
        message: kNoWifiOrMobileData,
        lastSyncedAt: _lastSyncedAt,
      );

  SyncStatus get _pausedStatus => SyncStatus(
        phase: SyncPhase.paused,
        lastSyncedAt: _lastSyncedAt,
      );

  void _onConnectivity(List<ConnectivityResult> results) {
    unawaited(_applyOnline(hasNetworkInterface(results)));
  }

  Future<void> _refreshConnectivity() async {
    await _applyOnline(await _online());
  }

  Future<void> _applyOnline(bool online) async {
    if (_paused) return;
    if (online) {
      if (_running) {
        _missedUpdate = true;
        return;
      }
      scheduleSync(delay: const Duration(milliseconds: 400));
      return;
    }
    _debounce?.cancel();
    if (!_running) _emit(_offlineStatus);
  }

  /// Stops automatic and manual sync until [resume].
  void pause() {
    _paused = true;
    _debounce?.cancel();
    _emit(_pausedStatus);
  }

  /// Turns auto-sync back on and runs when the network is up.
  void resume() {
    _paused = false;
    unawaited(_refreshConnectivity());
  }

  /// Coalesces bursts of edits into one sync run.
  void scheduleSync({Duration? delay}) {
    if (_paused) return;
    _debounce?.cancel();
    _debounce = Timer(delay ?? _quietPeriod, () => unawaited(syncNow()));
  }

  void dispose() {
    _debounce?.cancel();
    unawaited(_watch?.cancel());
    unawaited(_remoteWatch?.cancel());
    unawaited(_net?.cancel());
  }

  /// Runs a full push + pull. Safe to call repeatedly; overlapping calls are
  /// ignored rather than queued.
  Future<void> syncNow() async {
    if (_running) return;
    if (_paused) {
      _emit(_pausedStatus);
      return;
    }
    if (!await _online()) {
      _emit(_offlineStatus);
      return;
    }
    _running = true;
    _emit(const SyncStatus(phase: SyncPhase.syncing));
    // Stamp the cursor *before* talking to the cloud. Stamping afterwards
    // skips anything that landed during a long pull — the other device's
    // PDF import is the usual casualty.
    final startedAt = DateTime.now();
    try {
      await _push();
      await _pull();
      _lastSyncedAt = startedAt;
      _emit(SyncStatus(
        phase: SyncPhase.idle,
        lastSyncedAt: _lastSyncedAt,
      ));
    } catch (e) {
      debugPrint('Sync failed: $e');
      final online = await _online();
      if (!online || isNetworkError(e)) {
        _emit(_offlineStatus);
      } else {
        _emit(SyncStatus(
          phase: SyncPhase.error,
          message: '$e',
          lastSyncedAt: _lastSyncedAt,
        ));
        scheduleSync(delay: const Duration(seconds: 8));
      }
    } finally {
      _running = false;
      if (_paused) {
        _emit(_pausedStatus);
      } else if (!await _online()) {
        _emit(_offlineStatus);
      } else if (_missedUpdate) {
        _missedUpdate = false;
        scheduleSync();
      }
    }
  }

  void _emit(SyncStatus status) => onStatus?.call(status);

  // ---- Push ----------------------------------------------------------------

  Future<void> _push() async {
    await _claimUnownedDocuments();
    await _pushDocuments();
    await _pushPages();
    // Bytes and asset metadata first so a pulled image/sticker already has a
    // remoteKey by the time its canvas element lands on the other device.
    await _pushAssets();
    await _pushElements();
    await _pushInk();
  }

  /// Notes created before sign-in (or during the auth-restore splash) have a
  /// null [Documents.ownerUid] and would otherwise never leave this device —
  /// [_pushDocuments] only uploads rows owned by [uid].
  Future<void> _claimUnownedDocuments() async {
    await (_db.update(_db.documents)..where((d) => d.ownerUid.isNull())).write(
      DocumentsCompanion(
        ownerUid: Value(uid),
        dirty: const Value(true),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  /// Records assets in the cloud and uploads any bytes not there yet.
  Future<void> _pushAssets() async {
    // Bytes first so the metadata upsert includes remoteKey. The previous
    // order wrote remoteKey locally *after* clearing dirty, so Firestore kept
    // a null key and the other device had nothing to download.
    await _files?.uploadPending();

    final rows =
        await (_db.select(_db.assets)..where((a) => a.dirty.equals(true)))
            .get();
    if (rows.isEmpty) return;
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
    final uploadedIds = <String>{};
    for (final pageId in pageIds) {
      final strokes = await (_db.select(_db.strokes)
            ..where((s) => s.pageId.equals(pageId) & s.deletedAt.isNull())
            ..orderBy([(s) => OrderingTerm.asc(s.seq)]))
          .get();
      final blob = encodeInkPage(strokes);
      final ok = await _remote.putInk(pageId, blob, DateTime.now());
      if (ok) {
        uploadedIds.addAll(
          dirtyStrokes.where((s) => s.pageId == pageId).map((s) => s.id),
        );
      }
    }
    await _clearDirty(_db.strokes, uploadedIds);
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
    // Inclusive overlap: the cursor is a live DateTime while SQLite stores
    // milliseconds, so a strict "after last sync" misses edits from the same
    // tick — drawings and stickers added right after a sync are the usual miss.
    final since = _lastSyncedAt?.subtract(const Duration(seconds: 2));
    await _pullDocuments(since);
    await _pullElements(since: since);
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
        // The notebook row itself lost last-write-wins (title, cover, …) but
        // drawings and stickers live on pages — still walk children.
        final pageCount = await _livePageCount(record.id);
        await _pullPages(
          record.id,
          pageCount == 0 ? null : since,
        );
        continue;
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

      // A document this device has never seen (or one whose pages never
      // arrived) must fetch the full page list. Incremental `since` skips
      // pages older than the last cursor — that's how a PDF card can land
      // with no pages, or never land if we only look at changed documents
      // after a gapped cursor.
      final pageCount = await _livePageCount(record.id);
      await _pullPages(
        record.id,
        local == null || pageCount == 0 ? null : since,
      );
    }
  }

  Future<int> _livePageCount(String documentId) async {
    final count = _db.notePages.id.count();
    final query = _db.selectOnly(_db.notePages)
      ..addColumns([count])
      ..where(_db.notePages.documentId.equals(documentId) &
          _db.notePages.deletedAt.isNull());
    final row = await query.getSingle();
    return row.read(count) ?? 0;
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
        if (!record.isDeleted) {
          await _pullInk(record.id);
          final skippedPdf = record.data['pdfAssetId'] as String?;
          final skippedBg = record.data['bgAssetId'] as String?;
          if (skippedPdf != null && ensuredAssets.add(skippedPdf)) {
            await _ensureAsset(skippedPdf);
          }
          if (skippedBg != null && ensuredAssets.add(skippedBg)) {
            await _ensureAsset(skippedBg);
          }
        }
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

  /// Hydrates canvas objects (images, text, stickers). Pushed for years;
  /// never pulled — so a photo added on the phone never appeared elsewhere.
  Future<void> _pullElements({DateTime? since, String? pageId}) async {
    final records = await _remote.fetchChanged(
      RemoteCollection.elements,
      since: since,
      parentId: pageId,
    );
    for (final record in records) {
      final local = await (_db.select(_db.canvasElements)
            ..where((e) => e.id.equals(record.id)))
          .getSingleOrNull();
      if (local != null &&
          !remoteWins(
            localUpdatedAt: local.updatedAt,
            remoteUpdatedAt: record.updatedAt,
            remoteDeletedAt: record.deletedAt,
          )) {
        if (!record.isDeleted) await _ensureElementAsset(record);
        continue;
      }

      final resolvedPageId =
          record.data['pageId'] as String? ?? pageId ?? local?.pageId;
      if (resolvedPageId == null) continue;

      // Bytes before the row so the first canvas paint is not an empty frame.
      if (!record.isDeleted) await _ensureElementAsset(record);

      try {
        await _db.into(_db.canvasElements).insertOnConflictUpdate(
              CanvasElementsCompanion.insert(
                id: record.id,
                pageId: resolvedPageId,
                type: _enumAt(ElementType.values,
                    (record.data['type'] as num?)?.toInt() ?? 0),
                data: record.data['data'] as String? ?? '{}',
                x: Value((record.data['x'] as num?)?.toDouble() ?? 0),
                y: Value((record.data['y'] as num?)?.toDouble() ?? 0),
                width: Value((record.data['width'] as num?)?.toDouble() ?? 100),
                height: Value((record.data['height'] as num?)?.toDouble() ?? 40),
                scale: Value((record.data['scale'] as num?)?.toDouble() ?? 1),
                rotation:
                    Value((record.data['rotation'] as num?)?.toDouble() ?? 0),
                z: Value((record.data['z'] as num?)?.toInt() ?? 0),
                updatedAt: Value(record.updatedAt),
                deletedAt: Value(record.deletedAt),
                dirty: const Value(false),
                remoteUpdatedAt: Value(record.updatedAt),
              ),
            );
      } catch (e) {
        // Page row may not have landed yet; the next run retries.
        debugPrint('Skip element ${record.id}: $e');
        continue;
      }
    }
  }

  Future<void> _ensureElementAsset(RemoteRecord record) async {
    final typeIndex = (record.data['type'] as num?)?.toInt() ?? 0;
    if (typeIndex != ElementType.image.index) return;
    final raw = record.data['data'] as String?;
    if (raw == null || raw.isEmpty) return;
    try {
      final assetId = ImageElementData.fromJson(raw).assetId;
      if (assetId.isNotEmpty) await _ensureAsset(assetId);
    } catch (_) {}
  }

  /// Hydrates an asset row from the cloud and downloads its bytes when R2 is
  /// configured. Safe to call repeatedly — already-local content is a no-op.
  Future<void> _ensureAsset(String assetId) async {
    final local = await (_db.select(_db.assets)
          ..where((a) => a.id.equals(assetId)))
        .getSingleOrNull();
    final hasBytes = local != null &&
        await assetExists(
          localPath: local.localPath,
          hasInlineData: local.data != null && local.data!.isNotEmpty,
        );
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
    final pageIds = [for (final p in pages) p.id];
    if (pageIds.isNotEmpty) {
      final elements = await (_db.select(_db.canvasElements)
            ..where((e) =>
                e.pageId.isIn(pageIds) &
                e.deletedAt.isNull() &
                e.type.equals(ElementType.image.index)))
          .get();
      for (final element in elements) {
        try {
          final assetId = ImageElementData.fromJson(element.data).assetId;
          if (assetId.isNotEmpty) ids.add(assetId);
        } catch (_) {}
      }
    }
    for (final id in ids) {
      await _ensureAsset(id);
    }
  }

  /// Replaces a page's strokes with the cloud copy. Whole-page granularity is
  /// deliberate: it matches how ink is pushed.
  Future<void> _pullInk(String pageId) async {
    final dirty = await (_db.select(_db.strokes)
          ..where((s) => s.pageId.equals(pageId) & s.dirty.equals(true))
          ..limit(1))
        .get();
    if (dirty.isNotEmpty) return;

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

  T _enumAt<T>(List<T> values, int index) =>
      values[index.clamp(0, values.length - 1)];

  MarginSpec _margins(Object? value) {
    if (value is String && value.isNotEmpty) {
      try {
        return MarginSpec.fromJson(value);
      } catch (_) {}
    }
    return MarginSpec.none;
  }
}
