import 'package:drift/drift.dart';

import '../db/database.dart';
import 'account_prefs.dart';

/// Reads/writes the single local [UserPrefs] row and marks it dirty for sync.
class UserPrefsRepository {
  UserPrefsRepository(this._db);

  final AppDatabase _db;

  Future<AccountPrefs> load() async {
    final row = await (_db.select(_db.userPrefs)
          ..where((p) => p.id.equals(kUserPrefsRowId)))
        .getSingleOrNull();
    if (row == null) return const AccountPrefs();
    return AccountPrefs.fromJson(row.payload);
  }

  Stream<AccountPrefs> watch() {
    return (_db.select(_db.userPrefs)
          ..where((p) => p.id.equals(kUserPrefsRowId)))
        .watch()
        .map((rows) {
      if (rows.isEmpty) return const AccountPrefs();
      return AccountPrefs.fromJson(rows.first.payload);
    });
  }

  Future<void> save(
    AccountPrefs prefs, {
    bool dirty = true,
  }) async {
    final now = DateTime.now();
    await _db.into(_db.userPrefs).insertOnConflictUpdate(
          UserPrefsCompanion.insert(
            id: kUserPrefsRowId,
            payload: Value(prefs.toJson()),
            updatedAt: Value(now),
            dirty: Value(dirty),
            deletedAt: const Value(null),
          ),
        );
  }

  Future<void> applyRemote({
    required String payload,
    required DateTime updatedAt,
  }) async {
    await _db.into(_db.userPrefs).insertOnConflictUpdate(
          UserPrefsCompanion.insert(
            id: kUserPrefsRowId,
            payload: Value(payload),
            updatedAt: Value(updatedAt),
            dirty: const Value(false),
            remoteUpdatedAt: Value(updatedAt),
            deletedAt: const Value(null),
          ),
        );
  }
}
