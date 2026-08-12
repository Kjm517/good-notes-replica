import 'package:drift/drift.dart';

import '../../../core/db/database.dart';
import '../../../core/ink/ink_stroke.dart';

/// Data access for ink strokes belonging to a page.
class StrokeRepository {
  StrokeRepository(this._db);

  final AppDatabase _db;

  Future<List<InkStroke>> getStrokes(String pageId) async {
    final rows = await (_db.select(_db.strokes)
          ..where((s) => s.pageId.equals(pageId) & s.deletedAt.isNull())
          ..orderBy([(s) => OrderingTerm.asc(s.seq)]))
        .get();
    return rows.map(_toInk).toList();
  }

  Stream<List<InkStroke>> watchStrokes(String pageId) {
    return (_db.select(_db.strokes)
          ..where((s) => s.pageId.equals(pageId) & s.deletedAt.isNull())
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
          style: Value(stroke.style),
          filled: Value(stroke.filled),
          tip: Value(stroke.tip),
          bboxL: b.left,
          bboxT: b.top,
          bboxR: b.right,
          bboxB: b.bottom,
          seq: stroke.seq,
        ));
    await _touchPage(pageId);
  }

  /// Tombstones the strokes so the erase replicates to other devices.
  Future<void> deleteStrokes(Iterable<String> ids) async {
    if (ids.isEmpty) return;
    final now = DateTime.now();
    await (_db.update(_db.strokes)..where((s) => s.id.isIn(ids))).write(
      StrokesCompanion(
        deletedAt: Value(now),
        updatedAt: Value(now),
        dirty: const Value(true),
      ),
    );
  }

  Future<void> clearPage(String pageId) async {
    final now = DateTime.now();
    await (_db.update(_db.strokes)..where((s) => s.pageId.equals(pageId)))
        .write(StrokesCompanion(
      deletedAt: Value(now),
      updatedAt: Value(now),
      dirty: const Value(true),
    ));
    await _touchPage(pageId);
  }

  Future<int> maxSeq(String pageId) async {
    final rows = await (_db.select(_db.strokes)
          ..where((s) => s.pageId.equals(pageId) & s.deletedAt.isNull()))
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
        style: s.style,
        filled: s.filled,
        tip: s.tip,
        points: InkStroke.unpackPoints(s.points),
      );

  Future<void> _touchPage(String pageId) async {
    await (_db.update(_db.notePages)..where((p) => p.id.equals(pageId)))
        .write(NotePagesCompanion(
      updatedAt: Value(DateTime.now()),
      dirty: const Value(true),
    ));
  }
}
