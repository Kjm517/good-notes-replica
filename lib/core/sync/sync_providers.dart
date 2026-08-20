import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../features/auth/providers.dart';
import '../network/network_status.dart';
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
/// Override at build time if you point at a different worker:
///   `--dart-define=NOTABLY_FILE_ENDPOINT=https://notably-files.YOUR.workers.dev`
///
/// An empty override (`NOTABLY_FILE_ENDPOINT=`) disables file sync; notes
/// still replicate. The default is the deployed Notably worker so `flutter run`
/// without extra flags still moves PDFs between devices on the same account.
const String kFileEndpoint = String.fromEnvironment(
  'NOTABLY_FILE_ENDPOINT',
  defaultValue: 'https://notably-files.notably.workers.dev',
);

/// Uploads/downloads source PDFs and images, or null when signed out.
final fileSyncProvider = Provider<FileSync?>((ref) {
  final user = ref.watch(authStateProvider).asData?.value;
  if (user == null) return null;
  return FileSync(db: ref.watch(databaseProvider), endpoint: kFileEndpoint);
});

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
