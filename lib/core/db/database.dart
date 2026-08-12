import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

import '../models/enums.dart';
import '../models/margin_spec.dart';
import 'converters.dart';
import 'tables.dart';

part 'database.g.dart';

@DriftDatabase(tables: [Documents, NotePages, Strokes, CanvasElements, Assets])
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor])
      : super(executor ?? _openConnection());

  @override
  int get schemaVersion => 9;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onUpgrade: (m, from, to) async {
          if (from < 2) {
            await m.addColumn(notePages, notePages.bgAssetId);
            await m.addColumn(notePages, notePages.pageW);
            await m.addColumn(notePages, notePages.pageH);
          }
          if (from < 3) {
            // Assets.data changed from BLOB to base64 TEXT. Recreate the table
            // (imported assets, if any, are re-importable).
            await m.deleteTable('assets');
            await m.createTable(assets);
          }
          if (from < 4) {
            await m.addColumn(strokes, strokes.style);
            await m.addColumn(strokes, strokes.filled);
          }
          if (from < 5) {
            await m.addColumn(strokes, strokes.tip);
          }
          if (from < 6) {
            // Sync bookkeeping on every replicated table. Spelled out per
            // table because each generated table is its own type.
            await m.addColumn(documents, documents.deletedAt);
            await m.addColumn(documents, documents.dirty);
            await m.addColumn(documents, documents.remoteUpdatedAt);

            await m.addColumn(notePages, notePages.deletedAt);
            await m.addColumn(notePages, notePages.dirty);
            await m.addColumn(notePages, notePages.remoteUpdatedAt);

            await m.addColumn(canvasElements, canvasElements.deletedAt);
            await m.addColumn(canvasElements, canvasElements.dirty);
            await m.addColumn(canvasElements, canvasElements.remoteUpdatedAt);

            // Strokes had no updatedAt at all; without it sync cannot tell
            // which side of a conflict is newer.
            await m.addColumn(strokes, strokes.updatedAt);
            await m.addColumn(strokes, strokes.deletedAt);
            await m.addColumn(strokes, strokes.dirty);
            await m.addColumn(strokes, strokes.remoteUpdatedAt);

            await m.addColumn(assets, assets.deletedAt);
            await m.addColumn(assets, assets.dirty);
            await m.addColumn(assets, assets.remoteUpdatedAt);
            // Assets move from base64-in-database to files on disk.
            await m.addColumn(assets, assets.localPath);
            await m.addColumn(assets, assets.sha256);
            await m.addColumn(assets, assets.sizeBytes);
            await m.addColumn(assets, assets.remoteKey);
          }
          if (from < 7) {
            await m.addColumn(documents, documents.coverThumb);
          }
          if (from < 8) {
            await m.addColumn(notePages, notePages.searchText);
          }
          if (from < 9) {
            await m.addColumn(documents, documents.ownerUid);
          }
        },
        beforeOpen: (details) async {
          await customStatement('PRAGMA foreign_keys = ON');
        },
      );

  static QueryExecutor _openConnection() {
    return driftDatabase(
      name: 'notably',
      // Used only on the web build; native ignores these. The two files are
      // served from web/ (see web/sqlite3.wasm and web/drift_worker.js).
      web: DriftWebOptions(
        sqlite3Wasm: Uri.parse('sqlite3.wasm'),
        driftWorker: Uri.parse('drift_worker.js'),
      ),
    );
  }
}
