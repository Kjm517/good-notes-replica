import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../../core/db/database.dart';
import '../../../core/models/enums.dart';
import '../../../core/models/margin_spec.dart';

/// Data access for the pages of a document and their page-level settings.
class PageRepository {
  PageRepository(this._db, this._uuid);

  final AppDatabase _db;
  final Uuid _uuid;

  Stream<List<NotePage>> watchPages(String documentId) {
    final q = _db.select(_db.notePages)
      ..where((p) => p.documentId.equals(documentId) & p.deletedAt.isNull())
      ..orderBy([(p) => OrderingTerm.asc(p.pageIndex)]);
    return q.watch();
  }

  Future<NotePage?> firstPage(String documentId) {
    return (_db.select(_db.notePages)
          ..where((p) => p.documentId.equals(documentId) & p.deletedAt.isNull())
          ..orderBy([(p) => OrderingTerm.asc(p.pageIndex)])
          ..limit(1))
        .getSingleOrNull();
  }

  Future<List<NotePage>> getPages(String documentId) {
    final q = _db.select(_db.notePages)
      ..where((p) => p.documentId.equals(documentId) & p.deletedAt.isNull())
      ..orderBy([(p) => OrderingTerm.asc(p.pageIndex)]);
    return q.get();
  }

  Future<NotePage> addPage(
    String documentId, {
    int? atIndex,
    PaperTemplate template = PaperTemplate.lined,
    PaperColor paperColor = PaperColor.white,
    MarginSpec margins = MarginSpec.none,
  }) async {
    final pages = await getPages(documentId);
    final insertAt = atIndex ?? pages.length;
    return _db.transaction(() async {
      // Shift subsequent pages down.
      for (final p in pages.where((p) => p.pageIndex >= insertAt)) {
        await (_db.update(_db.notePages)..where((t) => t.id.equals(p.id)))
            .write(NotePagesCompanion(
              pageIndex: Value(p.pageIndex + 1),
              updatedAt: Value(DateTime.now()),
              dirty: const Value(true),
            ));
      }
      final id = _uuid.v4();
      await _db.into(_db.notePages).insert(NotePagesCompanion.insert(
            id: id,
            documentId: documentId,
            pageIndex: insertAt,
            template: Value(template),
            paperColor: Value(paperColor),
            marginSpec: Value(margins),
          ));
      await _touchDocument(documentId);
      return (await (_db.select(_db.notePages)..where((p) => p.id.equals(id)))
          .getSingle());
    });
  }

  /// Duplicates a page including its strokes and elements.
  Future<void> duplicatePage(String pageId) async {
    final page = await (_db.select(_db.notePages)
          ..where((p) => p.id.equals(pageId)))
        .getSingleOrNull();
    if (page == null) return;
    final strokes = await (_db.select(_db.strokes)
          ..where((s) => s.pageId.equals(pageId)))
        .get();
    final elements = await (_db.select(_db.canvasElements)
          ..where((e) => e.pageId.equals(pageId)))
        .get();

    await _db.transaction(() async {
      final all = await getPages(page.documentId);
      for (final p in all.where((p) => p.pageIndex > page.pageIndex)) {
        await (_db.update(_db.notePages)..where((t) => t.id.equals(p.id)))
            .write(NotePagesCompanion(
              pageIndex: Value(p.pageIndex + 1),
              updatedAt: Value(DateTime.now()),
              dirty: const Value(true),
            ));
      }
      final newId = _uuid.v4();
      await _db.into(_db.notePages).insert(NotePagesCompanion.insert(
            id: newId,
            documentId: page.documentId,
            pageIndex: page.pageIndex + 1,
            template: Value(page.template),
            paperColor: Value(page.paperColor),
            marginSpec: Value(page.marginSpec),
            pdfAssetId: Value(page.pdfAssetId),
            pdfPageIndex: Value(page.pdfPageIndex),
          ));
      for (final s in strokes) {
        await _db.into(_db.strokes).insert(StrokesCompanion.insert(
              id: _uuid.v4(),
              pageId: newId,
              tool: s.tool,
              color: s.color,
              width: s.width,
              opacity: Value(s.opacity),
              points: s.points,
              bboxL: s.bboxL,
              bboxT: s.bboxT,
              bboxR: s.bboxR,
              bboxB: s.bboxB,
              seq: s.seq,
            ));
      }
      for (final e in elements) {
        await _db.into(_db.canvasElements).insert(CanvasElementsCompanion.insert(
              id: _uuid.v4(),
              pageId: newId,
              type: e.type,
              data: e.data,
              x: Value(e.x),
              y: Value(e.y),
              width: Value(e.width),
              height: Value(e.height),
              scale: Value(e.scale),
              rotation: Value(e.rotation),
              z: Value(e.z),
            ));
      }
      await _touchDocument(page.documentId);
    });
  }

