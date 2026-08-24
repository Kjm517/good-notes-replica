import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../auth/providers.dart';
import '../settings/entitlements.dart';
import '../../core/db/database.dart';
import 'data/asset_repository.dart';
import 'data/import_service.dart';
import 'data/library_repository.dart';

/// Scoped to the signed-in account, so the library rebuilds (and re-filters)
/// the moment someone signs in or out.
final libraryRepositoryProvider = Provider<LibraryRepository>((ref) {
  final user = ref.watch(authStateProvider).asData?.value;
  return LibraryRepository(
    ref.watch(databaseProvider),
    ref.watch(uuidProvider),
    ref.watch(assetRepositoryProvider),
    ownerUid: user?.uid,
  );
});

final assetRepositoryProvider = Provider<AssetRepository>((ref) {
  return AssetRepository(
    ref.watch(databaseProvider),
    storageQuotaBytes: ref.watch(storageQuotaBytesProvider),
  );
});

final importServiceProvider = Provider<ImportService>((ref) {
  final user = ref.watch(authStateProvider).asData?.value;
  return ImportService(
    ref.watch(databaseProvider),
    ref.watch(uuidProvider),
    ref.watch(assetRepositoryProvider),
    ownerUid: user?.uid,
  );
});

/// Current sort order for library grids.
final librarySortProvider =
    StateProvider<LibrarySort>((ref) => LibrarySort.modifiedDesc);

/// Which shelf the library grid is showing.
///
/// Trash is deliberately absent: it needs restore and empty actions that the
/// normal grid doesn't offer, so it stays its own screen at `/trash`.
enum LibrarySection { all, recent, starred }

extension LibrarySectionInfo on LibrarySection {
  String get label => switch (this) {
        LibrarySection.all => 'All documents',
        LibrarySection.recent => 'Recent',
        LibrarySection.starred => 'Starred',
      };

  /// Shorter form for the mobile filter chips, where space is tight.
  String get shortLabel => this == LibrarySection.all ? 'All' : label;
}

final librarySectionProvider =
    StateProvider<LibrarySection>((ref) => LibrarySection.all);

/// Total bytes held by imported files, for the sidebar storage readout.
///
/// Only assets carry real weight — ink is a few KB per page — so summing the
/// asset sizes is an honest measure of what the library costs on disk.
final libraryStorageProvider = StreamProvider<int>((ref) {
  return ref.watch(assetRepositoryProvider).watchTotalBytes();
});

/// Grid vs list layout for the library.
final libraryGridModeProvider = StateProvider<bool>((ref) => true);

/// Children of a folder (null arg = root shelf).
final folderChildrenProvider =
    StreamProvider.family<List<Document>, String?>((ref, parentId) {
  final repo = ref.watch(libraryRepositoryProvider);
  final sort = ref.watch(librarySortProvider);
  return repo.watchChildren(parentId, sort: sort);
});

final starredProvider = StreamProvider<List<Document>>((ref) {
  return ref.watch(libraryRepositoryProvider).watchStarred();
});

final recentsProvider = StreamProvider<List<Document>>((ref) {
  return ref.watch(libraryRepositoryProvider).watchRecents();
});

final trashProvider = StreamProvider<List<Document>>((ref) {
  return ref.watch(libraryRepositoryProvider).watchTrash();
});

/// Free-text search query for the library.
final librarySearchQueryProvider = StateProvider<String>((ref) => '');

final librarySearchResultsProvider = StreamProvider<List<Document>>((ref) {
  final query = ref.watch(librarySearchQueryProvider).trim();
  if (query.isEmpty) return Stream.value(const []);
  return ref.watch(libraryRepositoryProvider).watchSearch(query);
});

/// Look up a single document by id (for editor/app bar titles).
final documentProvider =
    FutureProvider.family<Document?, String>((ref, id) async {
  return ref.watch(libraryRepositoryProvider).findById(id);
});

/// Live single-document stream (updates on rename etc.).
final documentStreamProvider =
    StreamProvider.family<Document?, String>((ref, id) {
  return ref.watch(libraryRepositoryProvider).watchById(id);
});

/// Live page count for a document, for the library card meta line.
final documentPageCountProvider =
    StreamProvider.family<int, String>((ref, id) {
  return ref.watch(libraryRepositoryProvider).watchPageCount(id);
});
