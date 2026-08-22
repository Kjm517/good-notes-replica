import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../../core/db/database.dart';
import '../../../core/models/enums.dart';
import '../../../core/models/margin_spec.dart';
import 'asset_repository.dart';

/// How library grids can be ordered.
enum LibrarySort { nameAsc, nameDesc, modifiedDesc, createdDesc }

/// Data access for the library: folders, notebooks and PDFs.
///
/// Everything is scoped to [ownerUid] — the signed-in account, or null when
/// signed out. Documents belonging to an account are invisible to anyone
/// else, so signing out doesn't leave one person's notes on screen for the
/// next user of the device.
class LibraryRepository {
  LibraryRepository(
    this._db,
    this._uuid,
    this._assets, {
    this.ownerUid,
  });

  final AppDatabase _db;
  final Uuid _uuid;
  final AssetRepository _assets;

  /// Firebase uid of the signed-in account, or null when signed out.
  final String? ownerUid;

  /// Rows this session is allowed to see: the current account's documents,
  /// plus anything created locally while signed out.
  Expression<bool> _owned($DocumentsTable d) => ownerUid == null
      ? d.ownerUid.isNull()
      : d.ownerUid.isNull() | d.ownerUid.equals(ownerUid!);

  // ---- Queries -------------------------------------------------------------

  /// Live list of the (non-trashed) children of [parentId] (null = root).
  Stream<List<Document>> watchChildren(String? parentId,
      {LibrarySort sort = LibrarySort.modifiedDesc}) {
    final query = _db.select(_db.documents)
      ..where((d) => d.trashedAt.isNull() & d.deletedAt.isNull() & _owned(d))
      ..where((d) => parentId == null
          ? d.parentId.isNull()
          : d.parentId.equals(parentId));
    _applySort(query, sort);
    return query.watch();
  }

  Stream<List<Document>> watchStarred() {
    final query = _db.select(_db.documents)
      ..where((d) =>
          d.trashedAt.isNull() &
          d.deletedAt.isNull() &
          d.starred.equals(true) &
          _owned(d))
      ..orderBy([(d) => OrderingTerm.desc(d.updatedAt)]);
    return query.watch();
  }

  Stream<List<Document>> watchRecents({int limit = 12}) {
    final query = _db.select(_db.documents)
      ..where((d) =>
          d.trashedAt.isNull() &
          d.deletedAt.isNull() &
          d.type.equals(DocumentType.folder.index).not() &
          d.lastOpenedAt.isNotNull() &
          _owned(d))
      ..orderBy([(d) => OrderingTerm.desc(d.lastOpenedAt)])
      ..limit(limit);
    return query.watch();
  }

  Stream<List<Document>> watchTrash() {
    final query = _db.select(_db.documents)
      ..where((d) =>
          d.trashedAt.isNotNull() & d.deletedAt.isNull() & _owned(d))
      ..orderBy([(d) => OrderingTerm.desc(d.trashedAt)]);
    return query.watch();
  }

  Stream<List<Document>> watchSearch(String term) {
    final like = '%${term.trim()}%';
    final query = _db.select(_db.documents)
      ..where((d) =>
          d.trashedAt.isNull() &
          d.deletedAt.isNull() &
          d.title.like(like) &
          _owned(d))
      ..orderBy([(d) => OrderingTerm.desc(d.updatedAt)]);
    return query.watch();
  }

  Future<Document?> findById(String id) =>
      (_db.select(_db.documents)..where((d) => d.id.equals(id)))
          .getSingleOrNull();

  Stream<Document?> watchById(String id) =>
      (_db.select(_db.documents)..where((d) => d.id.equals(id)))
          .watchSingleOrNull();

  Future<int> pageCount(String documentId) async {
    final rows = await (_db.select(_db.notePages)
          ..where((p) => p.documentId.equals(documentId)))
        .get();
    return rows.length;
  }

  /// On-disk bytes for this document's PDF/image assets (deduped by asset id).
  Future<int> storageBytesFor(String documentId) =>
      _assets.bytesForDocument(documentId);

  /// Live count of a document's live (non-tombstoned) pages, for the library
  /// card meta line. A count query rather than fetching rows so a 348-page PDF
  /// doesn't load 348 rows just to print a number.
  Stream<int> watchPageCount(String documentId) {
    final count = _db.notePages.id.count();
    final query = _db.selectOnly(_db.notePages)
      ..addColumns([count])
      ..where(_db.notePages.documentId.equals(documentId) &
          _db.notePages.deletedAt.isNull());
    return query.watchSingle().map((row) => row.read(count) ?? 0);
  }

  void _applySort(SimpleSelectStatement<$DocumentsTable, Document> q,
      LibrarySort sort) {
    // Folders always float to the top, then the chosen sort.
    q.orderBy([
      (d) => OrderingTerm.asc(d.type),
      switch (sort) {
        LibrarySort.nameAsc => (d) => OrderingTerm.asc(d.title),
        LibrarySort.nameDesc => (d) => OrderingTerm.desc(d.title),
        LibrarySort.modifiedDesc => (d) => OrderingTerm.desc(d.updatedAt),
        LibrarySort.createdDesc => (d) => OrderingTerm.desc(d.createdAt),
      },
    ]);
  }

  // ---- Mutations -----------------------------------------------------------

