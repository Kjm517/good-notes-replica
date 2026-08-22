import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:notably/core/db/database.dart';
import 'package:notably/core/models/enums.dart';
import 'package:notably/core/sync/remote_store.dart';
import 'package:notably/core/sync/sync_engine.dart';

import 'sync_engine_test.dart' show MemoryRemoteStore;

/// Deleting on one device and seeing it gone on another.
///
/// Two separate things can stop that happening, and only one of them is a bug:
///
///  * The **cursor** — an incremental pull asks only for records newer than
///    the last run, measured on *this* device's clock against timestamps
///    written by *other* devices' clocks. A tombstone that falls outside that
///    window is never even fetched. This is what the refresh button escapes.
///  * **Last-write-wins** — a fetched tombstone still has to beat the local
///    row's timestamp. A genuinely stale delete losing to newer local work is
///    deliberate (see `sync_test.dart`), not something refresh should override.
void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  late AppDatabase db;
  late MemoryRemoteStore cloud;
  late SyncEngine engine;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    cloud = MemoryRemoteStore();
    engine = SyncEngine(
      db: db,
      remote: cloud,
      uid: 'user-1',
      isOnline: () async => true,
    );
  });

  tearDown(() async {
    engine.dispose();
    await db.close();
  });

  /// Puts a document in the cloud as if another device had written it.
  void cloudDocument(String id, {required DateTime at, DateTime? deletedAt}) {
    cloud.documents[id] = RemoteRecord(
      id: id,
      updatedAt: at,
      deletedAt: deletedAt,
      data: {
        'type': DocumentType.pdf.index,
        'title': 'Textbook',
        'createdAt': at.millisecondsSinceEpoch,
      },
    );
  }

  Future<Document?> local(String id) =>
      (db.select(db.documents)..where((d) => d.id.equals(id)))
          .getSingleOrNull();

  Future<List<String>> shelf() async {
    final rows = await (db.select(db.documents)
          ..where((d) => d.deletedAt.isNull()))
        .get();
    return rows.map((d) => d.id).toList();
  }

  test('deleting on one device removes it from the other', () async {
    final now = DateTime.now();
    cloudDocument('doc-1', at: now.subtract(const Duration(minutes: 2)));
    await engine.syncNow();
    expect(await shelf(), ['doc-1']);

    // The other device deletes it a moment later, as a real device would.
    cloudDocument('doc-1',
        at: now.subtract(const Duration(minutes: 1)),
        deletedAt: now.subtract(const Duration(minutes: 1)));
    await engine.syncNow();

    expect(await shelf(), isEmpty, reason: 'the card should be gone');
  });

  test('refresh catches a delete the incremental cursor skipped', () async {
    final now = DateTime.now();

    // Imported on the other device ten minutes ago and pulled here, so the
    // local row carries that device's timestamp.
    cloudDocument('doc-1', at: now.subtract(const Duration(minutes: 10)));
    await engine.syncNow();
    expect(await shelf(), ['doc-1']);

    // The delete is newer than the local row — last-write-wins would accept
    // it — but older than this device's sync cursor, so an incremental pull
    // never asks for it. This is the exact shape of a cross-device delete
    // going missing when two clocks disagree.
    final deletedAt = now.subtract(const Duration(minutes: 6));
    cloudDocument('doc-1', at: deletedAt, deletedAt: deletedAt);

    await engine.refreshNow();
    expect(
      (await local('doc-1'))?.deletedAt,
      isNotNull,
      reason: 'refresh ignores the cursor and re-reads the account',
    );
    expect(await shelf(), isEmpty);
  });

  test('refresh does not resurrect anything it already has', () async {
    final now = DateTime.now();
    cloudDocument('doc-1', at: now.subtract(const Duration(minutes: 2)));
    cloudDocument('doc-2', at: now.subtract(const Duration(minutes: 2)));
    await engine.syncNow();

    await engine.refreshNow();
    await engine.refreshNow();

    expect(await shelf(), ['doc-1', 'doc-2']);
  });

  test('a genuinely stale delete still loses to newer local work', () async {
    final now = DateTime.now();
    cloudDocument('doc-1', at: now);
    await engine.syncNow();

    // Deleted long before the version this device holds. Refresh fetches it,
    // and last-write-wins correctly refuses it — refresh widens what is
    // *asked for*, it does not override conflict resolution.
    final ancient = now.subtract(const Duration(hours: 1));
    cloudDocument('doc-1', at: ancient, deletedAt: ancient);
    await engine.refreshNow();

    expect(await shelf(), ['doc-1']);
  });
}
