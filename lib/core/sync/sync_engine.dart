import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';

import '../db/database.dart';
import '../db/sync_touch.dart';
import '../ink/ink_page_codec.dart';
import '../models/enums.dart';
import '../models/image_element.dart';
import '../models/margin_spec.dart';
import '../network/network_status.dart';
import '../storage/asset_store.dart';
import 'account_prefs.dart';
import 'file_sync.dart';
import 'remote_store.dart';
import 'sync_fields.dart';
import 'sync_state.dart';
import 'user_prefs_repository.dart';

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

  /// Pages whose ink was successfully pushed during the current [syncNow].
  /// The following pull must not re-apply that echo: a corrupt or empty
  /// round-trip through Postgres bytea would delete-and-replace local strokes
  /// and make drawings vanish the moment the green cloud appears.
  final Set<String> _inkPagesPushedThisRun = {};

  /// Why the last file upload failed, if it did. Surfaced in the sync status
  /// so a stuck upload explains itself rather than looking merely slow.
  String? _lastUploadError;

  /// Why the last file download failed (timeout, 404, auth, …).
  String? _lastDownloadError;

  /// Why ink failed to leave this device (oversized without R2, etc.).
  String? _lastInkError;
  bool _paused = false;
  Timer? _debounce;
  StreamSubscription<void>? _watch;
  StreamSubscription<void>? _remoteWatch;
  StreamSubscription<List<ConnectivityResult>>? _net;

  /// True if something external changed while a sync was already running, so
  /// the run that follows doesn't miss it. Local DB writes and Firestore
  /// echoes from *this* push must not set the flag — that is what made sync
  /// restart forever on "Downloading file…".
  bool _missedUpdate = false;

  /// Last progress fraction emitted — reused when tagging a file download.
  double _lastProgress = 0;

  /// Documents whose pages are still being pulled this run, and the one
  /// currently in [_pullPages]. Library cards key off these so a PDF that
  /// already has some local pages stays gray until the rest arrive.
  final Set<String> _pullingDocumentIds = {};
  String? _pullingDocumentId;
  double? _pullingDocumentProgress;

  /// Per-asset backoff after a failed R2 download so we don't hammer the
  /// worker every quiet period.
  final Map<String, DateTime> _downloadBackoffUntil = {};

  /// Consecutive failures per asset, so a file the worker will never serve
  /// backs off towards [_downloadBackoffMax] instead of being retried at a
  /// fixed 45 seconds until the battery runs out.
  final Map<String, int> _downloadAttempts = {};

  /// Consecutive runs that ended with work still outstanding. Each one pushes
  /// the follow-up further out; a clean run resets it.
  int _pendingRuns = 0;

  /// Where [_pullInkChanged] stopped when it hit its per-run ceiling.
  ///
  /// Without this the next run starts from [_lastSyncedAt], which is *later*
  /// than the backlog it never reached — so on a device syncing a large
  /// notebook for the first time, every page of ink past the cap was skipped
  /// permanently.
  DateTime? _inkResumeCursor;

  /// How long to wait after the last change before syncing. Long enough that a
  /// burst of strokes becomes one upload, short enough to feel automatic.
  static const Duration _quietPeriod = Duration(milliseconds: 500);
  static const Duration _downloadBackoff = Duration(seconds: 45);
  static const Duration _downloadBackoffMax = Duration(minutes: 10);

  /// Follow-up delay when a run leaves work behind, doubling per consecutive
  /// pending run up to [_pendingRetryMax].
  static const Duration _pendingRetryBase = Duration(seconds: 10);
  static const Duration _pendingRetryMax = Duration(minutes: 5);

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
          _db.userPrefs,
          _db.quizAttempts,
        ]))
        .listen((_) {
      // Own pull/push writes fire this stream; do not defer another run for
      // them. A real user edit after we finish will schedule normally.
      if (_running) return;
      scheduleSync();
    });
    // Another device's import never touches *this* SQLite, so local table
    // watches alone leave the library empty until resume or a manual tap.
    _remoteWatch ??= _remote.watchChanges().listen((_) {
      // Mid-run snapshots are almost always echoes of *this* device's push.
      // Deferring on them caused an endless sync loop. Real remote changes
      // that land after we go idle still schedule below.
      if (_running) return;
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
    if (!_paused) {
      unawaited(_refreshConnectivity());
      return;
    }
    _paused = false;
    // Clear the paused badge immediately — waiting for the next sync left the
    // cloud menu looking stuck after "Resume" / "Sync now".
    if (!_running) {
      _emit(SyncStatus(
        phase: SyncPhase.idle,
        lastSyncedAt: _lastSyncedAt,
      ));
    }
    unawaited(_refreshConnectivity());
  }

  /// Manual sync from the cloud menu. Unpauses first so "Sync now" still works
  /// after the user has stopped auto-sync.
  Future<void> syncNowFromUser({bool full = true}) async {
    if (_paused) {
      _paused = false;
      if (!_running) {
        _emit(SyncStatus(
          phase: SyncPhase.idle,
          lastSyncedAt: _lastSyncedAt,
        ));
      }
    }
    // "Sync now" means try again now — wipe download backoff so a stuck
    // textbook isn't waiting another ten minutes for the next attempt.
    _downloadBackoffUntil.clear();
    _downloadAttempts.clear();
    _pendingRuns = 0;
    return syncNow(full: full);
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

  /// Re-reads the whole account from the cloud, ignoring the incremental
  /// cursor, then pushes anything local.
  ///
  /// This is what the refresh button runs. Incremental pulls ask only for
  /// records newer than the last run, which is fast but trusts that every
  /// device's clock agrees: `updatedAt` is stamped by whichever device made
  /// the change, so a tablet running a few minutes behind writes records that
  /// look older than this device's cursor and are skipped indefinitely. A
  /// delete is the case where that is most obvious and least acceptable — the
  /// file simply stays. Refresh drops the cursor so the answer is always the
  /// cloud's current truth.
  Future<void> refreshNow() => syncNow(full: true);

  /// Runs a full push + pull. Safe to call repeatedly; overlapping calls are
  /// ignored rather than queued.
  ///
  /// [full] pulls every record rather than only those newer than the last
  /// sync. Slower, so it is reserved for an explicit refresh.
  Future<void> syncNow({bool full = false}) async {
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
    _inkPagesPushedThisRun.clear();
    if (_files != null && !_files.enabled) {
      debugPrint(
        'File sync disabled (empty NOTABLY_FILE_ENDPOINT) — '
        'notes sync, PDFs stay on the importing device.',
      );
    }
    _emitProgress(0.0, 'Syncing…');
    // Stamp the cursor *before* talking to the cloud. Stamping afterwards
    // skips anything that landed during a long pull — the other device's
    // PDF import is the usual casualty.
    final startedAt = DateTime.now();
    try {
      await _push();
      await _pull(full: full);
      _lastSyncedAt = startedAt;
      final pendingUploads = await _pendingFileUploadCount();
      final missingFiles = await _missingAssets();
      final pendingDownloads = missingFiles.length;
      final pendingPages = await _pendingDirtyPageCount();
      final pendingInk = await _pendingDirtyInkPageCount();
      final pendingPrefs = await _pendingDirtyPrefsCount();
      if (pendingUploads > 0) {
        // Notes may be idle while a large PDF is still waiting on R2 — don't
        // claim "fully synced" or the library card stays stuck on Uploading.
        _emit(SyncStatus(
          phase: SyncPhase.pending,
          pendingChanges: pendingUploads,
          lastSyncedAt: _lastSyncedAt,
          // A repeatedly failing upload used to look identical to a slow
          // one: both sat on "still uploading" with the reason only in the
          // debug console. Say what went wrong instead.
          message: _lastUploadError != null
              ? 'Upload failed: $_lastUploadError'
              : pendingUploads == 1
                  ? '1 file still uploading'
                  : '$pendingUploads files still uploading',
        ));
        _scheduleRetry();
      } else if (pendingPages > 0) {
        _emit(SyncStatus(
          phase: SyncPhase.pending,
          pendingChanges: pendingPages,
          lastSyncedAt: _lastSyncedAt,
          message: pendingPages == 1
              ? '1 page still uploading'
              : '$pendingPages pages still uploading',
        ));
        _scheduleRetry();
      } else if (pendingInk > 0) {
        _emit(SyncStatus(
          phase: SyncPhase.pending,
          pendingChanges: pendingInk,
          lastSyncedAt: _lastSyncedAt,
          message: _lastInkError ??
              (pendingInk == 1
                  ? '1 page of drawings still uploading'
                  : '$pendingInk pages of drawings still uploading'),
        ));
        _scheduleRetry();
      } else if (pendingPrefs > 0) {
        _emit(SyncStatus(
          phase: SyncPhase.pending,
          pendingChanges: pendingPrefs,
          lastSyncedAt: _lastSyncedAt,
          message: 'Stickers & pen settings still uploading',
        ));
        _scheduleRetry();
      } else if (pendingDownloads > 0) {
        // Two very different situations used to share one message. A file
        // whose R2 key exists is genuinely mid-download and worth retrying
        // soon; one with no key anywhere is waiting on the device that
        // imported it, and nothing this device does will speed it up. Saying
        // "still downloading" for the second is what made sync look hung.
        final fetchable =
            missingFiles.where((a) => a.hasRemoteCopy).length;
        final waiting = pendingDownloads - fetchable;
        _emit(SyncStatus(
          phase: SyncPhase.pending,
          pendingChanges: pendingDownloads,
          lastSyncedAt: _lastSyncedAt,
          message: _lastDownloadError != null && fetchable > 0
              ? 'Download failed: $_lastDownloadError'
              : fetchable > 0
                  ? (fetchable == 1
                      ? '1 file still downloading'
                      : '$fetchable files still downloading')
                  : (waiting == 1
                      ? '1 file is still uploading from your other device'
                      : '$waiting files are still uploading from your '
                          'other device'),
        ));
        _scheduleRetry();
      } else {
        _pendingRuns = 0;
        _lastDownloadError = null;
        _emit(SyncStatus(
          phase: SyncPhase.idle,
          lastSyncedAt: _lastSyncedAt,
        ));
      }
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
        // Same backoff as a pending run: an error that repeats (a bad
        // endpoint, a revoked token) should not retry every eight seconds
        // for the rest of the session.
        _scheduleRetry();
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

  /// Schedules the follow-up run after a sync that left work behind.
  ///
  /// A fixed ten-second retry is fine while something is actually moving and
  /// pure waste once it is not — a file the other device has not uploaded yet
  /// kept this one waking up six times a minute, forever, to re-count it.
  void _scheduleRetry() {
    _pendingRuns++;
    var delay = _pendingRetryBase * (1 << (_pendingRuns - 1).clamp(0, 5));
    if (delay > _pendingRetryMax) delay = _pendingRetryMax;
    scheduleSync(delay: delay);
  }

  void _emitProgress(
    double progress,
    String message, {
    String? activeAssetId,
  }) {
    _lastProgress = progress.clamp(0.0, 1.0);
    _emit(SyncStatus(
      phase: SyncPhase.syncing,
      progress: _lastProgress,
      progressMessage: message,
      activeAssetId: activeAssetId,
      pullingDocumentIds: Set<String>.from(_pullingDocumentIds),
      pullingDocumentId: _pullingDocumentId,
      pullingDocumentProgress: _pullingDocumentProgress,
    ));
  }

  // ---- Push ----------------------------------------------------------------

  Future<void> _push() async {
    _emitProgress(0.05, 'Claiming documents…');
    await _claimUnownedDocuments();
    _emitProgress(0.15, 'Uploading documents…');
    await _pushDocuments();
    _emitProgress(0.25, 'Uploading pages…');
    await _pushPages();
    _emitProgress(0.35, 'Uploading assets…');
    await _pushAssets();
    _emitProgress(0.45, 'Uploading elements…');
    await _pushElements();
    _emitProgress(0.50, 'Uploading quizzes…');
    await _pushQuizzes();
    _emitProgress(0.53, 'Uploading preferences…');
    await _pushUserPrefs();
    _emitProgress(0.55, 'Uploading ink…');
    await _pushInk();
  }

  /// Quiz history: what was generated, what was answered, and how it scored.
  ///
  /// The questions and answers already travel as JSON on the row, so the whole
  /// attempt replicates as one record — including the highlight each answer
  /// resolved to, which is why a synced quiz opens on the marked page without
  /// re-reading the PDF.
  Future<void> _pushQuizzes() async {
    final rows = await (_db.select(_db.quizAttempts)
          ..where((q) => q.dirty.equals(true)))
        .get();
    if (rows.isEmpty) return;

    await _remote.upsert(
      RemoteCollection.quizzes,
      [
        for (final q in rows)
          RemoteRecord(
            id: q.id,
            updatedAt: q.updatedAt,
            deletedAt: q.deletedAt,
            data: {
              'documentId': q.documentId,
              'familyId': q.familyId,
              'title': q.title,
              'sourceLabel': q.sourceLabel,
              'questionCount': q.questionCount,
              'correctCount': q.correctCount,
              'durationMs': q.durationMs,
              'questionsJson': q.questionsJson,
              'answersJson': q.answersJson,
              'completedAt': q.completedAt.toIso8601String(),
              'completed': q.completed,
            },
          ),
      ],
    );
    await _clearDirty(_db.quizAttempts, rows.map((q) => q.id));
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

  /// Files this device still owes the cloud.
  ///
  /// Notes finish long before a textbook does, so a run that has pushed every
  /// row can still leave the PDF uploading. Reporting that as idle is what
  /// made the library card sit on "Uploading" with nothing apparently
  /// happening.
  ///
  /// The local-bytes clause is what stops the opposite mistake. An asset that
  /// arrived here as metadata only — synced from the device that imported it,
  /// before that device finished uploading — also has no remoteKey, but this
  /// device has nothing to send and never will. Counting those meant a second
  /// device sat on "6 files still uploading" forever, re-running a sync every
  /// 12 seconds for work that was never its to do.
  Future<int> _pendingFileUploadCount() async {
    if (_files == null || !_files.enabled) return 0;
    final count = _db.assets.id.count();
    final query = _db.selectOnly(_db.assets)
      ..addColumns([count])
      ..where(_db.assets.remoteKey.isNull() &
          _db.assets.deletedAt.isNull() &
          (_db.assets.localPath.isNotNull() | _db.assets.data.isNotNull()));
    return (await query.getSingle()).read(count) ?? 0;
  }

  /// Every asset id this account's content refers to: page backgrounds, PDF
  /// sources, canvas images and the sticker library.
  ///
  /// [documentId] narrows it to one notebook, which is what opening a
  /// document needs; omitting it covers the whole library.
  Future<Set<String>> _referencedAssetIds({String? documentId}) async {
    final pages = await (_db.select(_db.notePages)
          ..where((p) => documentId == null
              ? p.deletedAt.isNull()
              : p.documentId.equals(documentId) & p.deletedAt.isNull()))
        .get();
    final assetIds = <String>{
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
          if (assetId.isNotEmpty) assetIds.add(assetId);
        } catch (_) {}
      }
    }
    if (documentId == null) {
      // Sticker library assets (may not be placed on a page yet).
      final prefs = await UserPrefsRepository(_db).load();
      for (final sticker in prefs.stickers) {
        assetIds.add(sticker.assetId);
      }
    }
    return assetIds;
  }

  /// Source PDFs/images referenced by pages **or** canvas stickers/images
  /// that still lack local bytes, and whether the cloud has a copy to fetch.
  Future<List<_MissingAsset>> _missingAssets({String? documentId}) async {
    if (_files == null || !_files.enabled) return const [];
    final missing = <_MissingAsset>[];
    for (final id in await _referencedAssetIds(documentId: documentId)) {
      final asset = await (_db.select(_db.assets)
            ..where((a) => a.id.equals(id) & a.deletedAt.isNull()))
          .getSingleOrNull();
      if (asset == null) {
        // No row at all: the metadata has not reached this device, so there
        // is nothing to fetch from R2 with either.
        missing.add(_MissingAsset(id, hasRemoteCopy: false));
        continue;
      }
      final hasBytes = await assetExists(
        localPath: asset.localPath,
        hasInlineData: asset.data != null && asset.data!.isNotEmpty,
      );
      if (hasBytes) continue;
      final recovered = await findStoredAssetPath(id);
      if (recovered != null) {
        await (_db.update(_db.assets)..where((a) => a.id.equals(id))).write(
          AssetsCompanion(localPath: Value(recovered)),
        );
        continue;
      }
      missing.add(
        _MissingAsset(id, hasRemoteCopy: asset.remoteKey != null),
      );
    }
    return missing;
  }

  /// Actually fetches the files [_missingAssets] just found.
  ///
  /// Counting them without retrying them is what left the cloud menu on
  /// "4 files still downloading" forever: [_ensureAsset] only ran for records
  /// the *incremental* pull happened to return, so once those pages stopped
  /// changing nothing ever asked R2 again — while the count kept rescheduling
  /// a sync every ten seconds to re-count the same four files.
  Future<void> _drainPendingDownloads() async {
    final files = _files;
    if (files == null || !files.enabled) return;
    final missing = await _missingAssets();
    if (missing.isEmpty) return;
    _emitProgress(0.95, 'Downloading files…');
    for (final asset in missing) {
      await _ensureAsset(asset.id);
    }
  }

  Future<int> _pendingDirtyInkPageCount() async {
    final rows = await (_db.select(_db.strokes)
          ..where((s) => s.dirty.equals(true)))
        .get();
    return rows.map((s) => s.pageId).toSet().length;
  }

  Future<int> _pendingDirtyPageCount() async {
    final count = _db.notePages.id.count();
    final query = _db.selectOnly(_db.notePages)
      ..addColumns([count])
      ..where(_db.notePages.dirty.equals(true) &
          _db.notePages.deletedAt.isNull());
    return (await query.getSingle()).read(count) ?? 0;
  }

  Future<int> _pendingDirtyPrefsCount() async {
    final row = await (_db.select(_db.userPrefs)
          ..where((p) =>
              p.id.equals(kUserPrefsRowId) & p.dirty.equals(true)))
        .getSingleOrNull();
    return row == null ? 0 : 1;
  }

  /// Records assets in the cloud and uploads any bytes not there yet.
  Future<void> _pushAssets() async {
    // Bytes first so the metadata upsert includes remoteKey. The previous
    // order wrote remoteKey locally *after* clearing dirty, so Firestore kept
    // a null key and the other device had nothing to download.
    _lastUploadError = await _files?.uploadPending(
      onProgress: (assetId, fraction) {
        // Keep overall sync in the asset band so the indicator doesn't jump
        // from 0%→100% on one file then snap back to "Uploading elements".
        _emitProgress(
          0.35 + 0.09 * fraction.clamp(0.0, 1.0),
          'Uploading file…',
          activeAssetId: assetId,
        );
      },
    );

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
  ///
  /// Blobs under [kInkInlineMaxBytes] go straight into Supabase; larger ones
  /// upload to R2 first, then store only the object key in `ink`.
  Future<void> _pushInk() async {
    final dirtyStrokes =
        await (_db.select(_db.strokes)..where((s) => s.dirty.equals(true)))
            .get();
    if (dirtyStrokes.isEmpty) {
      _lastInkError = null;
      return;
    }

    final pageIds = dirtyStrokes.map((s) => s.pageId).toSet();
    final uploadedIds = <String>{};
    String? lastError;
    for (final pageId in pageIds) {
      final strokes = await (_db.select(_db.strokes)
            ..where((s) => s.pageId.equals(pageId) & s.deletedAt.isNull())
            ..orderBy([(s) => OrderingTerm.asc(s.seq)]))
          .get();
      final blob = encodeInkPage(strokes);
      final stamp = DateTime.now();
      var ok = false;
      if (blob.lengthInBytes > kInkInlineMaxBytes) {
        final files = _files;
        if (files == null || !files.enabled) {
          lastError =
              'Drawing too large to sync without file storage';
          debugPrint(
            'Ink for $pageId is ${blob.lengthInBytes} bytes — '
            'needs R2 (NOTABLY_FILE_ENDPOINT)',
          );
        } else {
          final key = 'ink/$uid/$pageId.bin';
          try {
            await files.putBytes(key, blob, mime: 'application/octet-stream');
            ok = await _remote.putInk(pageId, stamp, remoteKey: key);
          } catch (e) {
            lastError = 'Drawing upload failed: $e';
            debugPrint('R2 ink upload failed for $pageId: $e');
          }
        }
      } else {
        ok = await _remote.putInk(pageId, stamp, bytes: blob);
      }
      if (ok) {
        _inkPagesPushedThisRun.add(pageId);
        uploadedIds.addAll(
          dirtyStrokes.where((s) => s.pageId == pageId).map((s) => s.id),
        );
      }
    }
    _lastInkError = uploadedIds.length == dirtyStrokes.length
        ? null
        : lastError;
    await _clearDirty(_db.strokes, uploadedIds);
  }

  Future<void> _pushUserPrefs() async {
    final row = await (_db.select(_db.userPrefs)
          ..where((p) =>
              p.id.equals(kUserPrefsRowId) & p.dirty.equals(true)))
        .getSingleOrNull();
    if (row == null) return;

    // Decode once so sticker asset ids stay typed for R2 ensure below.
    final prefs = AccountPrefs.fromJson(row.payload);
    await _remote.upsert(
      RemoteCollection.userPrefs,
      [
        RemoteRecord(
          id: uid,
          updatedAt: row.updatedAt,
          deletedAt: row.deletedAt,
          data: prefs.toMap(),
        ),
      ],
    );
    await _clearDirty(_db.userPrefs, [row.id]);
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

  Future<void> _pull({bool full = false}) async {
    // Inclusive overlap: the cursor is a live DateTime while SQLite stores
    // milliseconds, so a strict "after last sync" misses edits from the same
    // tick — drawings and stickers added right after a sync are the usual miss.
    //
    // The window is minutes rather than seconds because `updatedAt` comes from
    // the clock of whichever device made the change. Two phones are routinely
    // tens of seconds apart, and an emulator can be further out still; a
    // two-second overlap silently drops anything written by a device running
    // behind this one. Re-examining a few minutes of records each pull is
    // cheap — they are compared by last-write-wins and mostly discarded — and
    // it is the difference between a delete arriving and never arriving.
    final since = full
        ? null
        : _lastSyncedAt?.subtract(const Duration(minutes: 5));
    // Documents (and their pages) must land before ink/elements — strokes and
    // canvas rows FK to note_pages, and inserting first throws SqliteException
    // 787 and aborts the whole sync.
    _emitProgress(0.60, 'Downloading documents…');
    await _pullDocuments(since);
    _emitProgress(0.75, 'Downloading elements…');
    await _pullElements(since: since);
    _emitProgress(0.82, 'Downloading preferences…');
    await _pullUserPrefs(since);
    _emitProgress(0.85, 'Downloading drawings…');
    await _pullInkChanged(since, full: full);
    _emitProgress(0.92, 'Downloading quizzes…');
    await _pullQuizzes(since);
    // Last, because it is the slowest and depends on everything above having
    // told us which files this device is missing.
    await _drainPendingDownloads();
  }

  Future<void> _pullUserPrefs(DateTime? since) async {
    final records = await _remote.fetchChanged(
      RemoteCollection.userPrefs,
      since: since,
    );
    if (records.isEmpty) return;
    // One row per account; take the newest.
    records.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    final record = records.first;
    final local = await (_db.select(_db.userPrefs)
          ..where((p) => p.id.equals(kUserPrefsRowId)))
        .getSingleOrNull();
    if (local != null &&
        !remoteWins(
          localUpdatedAt: local.updatedAt,
          remoteUpdatedAt: record.updatedAt,
          remoteDeletedAt: record.deletedAt,
        )) {
      return;
    }
    if (record.isDeleted) return;

    final prefs = AccountPrefs.fromMap(
      Map<String, dynamic>.from(record.data),
    );
    await UserPrefsRepository(_db).applyRemote(
      payload: prefs.toJson(),
      updatedAt: record.updatedAt,
    );
    for (final sticker in prefs.stickers) {
      await _ensureAsset(sticker.assetId);
    }
  }

  Future<void> _pullDocuments(DateTime? since) async {
    final remoteDocs =
        await _remote.fetchChanged(RemoteCollection.documents, since: since);

    _pullingDocumentIds
      ..clear()
      ..addAll([
        for (final record in remoteDocs)
          if (!record.isDeleted && _remoteDocumentType(record) != DocumentType.folder)
            record.id,
      ]);
    _pullingDocumentId = null;
    _pullingDocumentProgress = null;
    if (_pullingDocumentIds.isNotEmpty) {
      _emitProgress(_lastProgress, 'Downloading documents…');
    }

    try {
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
    } finally {
      _pullingDocumentIds.clear();
      _pullingDocumentId = null;
      _pullingDocumentProgress = null;
    }
  }

  DocumentType _remoteDocumentType(RemoteRecord record) {
    final index = (record.data['type'] as num?)?.toInt() ?? 1;
    if (index < 0 || index >= DocumentType.values.length) {
      return DocumentType.notebook;
    }
    return DocumentType.values[index];
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
    _pullingDocumentId = documentId;
    _pullingDocumentProgress = null;
    _emitProgress(_lastProgress, 'Syncing pages…');
    try {
      final pages = await _remote.fetchChanged(
        RemoteCollection.pages,
        since: since,
        parentId: documentId,
      );

      final total = pages.length;
      var processed = 0;
      var lastEmitted = 0;
      void emitPageProgress() {
        if (total <= 0) return;
        _pullingDocumentProgress = (processed / total).clamp(0.0, 1.0);
        _emitProgress(_lastProgress, 'Syncing pages…');
      }

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
            final skippedPdf = record.data['pdfAssetId'] as String?;
            final skippedBg = record.data['bgAssetId'] as String?;
            if (skippedPdf != null && ensuredAssets.add(skippedPdf)) {
              await _ensureAsset(skippedPdf);
            }
            if (skippedBg != null && ensuredAssets.add(skippedBg)) {
              await _ensureAsset(skippedBg);
            }
          }
          processed++;
          if (processed == total || processed - lastEmitted >= 25) {
            lastEmitted = processed;
            emitPageProgress();
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
        processed++;
        if (processed == total || processed - lastEmitted >= 25) {
          lastEmitted = processed;
          emitPageProgress();
        }
      }
    } finally {
      _pullingDocumentIds.remove(documentId);
      if (_pullingDocumentId == documentId) {
        _pullingDocumentId = null;
        _pullingDocumentProgress = null;
      }
      // Drop this card's lock immediately rather than waiting for the next
      // phase emit — otherwise a finished PDF stays gray through elements.
      _emitProgress(_lastProgress, 'Downloading documents…');
    }
  }

  /// Brings quiz history down from the cloud.
  ///
  /// An attempt belongs to a document, so one that arrives before its
  /// notebook does is skipped rather than inserted against a missing row —
  /// the next pull, with the document present, takes it.
  Future<void> _pullQuizzes(DateTime? since) async {
    final records =
        await _remote.fetchChanged(RemoteCollection.quizzes, since: since);
    for (final record in records) {
      final documentId = record.data['documentId'] as String?;
      if (documentId == null) continue;

      final local = await (_db.select(_db.quizAttempts)
            ..where((q) => q.id.equals(record.id)))
          .getSingleOrNull();
      if (local != null &&
          !remoteWins(
            localUpdatedAt: local.updatedAt,
            remoteUpdatedAt: record.updatedAt,
            remoteDeletedAt: record.deletedAt,
          )) {
        continue;
      }

      final owner = await (_db.select(_db.documents)
            ..where((d) => d.id.equals(documentId)))
          .getSingleOrNull();
      if (owner == null) continue;

      await _db.into(_db.quizAttempts).insertOnConflictUpdate(
            QuizAttemptsCompanion.insert(
              id: record.id,
              documentId: documentId,
              familyId: record.data['familyId'] as String? ?? '',
              title: record.data['title'] as String? ?? '',
              sourceLabel: Value(record.data['sourceLabel'] as String? ?? ''),
              questionCount:
                  (record.data['questionCount'] as num?)?.toInt() ?? 0,
              correctCount: (record.data['correctCount'] as num?)?.toInt() ?? 0,
              durationMs: Value((record.data['durationMs'] as num?)?.toInt() ?? 0),
              questionsJson: record.data['questionsJson'] as String? ?? '[]',
              answersJson: record.data['answersJson'] as String? ?? '{}',
              completedAt: Value(
                DateTime.tryParse(record.data['completedAt'] as String? ?? '') ??
                    record.updatedAt,
              ),
              completed: Value(record.data['completed'] as bool? ?? true),
              updatedAt: Value(record.updatedAt),
              deletedAt: Value(record.deletedAt),
              dirty: const Value(false),
              remoteUpdatedAt: Value(record.updatedAt),
            ),
          );
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
    var local = await (_db.select(_db.assets)
          ..where((a) => a.id.equals(assetId)))
        .getSingleOrNull();
    if (await _assetBytesOnDevice(local, assetId)) {
      _downloadBackoffUntil.remove(assetId);
      _downloadAttempts.remove(assetId);
      return;
    }

    if (local == null) {
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
      local = await (_db.select(_db.assets)
            ..where((a) => a.id.equals(assetId)))
          .getSingleOrNull();
    } else if (local.remoteKey == null) {
      final record =
          await _remote.fetchById(RemoteCollection.assets, assetId);
      if (record != null && !record.isDeleted) {
        await (_db.update(_db.assets)..where((a) => a.id.equals(assetId)))
            .write(AssetsCompanion(
          mime: Value(record.data['mime'] as String?),
          sha256: Value(record.data['sha256'] as String?),
          sizeBytes: Value((record.data['sizeBytes'] as num?)?.toInt()),
          remoteKey: Value(record.data['remoteKey'] as String?),
          updatedAt: Value(record.updatedAt),
          deletedAt: Value(record.deletedAt),
          dirty: const Value(false),
          remoteUpdatedAt: Value(record.updatedAt),
        ));
        local = await (_db.select(_db.assets)
              ..where((a) => a.id.equals(assetId)))
            .getSingleOrNull();
      }
    }

    // Metadata arrived before the importing device finished uploading to R2.
    // Calling download() here only fails and used to look like endless sync.
    if (local?.remoteKey == null) return;

    final backoffUntil = _downloadBackoffUntil[assetId];
    if (backoffUntil != null && backoffUntil.isAfter(DateTime.now())) {
      return;
    }

    _emitProgress(
      _lastProgress.clamp(0.60, 0.74),
      'Downloading file…',
      activeAssetId: assetId,
    );
    final ok = await _files?.download(
          assetId,
          onProgress: (fraction) {
            _emitProgress(
              0.60 + 0.14 * fraction.clamp(0.0, 1.0),
              'Downloading file…',
              activeAssetId: assetId,
            );
          },
        ) ??
        false;
    if (ok) {
      _downloadBackoffUntil.remove(assetId);
      _downloadAttempts.remove(assetId);
      _lastDownloadError = null;
    } else {
      _lastDownloadError = _files?.lastDownloadError ?? _lastDownloadError;
      final attempts = (_downloadAttempts[assetId] ?? 0) + 1;
      _downloadAttempts[assetId] = attempts;
      var wait = _downloadBackoff * (1 << (attempts - 1).clamp(0, 5));
      if (wait > _downloadBackoffMax) wait = _downloadBackoffMax;
      _downloadBackoffUntil[assetId] = DateTime.now().add(wait);
    }
  }

  /// Called when opening a document so pages whose PDF was synced as metadata
  /// only (or lost locally) try again to fetch the file before the canvas
  /// paints blank sheets.
  Future<void> ensureDocumentAssets(String documentId) async {
    // Opening a doc downloads outside syncNow; don't leave the toolbar stuck
    // on SyncPhase.syncing after a failed or skipped file fetch.
    final leaveBusy = !_running;
    try {
      for (final id in await _referencedAssetIds(documentId: documentId)) {
        await _ensureAsset(id);
      }
    } finally {
      if (leaveBusy && !_running && !_paused) {
        _emit(SyncStatus(
          phase: SyncPhase.idle,
          lastSyncedAt: _lastSyncedAt,
        ));
      }
    }
  }

  /// True when this device already has the notebook's pages and source file.
  ///
  /// Opening must not refetch thousands of page rows (or the PDF) in that
  /// case — drawings, stickers, and the file stay on disk and the editor
  /// should paint immediately. Background sync still brings later edits.
  Future<bool> documentIsCachedLocally(String documentId) async {
    if (await _livePageCount(documentId) <= 0) return false;
    final pages = await (_db.select(_db.notePages)
          ..where((p) =>
              p.documentId.equals(documentId) & p.deletedAt.isNull()))
        .get();
    final sourceIds = <String>{
      for (final p in pages) ...[
        if (p.pdfAssetId != null) p.pdfAssetId!,
        if (p.bgAssetId != null) p.bgAssetId!,
      ],
    };
    for (final id in sourceIds) {
      final local = await (_db.select(_db.assets)
            ..where((a) => a.id.equals(id)))
          .getSingleOrNull();
      if (!await _assetBytesOnDevice(local, id)) return false;
    }
    return true;
  }

  Future<bool> _assetBytesOnDevice(Asset? local, String assetId) async {
    if (local != null &&
        await assetExists(
          localPath: local.localPath,
          hasInlineData: local.data != null && local.data!.isNotEmpty,
        )) {
      return true;
    }
    final recovered = await findStoredAssetPath(assetId);
    if (recovered == null) return false;
    await (_db.update(_db.assets)..where((a) => a.id.equals(assetId))).write(
      AssetsCompanion(localPath: Value(recovered)),
    );
    return true;
  }

  /// Everything this device needs before showing [documentId]: its pages, the
  /// ink on them, and the source file.
  ///
  /// The incremental pull is bounded — a run stops after [_inkRounds] batches,
  /// and pages only arrive for documents the *documents* query returned. Both
  /// are fine for keeping a library warm in the background and both can leave
  /// exactly the notebook the user just tapped a step behind, which is how a
  /// PDF opened on a second device came up with none of its annotations.
  /// Asking for this one document by name closes that gap.
  Future<void> ensureDocumentContent(String documentId) async {
    if (await documentIsCachedLocally(documentId)) {
      return;
    }
    if (_paused || !await _online()) {
      await ensureDocumentAssets(documentId);
      return;
    }
    final leaveBusy = !_running;
    // Announce the fetch even when it turns out there is nothing to do: the
    // editor reloads its in-memory strokes on the syncing→idle edge, so ink
    // pulled here would otherwise sit in SQLite unpainted until the next run.
    if (leaveBusy) _emitProgress(0.5, 'Downloading drawings…');
    try {
      // Ignore the cursor: whatever this device is missing for this notebook
      // is by definition older than the cursor, or it would already be here.
      await _pullPages(documentId, null);
      final pageIds = [
        for (final page in await (_db.select(_db.notePages)
              ..where((p) =>
                  p.documentId.equals(documentId) & p.deletedAt.isNull()))
            .get())
          page.id,
      ];
      if (pageIds.isNotEmpty) {
        for (final ink in await _remote.fetchInkForPages(pageIds)) {
          await _applyRemoteInk(ink);
        }
      }
    } catch (e) {
      // A blank page is better than a crashed open; the background run will
      // try again.
      debugPrint('Could not refresh $documentId before opening: $e');
    } finally {
      if (leaveBusy && !_running && !_paused) {
        _emit(SyncStatus(
          phase: SyncPhase.idle,
          lastSyncedAt: _lastSyncedAt,
        ));
      }
    }
    await ensureDocumentAssets(documentId);
  }

  /// Replaces a page's strokes with the cloud copy. Whole-page granularity is
  /// deliberate: it matches how ink is pushed.
  /// Pulls every page of ink that changed, in pages of [_inkBatch].
  ///
  /// The old shape asked the cloud about each page in turn, so a pull of a
  /// 900-page textbook made 900 sequential round trips to discover that
  /// almost none of them had been drawn on. One query per batch replaces the
  /// lot; a device that has never synced walks through the backlog a batch at
  /// a time across runs rather than stalling on one.
  static const int _inkBatch = 50;
  static const int _inkRounds = 40;

  Future<void> _pullInkChanged(DateTime? since, {bool full = false}) async {
    // A backlog the previous run could not finish resumes where it stopped.
    var cursor = _inkResumeCursor ?? (full ? null : since);
    for (var round = 0; round < _inkRounds; round++) {
      final batch = await _remote.fetchInkChanged(since: cursor, limit: _inkBatch);
      if (batch.isEmpty) {
        _inkResumeCursor = null;
        return;
      }
      for (final ink in batch) {
        await _applyRemoteInk(ink);
      }
      if (batch.length < _inkBatch) {
        _inkResumeCursor = null;
        return;
      }
      // Ties on the same millisecond are re-applied next round; applying ink
      // twice is harmless, skipping a page is not.
      cursor = batch.last.updatedAt;
    }
    // Ceiling reached with more to come. Remember the cursor and make sure a
    // follow-up run happens, or the rest of the backlog is stranded behind a
    // cursor that has already moved past it.
    _inkResumeCursor = cursor;
    _missedUpdate = true;
  }

  /// Applies one page of ink pulled from the cloud.
  Future<void> _applyRemoteInk(RemoteInk ink) async {
    // Same-run echo: we just uploaded this page. Re-applying risks wiping
    // local ink if the download round-trips as empty/corrupt. Only inside a
    // run — the set survives until the next one starts, and an open-document
    // fetch must not inherit it.
    if (_running && _inkPagesPushedThisRun.contains(ink.pageId)) return;
    var bytes = ink.bytes;
    if ((bytes == null || bytes.isEmpty) && ink.usesRemoteFile) {
      bytes = await _files?.getBytes(ink.remoteKey!);
    }
    if (bytes == null || bytes.isEmpty) return;
    await _applyInk(ink.pageId, bytes, remoteUpdatedAt: ink.updatedAt);
  }

  /// Replaces a page's strokes with the cloud's copy, unless this device has
  /// unsent edits of its own — those win until they are pushed.
  ///
  /// Never deletes local live ink in favour of an empty/corrupt remote blob
  /// unless the remote timestamp clearly wins (another device cleared the page).
  Future<void> _applyInk(
    String pageId,
    Uint8List blob, {
    DateTime? remoteUpdatedAt,
  }) async {
    if (blob.isEmpty) return;
    final page = await (_db.select(_db.notePages)
          ..where((p) => p.id.equals(pageId)))
        .getSingleOrNull();
    if (page == null) {
      // Orphan ink (page not pulled yet, or already deleted). Retry next run
      // once the page row exists — never FK-crash the whole sync for it.
      return;
    }
    final dirty = await (_db.select(_db.strokes)
          ..where((s) => s.pageId.equals(pageId) & s.dirty.equals(true))
          ..limit(1))
        .get();
    if (dirty.isNotEmpty) return;

    final localLive = await (_db.select(_db.strokes)
          ..where((s) => s.pageId.equals(pageId) & s.deletedAt.isNull()))
        .get();
    final strokes = decodeInkPage(blob);

    // Never destroy local drawings for an empty download. Corrupt bytea, a
    // failed R2 fetch that still produced a header, or a soft-capped upload
    // that stored nothing all decode to []. A real clear-page leaves no live
    // strokes on this device either (they're tombstoned before push).
    //
    // Re-dirty so the next push re-uploads the real ink and repairs the cloud.
    if (strokes.isEmpty && localLive.isNotEmpty) {
      debugPrint(
        'Skip ink apply for $pageId: empty remote would wipe '
        '${localLive.length} local stroke(s) — re-queuing upload',
      );
      final now = DateTime.now();
      await (_db.update(_db.strokes)
            ..where(
              (s) => s.pageId.equals(pageId) & s.deletedAt.isNull(),
            ))
          .write(StrokesCompanion(
            dirty: const Value(true),
            updatedAt: Value(now),
          ));
      await touchPageForSync(_db, pageId);
      return;
    }

    // Remote has strokes but is older than what we already have — keep local.
    if (strokes.isNotEmpty &&
        localLive.isNotEmpty &&
        remoteUpdatedAt != null) {
      final localUpdated = localLive
          .map((s) => s.updatedAt)
          .reduce((a, b) => a.isAfter(b) ? a : b);
      if (!remoteWins(
        localUpdatedAt: localUpdated,
        remoteUpdatedAt: remoteUpdatedAt,
      )) {
        return;
      }
    }

    try {
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
                  updatedAt: Value(remoteUpdatedAt ?? DateTime.now()),
                ),
                mode: InsertMode.insertOrReplace,
              );
        }
      });
    } catch (e) {
      debugPrint('Skip ink for $pageId: $e');
    }
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

/// An asset whose bytes are not on this device yet.
///
/// [hasRemoteCopy] separates "R2 has it, we are fetching" from "the device
/// that imported it has not uploaded it yet" — the two need different
/// messages and very different retry rates.
class _MissingAsset {
  const _MissingAsset(this.id, {required this.hasRemoteCopy});

  final String id;
  final bool hasRemoteCopy;
}
