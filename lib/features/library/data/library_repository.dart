import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../../core/db/database.dart';
import '../../../core/models/enums.dart';
import '../../../core/models/margin_spec.dart';

/// How library grids can be ordered.
enum LibrarySort { nameAsc, nameDesc, modifiedDesc, createdDesc }

/// Data access for the library: folders, notebooks and PDFs.
class LibraryRepository {
  LibraryRepository(this._db, this._uuid);

  final AppDatabase _db;
  final Uuid _uuid;

  // ---- Queries -------------------------------------------------------------

  /// Live list of the (non-trashed) children of [parentId] (null = root).
  Stream<List<Document>> watchChildren(String? parentId,
      {LibrarySort sort = LibrarySort.modifiedDesc}) {
    final query = _db.select(_db.documents)
      ..where((d) => d.trashedAt.isNull())
      ..where((d) => parentId == null
          ? d.parentId.isNull()
          : d.parentId.equals(parentId));
    _applySort(query, sort);
    return query.watch();
  }

  Stream<List<Document>> watchStarred() {
    final query = _db.select(_db.documents)
      ..where((d) => d.trashedAt.isNull() & d.starred.equals(true))
      ..orderBy([(d) => OrderingTerm.desc(d.updatedAt)]);
    return query.watch();
  }

  Stream<List<Document>> watchRecents({int limit = 12}) {
    final query = _db.select(_db.documents)
      ..where((d) =>
          d.trashedAt.isNull() &
          d.type.equals(DocumentType.folder.index).not() &
          d.lastOpenedAt.isNotNull())
      ..orderBy([(d) => OrderingTerm.desc(d.lastOpenedAt)])
      ..limit(limit);
    return query.watch();
  }

  Stream<List<Document>> watchTrash() {
    final query = _db.select(_db.documents)
      ..where((d) => d.trashedAt.isNotNull())
      ..orderBy([(d) => OrderingTerm.desc(d.trashedAt)]);
    return query.watch();
  }

  Stream<List<Document>> watchSearch(String term) {
    final like = '%${term.trim()}%';
    final query = _db.select(_db.documents)
      ..where((d) => d.trashedAt.isNull() & d.title.like(like))
      ..orderBy([(d) => OrderingTerm.desc(d.updatedAt)]);
    return query.watch();
  }

  Future<Document?> findById(String id) =>
      (_db.select(_db.documents)..where((d) => d.id.equals(id)))
          .getSingleOrNull();

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
      DocumentsCompanion(title: Value(title), updatedAt: Value(DateTime.now())),
    );
  }

  Future<void> move(String id, String? newParentId) async {
    await (_db.update(_db.documents)..where((d) => d.id.equals(id))).write(
      DocumentsCompanion(
        parentId: Value(newParentId),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  Future<void> setStarred(String id, bool starred) async {
    await (_db.update(_db.documents)..where((d) => d.id.equals(id))).write(
      DocumentsCompanion(
        starred: Value(starred),
        updatedAt: Value(DateTime.now()),
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
      DocumentsCompanion(trashedAt: Value(DateTime.now())),
    );
  }

  Future<void> restore(String id) async {
    await (_db.update(_db.documents)..where((d) => d.id.equals(id))).write(
      const DocumentsCompanion(trashedAt: Value(null)),
    );
  }

  /// Permanently deletes a document. Pages/strokes/elements cascade.
  Future<void> deleteForever(String id) async {
    await (_db.delete(_db.documents)..where((d) => d.id.equals(id))).go();
  }

  Future<void> emptyTrash() async {
    await (_db.delete(_db.documents)..where((d) => d.trashedAt.isNotNull()))
        .go();
  }
}
