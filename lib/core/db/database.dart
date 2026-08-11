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
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        beforeOpen: (details) async {
          await customStatement('PRAGMA foreign_keys = ON');
        },
      );

  static QueryExecutor _openConnection() {
    return driftDatabase(name: 'notably');
  }
}
