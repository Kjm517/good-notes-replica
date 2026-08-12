import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../features/auth/providers.dart';
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

/// Base URL of the Cloudflare Worker that fronts R2 file storage.
///
/// Supplied at build time so no endpoint is baked into the repository:
///   --dart-define=NOTABLY_FILE_ENDPOINT=https://notably-files.<you>.workers.dev
/// Empty (the default) simply disables file sync; notes still sync.
const String kFileEndpoint =
    String.fromEnvironment('NOTABLY_FILE_ENDPOINT', defaultValue: '');

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

  final engine = SyncEngine(
    db: ref.watch(databaseProvider),
    remote: FirestoreStore(uid: user.uid),
    uid: user.uid,
    files: ref.watch(fileSyncProvider),
    onStatus: (status) => ref.read(syncStatusProvider.notifier).set(status),
  );
  ref.onDispose(engine.dispose);

  // Sync on every change from here on, plus an immediate first run.
  engine.startAutoSync();
  engine.scheduleSync(delay: const Duration(milliseconds: 500));
  return engine;
});
