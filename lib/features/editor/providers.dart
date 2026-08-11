import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/db/database.dart';
import 'data/page_repository.dart';
import 'data/stroke_repository.dart';
import 'state/editor_controller.dart';
import 'state/editor_state.dart';

final pageRepositoryProvider = Provider<PageRepository>((ref) {
  return PageRepository(ref.watch(databaseProvider), ref.watch(uuidProvider));
});

final strokeRepositoryProvider = Provider<StrokeRepository>((ref) {
  return StrokeRepository(ref.watch(databaseProvider));
});

/// Live pages of a document (for the thumbnail rail / navigation).
final pagesStreamProvider =
    StreamProvider.family<List<NotePage>, String>((ref, documentId) {
  return ref.watch(pageRepositoryProvider).watchPages(documentId);
});

/// The stateful editor for a document.
final editorControllerProvider =
    NotifierProvider.family<EditorController, EditorState, String>(
  EditorController.new,
);