  Future<void> deletePage(String pageId) async {
    final page = await (_db.select(_db.notePages)
          ..where((p) => p.id.equals(pageId)))
        .getSingleOrNull();
    if (page == null) return;
    await _db.transaction(() async {
      // Tombstone rather than hard delete so the removal replicates.
      final now = DateTime.now();
      await (_db.update(_db.notePages)..where((p) => p.id.equals(pageId)))
          .write(NotePagesCompanion(
        deletedAt: Value(now),
        updatedAt: Value(now),
        dirty: const Value(true),
      ));
      final rest = await getPages(page.documentId);
      // Re-pack indices.
      for (var i = 0; i < rest.length; i++) {
        if (rest[i].pageIndex != i) {
          await (_db.update(_db.notePages)..where((t) => t.id.equals(rest[i].id)))
              .write(NotePagesCompanion(
                pageIndex: Value(i),
                updatedAt: Value(DateTime.now()),
                dirty: const Value(true),
              ));
        }
      }
      await _touchDocument(page.documentId);
    });
  }

  Future<void> reorderPage(String documentId, int oldIndex, int newIndex) async {
    final pages = await getPages(documentId);
    if (oldIndex < 0 || oldIndex >= pages.length) return;
    final moved = pages.removeAt(oldIndex);
    pages.insert(newIndex.clamp(0, pages.length), moved);
    await _db.transaction(() async {
      for (var i = 0; i < pages.length; i++) {
        await (_db.update(_db.notePages)..where((t) => t.id.equals(pages[i].id)))
            .write(NotePagesCompanion(
          pageIndex: Value(i),
          updatedAt: Value(DateTime.now()),
          dirty: const Value(true),
        ));
      }
      await _touchDocument(documentId);
    });
  }

  Future<void> updateTemplate(String pageId, PaperTemplate template) =>
      _update(pageId, NotePagesCompanion(template: Value(template)));

  Future<void> updatePaperColor(String pageId, PaperColor color) =>
      _update(pageId, NotePagesCompanion(paperColor: Value(color)));

  /// Updates the adjustable margins for a page — the custom-feature hook.
  Future<void> updateMargins(String pageId, MarginSpec margins) =>
      _update(pageId, NotePagesCompanion(marginSpec: Value(margins)));

  Future<void> setBookmark(String pageId, String? title) =>
      _update(pageId, NotePagesCompanion(bookmarkTitle: Value(title)));

  Future<void> _update(String pageId, NotePagesCompanion companion) async {
    await (_db.update(_db.notePages)..where((p) => p.id.equals(pageId))).write(
      companion.copyWith(
        updatedAt: Value(DateTime.now()),
        dirty: const Value(true),
      ),
    );
  }

  Future<void> _touchDocument(String documentId) async {
    await (_db.update(_db.documents)..where((d) => d.id.equals(documentId)))
        .write(DocumentsCompanion(
      updatedAt: Value(DateTime.now()),
      dirty: const Value(true),
    ));
  }
}
