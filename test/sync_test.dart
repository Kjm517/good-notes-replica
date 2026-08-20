import 'package:flutter_test/flutter_test.dart';
import 'package:notably/core/sync/sync_fields.dart';
import 'package:notably/core/sync/sync_state.dart';

void main() {
  group('remoteWins (last-write-wins with tombstones)', () {
    final t0 = DateTime.utc(2026, 1, 1, 12, 0, 0);
    final earlier = t0.subtract(const Duration(minutes: 5));
    final later = t0.add(const Duration(minutes: 5));

    test('newer remote edit replaces the local record', () {
      expect(
        remoteWins(localUpdatedAt: t0, remoteUpdatedAt: later),
        isTrue,
      );
    });

    test('older remote edit is ignored', () {
      expect(
        remoteWins(localUpdatedAt: t0, remoteUpdatedAt: earlier),
        isFalse,
      );
    });

    test('identical timestamps do not overwrite local work', () {
      expect(
        remoteWins(localUpdatedAt: t0, remoteUpdatedAt: t0),
        isFalse,
      );
    });

    test('a newer remote delete wins', () {
      expect(
        remoteWins(
          localUpdatedAt: t0,
          remoteUpdatedAt: later,
          remoteDeletedAt: later,
        ),
        isTrue,
      );
    });

    test('a delete at the same instant beats a local edit', () {
      // Deliberate: a device that deleted a record should not have it
      // resurrected by a concurrent edit elsewhere.
      expect(
        remoteWins(
          localUpdatedAt: t0,
          remoteUpdatedAt: t0,
          remoteDeletedAt: t0,
        ),
        isTrue,
      );
    });

    test('a stale delete does not undo newer local work', () {
      expect(
        remoteWins(
          localUpdatedAt: t0,
          remoteUpdatedAt: earlier,
          remoteDeletedAt: earlier,
        ),
        isFalse,
      );
    });
  });

  test('SyncStatus labels cover offline and paused', () {
    expect(const SyncStatus(phase: SyncPhase.offline).label, 'Offline');
    expect(const SyncStatus(phase: SyncPhase.paused).label, 'Sync paused');
    expect(const SyncStatus(phase: SyncPhase.syncing).isBusy, isTrue);
    expect(const SyncStatus(phase: SyncPhase.offline).isBusy, isFalse);
  });
}