  Future<Document> createFolder({String? parentId, String title = 'New Folder'}) async {
    final id = _uuid.v4();
    final companion = DocumentsCompanion.insert(
      id: id,
      type: DocumentType.folder,
      title: Value(title),
      parentId: Value(parentId),
      ownerUid: Value(ownerUid),
    );
    await _db.into(_db.documents).insert(companion);
    return (await findById(id))!;
  }

  /// Creates a notebook document plus its first page.
  Future<Document> createNotebook({
    String? parentId,
    String title = 'Untitled Notebook',
    int coverStyle = 0,
    PageOrientation orientation = PageOrientation.portrait,
    PageSizePreset pageSize = PageSizePreset.a4,
    PaperTemplate template = PaperTemplate.lined,
    PaperColor paperColor = PaperColor.white,
    MarginSpec margins = MarginSpec.none,
  }) async {
    final docId = _uuid.v4();
    await _db.transaction(() async {
      await _db.into(_db.documents).insert(DocumentsCompanion.insert(
            id: docId,
            type: DocumentType.notebook,
            title: Value(title),
            parentId: Value(parentId),
            coverStyle: Value(coverStyle),
            orientation: Value(orientation),
            pageSize: Value(pageSize),
            ownerUid: Value(ownerUid),
          ));
      await _db.into(_db.notePages).insert(NotePagesCompanion.insert(
            id: _uuid.v4(),
            documentId: docId,
            pageIndex: 0,
            template: Value(template),
            paperColor: Value(paperColor),
            marginSpec: Value(margins),
          ));
    });
    return (await findById(docId))!;
  }

  Future<void> rename(String id, String title) async {
    await (_db.update(_db.documents)..where((d) => d.id.equals(id))).write(
      DocumentsCompanion(
        title: Value(title),
        updatedAt: Value(DateTime.now()),
        dirty: const Value(true),
      ),
    );
  }

  Future<void> move(String id, String? newParentId) async {
    await (_db.update(_db.documents)..where((d) => d.id.equals(id))).write(
      DocumentsCompanion(
        parentId: Value(newParentId),
        updatedAt: Value(DateTime.now()),
        dirty: const Value(true),
      ),
    );
  }

  /// Updates a document's default paper size / orientation. Blank pages that
  /// don't carry their own size follow this; imported PDF/image pages keep
  /// their captured dimensions.
  Future<void> setPageSetup(
    String id, {
    PageSizePreset? pageSize,
    PageOrientation? orientation,
  }) async {
    await (_db.update(_db.documents)..where((d) => d.id.equals(id))).write(
      DocumentsCompanion(
        pageSize:
            pageSize == null ? const Value.absent() : Value(pageSize),
        orientation:
            orientation == null ? const Value.absent() : Value(orientation),
        updatedAt: Value(DateTime.now()),
        dirty: const Value(true),
      ),
    );
  }

  Future<void> setStarred(String id, bool starred) async {
    await (_db.update(_db.documents)..where((d) => d.id.equals(id))).write(
      DocumentsCompanion(
        starred: Value(starred),
        updatedAt: Value(DateTime.now()),
        dirty: const Value(true),
      ),
    );
  }

  Future<void> touchOpened(String id) async {
    await (_db.update(_db.documents)..where((d) => d.id.equals(id))).write(
      DocumentsCompanion(lastOpenedAt: Value(DateTime.now())),
    );
  }

  Future<void> moveToTrash(String id) async {
    await (_db.update(_db.documents)..where((d) => d.id.equals(id))).write(
      DocumentsCompanion(
        trashedAt: Value(DateTime.now()),
        updatedAt: Value(DateTime.now()),
        dirty: const Value(true),
      ),
    );
  }

  Future<void> restore(String id) async {
    await (_db.update(_db.documents)..where((d) => d.id.equals(id))).write(
      DocumentsCompanion(
        trashedAt: const Value(null),
        updatedAt: Value(DateTime.now()),
        dirty: const Value(true),
      ),
    );
  }

  /// Marks a document deleted. It is kept as a tombstone rather than removed
  /// so the deletion propagates to other devices instead of being resurrected
  /// by the next sync; the UI filters tombstones out.
  Future<void> deleteForever(String id) async {
    final now = DateTime.now();
    await (_db.update(_db.documents)..where((d) => d.id.equals(id))).write(
      DocumentsCompanion(
        deletedAt: Value(now),
        updatedAt: Value(now),
        dirty: const Value(true),
      ),
    );
    await _assets.releaseOrphanedAssets();
  }

  /// Assigns any unowned local documents to [uid].
  ///
  /// Called when someone signs in: work they did before creating an account
  /// becomes theirs rather than being orphaned or shown to the next user.
  Future<int> claimLocalDocuments(String uid) async {
    return (_db.update(_db.documents)..where((d) => d.ownerUid.isNull()))
        .write(DocumentsCompanion(
      ownerUid: Value(uid),
      // Newly claimed work still needs uploading.
      dirty: const Value(true),
      updatedAt: Value(DateTime.now()),
    ));
  }

  Future<void> emptyTrash() async {
    final now = DateTime.now();
    await (_db.update(_db.documents)
          ..where((d) =>
          d.trashedAt.isNotNull() & d.deletedAt.isNull() & _owned(d)))
        .write(DocumentsCompanion(
          deletedAt: Value(now),
          updatedAt: Value(now),
          dirty: const Value(true),
        ));
    await _assets.releaseOrphanedAssets();
  }
}
