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
class RemoteInk {
  const RemoteInk({
    required this.pageId,
    required this.bytes,
    required this.updatedAt,
  });

  final String pageId;
  final Uint8List bytes;
  final DateTime updatedAt;
}

/// Which collection a record belongs to. Kept small and explicit so the
/// Firestore paths stay in one place.
enum RemoteCollection { documents, pages, elements, assets, quizzes }

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

  /// Returns false when the blob was not stored (e.g. over Firestore's size
  /// cap) so the engine can leave the local strokes dirty and retry.
  Future<bool> putInk(String pageId, Uint8List bytes, DateTime updatedAt);

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
