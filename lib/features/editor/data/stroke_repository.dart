import 'package:drift/drift.dart';

import '../../../core/db/database.dart';
import '../../../core/db/sync_touch.dart';
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

  /// Writes [stroke], resurrecting the row if that id was tombstoned before.
  ///
  /// Deletes only set [deletedAt], so the primary key outlives an erase and a
  /// plain insert would fail on redo, on undo of an erase, and on the selection
  /// move/transform paths, which all re-write the same stroke ids.
  Future<void> insertStroke(String pageId, InkStroke stroke) async {
    final b = stroke.bounds;
    await _db.into(_db.strokes).insertOnConflictUpdate(StrokesCompanion.insert(
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
          deletedAt: const Value(null),
          updatedAt: Value(DateTime.now()),
          dirty: const Value(true),
        ));
    await touchPageForSync(_db, pageId);
  }

  /// Tombstones the strokes so the erase replicates to other devices.
  Future<void> deleteStrokes(Iterable<String> ids) async {
    if (ids.isEmpty) return;
    final now = DateTime.now();
    final rows = await (_db.select(_db.strokes)..where((s) => s.id.isIn(ids)))
        .get();
    await (_db.update(_db.strokes)..where((s) => s.id.isIn(ids))).write(
      StrokesCompanion(
        deletedAt: Value(now),
        updatedAt: Value(now),
        dirty: const Value(true),
      ),
    );
    for (final pageId in rows.map((s) => s.pageId).toSet()) {
      await touchPageForSync(_db, pageId);
    }
  }

  Future<void> clearPage(String pageId) async {
    final now = DateTime.now();
    await (_db.update(_db.strokes)..where((s) => s.pageId.equals(pageId)))
        .write(StrokesCompanion(
      deletedAt: Value(now),
      updatedAt: Value(now),
      dirty: const Value(true),
    ));
    await touchPageForSync(_db, pageId);
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

}
