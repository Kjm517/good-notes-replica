import 'package:flutter/foundation.dart';

/// What the sync engine is doing right now.
enum SyncPhase {
  /// Not signed in, or Firebase unavailable — purely local.
  disabled,

  /// Signed in, nothing pending.
  idle,

  /// Uploading local changes / downloading remote ones.
  syncing,

  /// Local changes are waiting for connectivity or the next run.
  pending,

  /// The last attempt failed; [SyncStatus.message] says why.
  error,
}

@immutable
class SyncStatus {
  const SyncStatus({
    this.phase = SyncPhase.disabled,
    this.message,
    this.lastSyncedAt,
    this.pendingChanges = 0,
  });

  final SyncPhase phase;
  final String? message;
  final DateTime? lastSyncedAt;

  /// How many local records are waiting to be pushed.
  final int pendingChanges;

  bool get isBusy => phase == SyncPhase.syncing;

  /// Short label for the toolbar indicator.
  String get label => switch (phase) {
        SyncPhase.disabled => 'Local only',
        SyncPhase.idle => 'Synced',
        SyncPhase.syncing => 'Syncing…',
        SyncPhase.pending =>
          pendingChanges > 0 ? '$pendingChanges pending' : 'Pending',
        SyncPhase.error => 'Sync error',
      };

  SyncStatus copyWith({
    SyncPhase? phase,
    String? message,
    DateTime? lastSyncedAt,
    int? pendingChanges,
    bool clearMessage = false,
  }) =>
      SyncStatus(
        phase: phase ?? this.phase,
        message: clearMessage ? null : (message ?? this.message),
        lastSyncedAt: lastSyncedAt ?? this.lastSyncedAt,
        pendingChanges: pendingChanges ?? this.pendingChanges,
      );
}
