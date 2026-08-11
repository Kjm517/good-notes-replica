import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/db/database.dart';
import 'data/library_repository.dart';

final libraryRepositoryProvider = Provider<LibraryRepository>((ref) {
  return LibraryRepository(ref.watch(databaseProvider), ref.watch(uuidProvider));
});

/// Current sort order for library grids.
final librarySortProvider =
    StateProvider<LibrarySort>((ref) => LibrarySort.modifiedDesc);

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
