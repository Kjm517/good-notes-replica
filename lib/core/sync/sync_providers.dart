import 'dart:async';

import 'package:drift/drift.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../features/auth/providers.dart';
import '../db/database.dart';
import '../network/network_status.dart';
import '../storage/asset_store.dart';
import 'file_sync.dart';
import 'supabase_store.dart';
import 'sync_engine.dart';
import 'sync_state.dart';

/// Live sync status, shown in the toolbar and settings.
final syncStatusProvider =
    NotifierProvider<SyncStatusController, SyncStatus>(
        SyncStatusController.new);

class SyncStatusController extends Notifier<SyncStatus> {
  @override
  SyncStatus build() => const SyncStatus();

  void set(SyncStatus status) => state = status;
}

const kSyncPausedPrefsKey = 'sync_paused';

/// User opted out of account sync from the cloud menu.
final syncPausedProvider =
    NotifierProvider<SyncPausedController, bool>(SyncPausedController.new);

class SyncPausedController extends Notifier<bool> {
  @override
  bool build() {
    return ref.watch(sharedPrefsProvider).getBool(kSyncPausedPrefsKey) ?? false;
  }

  Future<void> setPaused(bool paused) async {
    state = paused;
    await ref.read(sharedPrefsProvider).setBool(kSyncPausedPrefsKey, paused);
    final engine = ref.read(syncEngineProvider);
    if (paused) {
      engine?.pause();
    } else {
      engine?.resume();
    }
  }
}

/// Base URL of the Cloudflare Worker that fronts R2 file storage.
///
/// Resolved in this order, so a deployment does not depend on remembering a
/// build flag:
///   1. `NOTABLY_FILE_ENDPOINT` in `.env` — set this to your own worker
///   2. `--dart-define=NOTABLY_FILE_ENDPOINT=...` / EnvConfig
///   3. the default below
///
/// Every worker lives on its own account subdomain, so the default only works
/// for the account it was deployed from: point this at yours or the app talks
/// to a worker that will refuse it, and files silently never move.
/// Setting it to an empty value disables file sync; notes still replicate.
const String _kDefaultFileEndpoint = 'https://notably-files.notably.workers.dev';

String get kFileEndpoint {
  String? fromEnv;
  try {
    fromEnv = dotenv.env['NOTABLY_FILE_ENDPOINT'];
  } catch (_) {
    // .env not loaded (tests): fall through to the compile-time value.
  }
  if (fromEnv != null) return _trimEndpoint(fromEnv);

  const fromDefine = String.fromEnvironment('NOTABLY_FILE_ENDPOINT');
  if (fromDefine.isNotEmpty) return _trimEndpoint(fromDefine);
  return _kDefaultFileEndpoint;
}

/// Requests are built as `$endpoint/file?...`, so a trailing slash would send
/// them to `//file` and the worker would not match the route.
String _trimEndpoint(String raw) {
  final value = raw.trim();
  return value.endsWith('/') ? value.substring(0, value.length - 1) : value;
}

/// Uploads/downloads source PDFs and images, or null when signed out.
final fileSyncProvider = Provider<FileSync?>((ref) {
  final user = ref.watch(authStateProvider).asData?.value;
  if (user == null) return null;
  final auth = ref.watch(authRepositoryProvider);
  return FileSync(
    db: ref.watch(databaseProvider),
    endpoint: kFileEndpoint,
    idToken: ({bool forceRefresh = false}) async =>
        auth?.idToken(forceRefresh: forceRefresh),
  );
});

/// Documents whose source PDF/image this device still has to upload to R2.
///
/// Map is `documentId → assetId`. Empty when signed out or file sync is off,
/// so local-only libraries never lock cards.
///
/// Only assets with bytes *here* count. One that arrived as metadata from the
/// device that imported it has no remote key either, but this device cannot
/// upload it — badging that card "Waiting to upload" blamed the wrong device
/// and never cleared. Opening it still explains itself properly.
final pendingUploadDocumentsProvider =
    StreamProvider<Map<String, String>>((ref) {
  final user = ref.watch(authStateProvider).asData?.value;
  if (user == null || kFileEndpoint.isEmpty) {
    return Stream.value(const <String, String>{});
  }
  final db = ref.watch(databaseProvider);
  return (db.select(db.assets)
        ..where((a) =>
            a.remoteKey.isNull() &
            a.deletedAt.isNull() &
            (a.localPath.isNotNull() | a.data.isNotNull())))
      .watch()
      .asyncMap((assets) async {
    if (assets.isEmpty) return const <String, String>{};
    final ids = assets.map((a) => a.id).toList();
    final pages = await (db.select(db.notePages)
          ..where(
            (p) =>
                p.deletedAt.isNull() &
                (p.pdfAssetId.isIn(ids) | p.bgAssetId.isIn(ids)),
          ))
        .get();
    final map = <String, String>{};
    for (final page in pages) {
      final assetId = page.pdfAssetId ?? page.bgAssetId;
      if (assetId != null && ids.contains(assetId)) {
        map[page.documentId] = assetId;
      }
    }
    return map;
  });
});

