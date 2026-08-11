import 'package:drift/drift.dart';

import '../../../core/db/database.dart';
import '../../../core/ink/ink_stroke.dart';

/// Data access for ink strokes belonging to a page.
class StrokeRepository {
  StrokeRepository(this._db);

  final AppDatabase _db;

  Future<List<InkStroke>> getStrokes(String pageId) async {
    final rows = await (_db.select(_db.strokes)
          ..where((s) => s.pageId.equals(pageId))
          ..orderBy([(s) => OrderingTerm.asc(s.seq)]))
        .get();
    return rows.map(_toInk).toList();
  }

  Stream<List<InkStroke>> watchStrokes(String pageId) {
    return (_db.select(_db.strokes)
          ..where((s) => s.pageId.equals(pageId))
          ..orderBy([(s) => OrderingTerm.asc(s.seq)]))
        .watch()
        .map((rows) => rows.map(_toInk).toList());
  }

  Future<void> insertStroke(String pageId, InkStroke stroke) async {
    final b = stroke.bounds;
    await _db.into(_db.strokes).insert(StrokesCompanion.insert(
          id: stroke.id,
          pageId: pageId,
          tool: stroke.tool,
          color: stroke.color,
          width: stroke.width,
          opacity: Value(stroke.opacity),
          points: stroke.packPoints(),
          bboxL: b.left,
          bboxT: b.top,
          bboxR: b.right,
          bboxB: b.bottom,
          seq: stroke.seq,
        ));
    await _touchPage(pageId);
  }

  Future<void> deleteStrokes(Iterable<String> ids) async {
    if (ids.isEmpty) return;
    await (_db.delete(_db.strokes)..where((s) => s.id.isIn(ids))).go();
  }

  Future<void> clearPage(String pageId) async {
    await (_db.delete(_db.strokes)..where((s) => s.pageId.equals(pageId))).go();
    await _touchPage(pageId);
  }

  Future<int> maxSeq(String pageId) async {
    final rows = await (_db.select(_db.strokes)
          ..where((s) => s.pageId.equals(pageId)))
        .get();
    return rows.fold<int>(-1, (m, s) => s.seq > m ? s.seq : m);
  }

  InkStroke _toInk(Stroke s) => InkStroke(
        id: s.id,
        tool: s.tool,
        color: s.color,
        width: s.width,
        opacity: s.opacity,
        seq: s.seq,
        points: InkStroke.unpackPoints(s.points),
      );

  Future<void> _touchPage(String pageId) async {
    await (_db.update(_db.notePages)..where((p) => p.id.equals(pageId)))
        .write(NotePagesCompanion(updatedAt: Value(DateTime.now())));
  }
}
