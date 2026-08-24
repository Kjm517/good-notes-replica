import 'dart:typed_data';

/// One replicated record, as it travels to and from the cloud.
///
/// Deliberately plain maps: the sync engine is then testable against an
/// in-memory store, with no Firestore involved.
class RemoteRecord {
  const RemoteRecord({
    required this.id,
    required this.data,
    required this.updatedAt,
    this.deletedAt,
  });

  final String id;
  final Map<String, Object?> data;
  final DateTime updatedAt;
  final DateTime? deletedAt;

  bool get isDeleted => deletedAt != null;
}

/// One page's ink, as it travels back from the cloud.
///
/// Small pages keep [bytes] inline; large pages set [remoteKey] (R2) and leave
/// [bytes] null/empty — the engine downloads the blob before applying.
class RemoteInk {
  const RemoteInk({
    required this.pageId,
    required this.updatedAt,
    this.bytes,
    this.remoteKey,
  });

  final String pageId;
  final Uint8List? bytes;
  final String? remoteKey;
  final DateTime updatedAt;

  bool get usesRemoteFile =>
      remoteKey != null && remoteKey!.isNotEmpty;
}

/// Which collection a record belongs to. Kept small and explicit so the
/// Firestore paths stay in one place.
enum RemoteCollection {
  documents,
  pages,
  elements,
  assets,
  quizzes,
  userPrefs,
}

/// The cloud side of sync. Implemented by Firestore in production and by a
/// fake in tests.
abstract class RemoteStore {
  /// Records in [collection] changed since [since] (null = everything).
  ///
  /// [parentId] scopes nested collections: pages of a document, elements of a
  /// page. Ignored for top-level collections.
  Future<List<RemoteRecord>> fetchChanged(
    RemoteCollection collection, {
    DateTime? since,
    String? parentId,
  });

  /// Creates or replaces [records] in one batch.
  Future<void> upsert(
    RemoteCollection collection,
    List<RemoteRecord> records, {
    String? parentId,
  });

  /// Per-page ink, stored as the packed stroke blob rather than one cloud
  /// document per stroke — a page can hold hundreds of strokes and Firestore
  /// bills per write.
  Future<Uint8List?> fetchInk(String pageId);

  /// Ink changed since [since], oldest first, at most [limit] per call.
  ///
  /// Asking page by page costs one round trip per page, so opening a 900-page
  /// textbook on a second device spent minutes asking about pages that had
  /// never been drawn on. This asks once for whatever actually changed.
  Future<List<RemoteInk>> fetchInkChanged({
    DateTime? since,
    int limit = 50,
  });

  /// Stores page ink metadata. Pass [bytes] for inline storage, or
  /// [remoteKey] after uploading a large blob to R2. Returns false when the
  /// row could not be written so the engine leaves strokes dirty.
  Future<bool> putInk(
    String pageId,
    DateTime updatedAt, {
    Uint8List? bytes,
    String? remoteKey,
  });

  /// Ink for a specific set of pages, regardless of when it changed.
  ///
  /// [fetchInkChanged] is bounded per run, so a device syncing a large
  /// backlog can go idle before it reaches the notebook the user is about to
  /// open. Opening a document asks for exactly its pages instead of hoping
  /// the incremental cursor already covered them.
  Future<List<RemoteInk>> fetchInkForPages(List<String> pageIds) async =>
      const [];

  /// A single record by id, or null if it doesn't exist. Used to hydrate asset
  /// metadata when a pulled page points at a PDF that this device has never
  /// seen.
  Future<RemoteRecord?> fetchById(
    RemoteCollection collection,
    String id, {
    String? parentId,
  });

  /// Fires when another device may have changed this account's library.
  ///
  /// The local engine listens so a tablet picks up a phone import without
  /// waiting for a resume, a tap on the cloud icon, or a local edit.
  Stream<void> watchChanges() => const Stream<void>.empty();
}