/// Documents whose PDF/image has not arrived on this device yet.
///
/// Includes rows still waiting on metadata during an active sync — the card
/// stays disabled until local bytes exist.
final missingLocalFileDocumentsProvider =
    StreamProvider<Map<String, String>>((ref) {
  final user = ref.watch(authStateProvider).asData?.value;
  if (user == null || kFileEndpoint.isEmpty) {
    return Stream.value(const <String, String>{});
  }
  final db = ref.watch(databaseProvider);

  // Drift invalidates by table, so every committed stroke re-runs these — a
  // stroke touches its page row for sync. Both triggers are reduced to a
  // signature and de-duplicated so the recompute below (which stats a file per
  // document) only runs when the page→asset mapping or an asset really moved.
  final pagesStream = db
      .customSelect(
        'SELECT document_id, COALESCE(pdf_asset_id, bg_asset_id) AS asset_id '
        'FROM note_pages '
        'WHERE deleted_at IS NULL '
        'AND (pdf_asset_id IS NOT NULL OR bg_asset_id IS NOT NULL) '
        'GROUP BY document_id ORDER BY document_id',
        readsFrom: {db.notePages},
      )
      .watch()
      .map((rows) => rows
          .map((r) =>
              '${r.read<String>('document_id')}:${r.read<String>('asset_id')}')
          .join(','))
      .distinct();

  final assetsStream = (db.select(db.assets)
        ..where((a) => a.deletedAt.isNull()))
      .watch()
      .map((assets) => assets
          .map((a) => '${a.id}:${a.remoteKey ?? ''}:${a.localPath ?? ''}:'
              '${a.data?.isNotEmpty ?? false}')
          .join(','))
      .distinct();

  return Stream.multi((controller) {
    var running = false;
    var again = false;

    Future<void> emit() async {
      if (running) {
        again = true;
        return;
      }
      running = true;
      try {
        do {
          again = false;
          final value = await _missingLocalFileDocuments(db);
          if (controller.isClosed) return;
          controller.add(value);
        } while (again);
      } finally {
        running = false;
      }
    }

    unawaited(emit());
    final sub1 = pagesStream.listen((_) => emit());
    final sub2 = assetsStream.listen((_) => emit());
    controller.onCancel = () {
      unawaited(sub1.cancel());
      unawaited(sub2.cancel());
    };
  });
});

/// One `documentId → assetId` pair per document, taken from its lowest-indexed
/// backed page.
///
/// Done in SQL rather than by walking every page row: this runs whenever the
/// pages table changes, and a library holding a few thousand-page PDFs would
/// otherwise decode every row of every document each time. SQLite defines the
/// bare columns of a `min()` aggregate as coming from the matching row.
Future<Map<String, String>> _assetIdByDocument(AppDatabase db) async {
  final rows = await db
      .customSelect(
        'SELECT document_id, '
        'COALESCE(pdf_asset_id, bg_asset_id) AS asset_id, '
        'MIN(page_index) AS page_index '
        'FROM note_pages '
        'WHERE deleted_at IS NULL '
        'AND (pdf_asset_id IS NOT NULL OR bg_asset_id IS NOT NULL) '
        'GROUP BY document_id',
        readsFrom: {db.notePages},
      )
      .get();
  return {
    for (final row in rows)
      row.read<String>('document_id'): row.read<String>('asset_id'),
  };
}

Future<Map<String, String>> _missingLocalFileDocuments(AppDatabase db) async {
  final assetIdByDocument = await _assetIdByDocument(db);
  if (assetIdByDocument.isEmpty) return const <String, String>{};

  final missing = <String, String>{};
  for (final entry in assetIdByDocument.entries) {
    final asset = await (db.select(db.assets)
          ..where((a) => a.id.equals(entry.value)))
        .getSingleOrNull();
    if (asset == null) {
      missing[entry.key] = entry.value;
      continue;
    }
    final hasBytes = await assetExists(
      localPath: asset.localPath,
      hasInlineData: asset.data != null && asset.data!.isNotEmpty,
    );
    if (hasBytes) continue;
    final recovered = await findStoredAssetPath(entry.value);
    if (recovered != null) {
      await (db.update(db.assets)..where((a) => a.id.equals(entry.value)))
          .write(AssetsCompanion(localPath: Value(recovered)));
      continue;
    }
    missing[entry.key] = entry.value;
  }
  return missing;
}

/// The sync engine, or null when signed out / Supabase unavailable.
///
/// Rebuilt whenever the signed-in user changes, so signing out tears the
/// engine down and signing in starts a fresh one for that account.
final syncEngineProvider = Provider<SyncEngine?>((ref) {
  final user = ref.watch(authStateProvider).asData?.value;
  if (user == null) {
    // Deferred: Riverpod forbids touching another provider while this one is
    // still building, and signing out has to clear whatever status the last
    // session left behind.
    var disposed = false;
    ref.onDispose(() => disposed = true);
    Future.microtask(() {
      if (!disposed) {
        ref.read(syncStatusProvider.notifier).set(const SyncStatus());
      }
    });
    return null;
  }

  var disposed = false;
  final engine = SyncEngine(
    db: ref.watch(databaseProvider),
    remote: SupabaseStore(uid: user.uid),
    uid: user.uid,
    files: ref.watch(fileSyncProvider),
    isOnline: isOnlineNow,
    onStatus: (status) {
      Future.microtask(() {
        if (disposed) return;
        ref.read(syncStatusProvider.notifier).set(status);
      });
    },
  );
  ref.onDispose(() {
    disposed = true;
    engine.dispose();
  });

  // Connectivity and pause emit SyncStatus immediately on some devices.
  // Riverpod forbids that while this provider is still building.
  Future.microtask(() {
    if (disposed) return;
    engine.startAutoSync();
    if (ref.read(sharedPrefsProvider).getBool(kSyncPausedPrefsKey) ?? false) {
      engine.pause();
    } else {
      engine.scheduleSync(delay: const Duration(milliseconds: 500));
    }
  });
  return engine;
});
