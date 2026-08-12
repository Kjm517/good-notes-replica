/// Conflict resolution for the sync engine.
///
/// Every synced table carries `updatedAt`, `deletedAt`, `dirty` and
/// `remoteUpdatedAt` (see `SyncedTable` in `lib/core/db/tables.dart`), and
/// every local mutation stamps `updatedAt` + `dirty` — without that the sync
/// engine cannot tell a record changed and the edit is silently lost.
library;

/// Decides whether an incoming remote record should replace the local one.
///
/// Last-write-wins on `updatedAt`. A tombstone of the same age or newer beats
/// a local edit, so deleting on one device is not undone by a stale edit
/// arriving from another.
bool remoteWins({
  required DateTime localUpdatedAt,
  required DateTime remoteUpdatedAt,
  DateTime? remoteDeletedAt,
}) {
  if (remoteDeletedAt != null && !remoteUpdatedAt.isBefore(localUpdatedAt)) {
    return true;
  }
  return remoteUpdatedAt.isAfter(localUpdatedAt);
}
