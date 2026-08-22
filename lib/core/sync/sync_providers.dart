import 'dart:async';

import 'package:drift/drift.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../app/env_config.dart';
import '../../features/auth/providers.dart';
import '../db/database.dart';
import '../network/network_status.dart';
import '../storage/asset_store.dart';
import 'file_sync.dart';
import 'firestore_store.dart';
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
<<<<<<< Updated upstream
/// Resolved in this order, so a deployment does not depend on remembering a
/// build flag:
///   1. `NOTABLY_FILE_ENDPOINT` in `.env` — set this to your own worker
///   2. `--dart-define=NOTABLY_FILE_ENDPOINT=...`
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
=======
/// Set in `.env` as NOTABLY_FILE_ENDPOINT, synced via `scripts/sync-env.sh`.
/// Empty disables file sync; notes still sync via Firestore.
const String kFileEndpoint = EnvConfig.fileEndpoint;
>>>>>>> Stashed changes

/// Uploads/downloads source PDFs and images, or null when signed out.
final fileSyncProvider = Provider<FileSync?>((ref) {
  final user = ref.watch(authStateProvider).asData?.value;
  if (user == null) return null;
  return FileSync(db: ref.watch(databaseProvider), endpoint: kFileEndpoint);
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
  final pagesStream = (db.select(db.notePages)
        ..where((p) => p.deletedAt.isNull()))
      .watch();
  final assetsStream = (db.select(db.assets)
        ..where((a) => a.deletedAt.isNull()))
      .watch();

  return Stream.multi((controller) {
    Future<void> emit() async {
      controller.add(await _missingLocalFileDocuments(db));
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

Future<Map<String, String>> _missingLocalFileDocuments(AppDatabase db) async {
  final pages = await (db.select(db.notePages)
        ..where((p) => p.deletedAt.isNull()))
      .get();
  if (pages.isEmpty) return const <String, String>{};

  final assetIdByDocument = <String, String>{};
  for (final page in pages) {
    final assetId = page.pdfAssetId ?? page.bgAssetId;
    if (assetId != null) {
      assetIdByDocument.putIfAbsent(page.documentId, () => assetId);
    }
  }

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
    if (!hasBytes) missing[entry.key] = entry.value;
  }
  return missing;
}

/// The sync engine, or null when signed out / Firebase unavailable.
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
    remote: FirestoreStore(uid: user.uid),
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
