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

  /// Signed in, but Wi-Fi and mobile data are both off.
  offline,

  /// The user paused account sync from the cloud menu.
  paused,

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
    this.progress,
    this.progressMessage,
    this.activeAssetId,
  });

  final SyncPhase phase;
  final String? message;
  final DateTime? lastSyncedAt;

  /// How many local records are waiting to be pushed.
  final int pendingChanges;

  /// Progress from 0.0 to 1.0 during [SyncPhase.syncing], null otherwise.
  final double? progress;

  /// Human-readable description of the current sync step, e.g.
  /// "Uploading documents…".
  final String? progressMessage;

  /// Asset currently uploading to R2, if any — used to gray the library card.
  final String? activeAssetId;

  bool get isBusy => phase == SyncPhase.syncing;

  /// Short label for the toolbar indicator.
  String get label => switch (phase) {
        SyncPhase.disabled => 'Local only',
        SyncPhase.idle => 'Synced',
        SyncPhase.syncing => 'Syncing…',
        SyncPhase.pending =>
          pendingChanges > 0 ? '$pendingChanges pending' : 'Pending',
        SyncPhase.offline => 'Offline',
        SyncPhase.paused => 'Sync paused',
        SyncPhase.error => 'Sync error',
      };

  SyncStatus copyWith({
    SyncPhase? phase,
    String? message,
    DateTime? lastSyncedAt,
    int? pendingChanges,
    double? progress,
    String? progressMessage,
    String? activeAssetId,
    bool clearMessage = false,
    bool clearProgress = false,
  }) =>
      SyncStatus(
        phase: phase ?? this.phase,
        message: clearMessage ? null : (message ?? this.message),
        lastSyncedAt: lastSyncedAt ?? this.lastSyncedAt,
        pendingChanges: pendingChanges ?? this.pendingChanges,
        progress: clearProgress ? null : (progress ?? this.progress),
        progressMessage:
            clearProgress ? null : (progressMessage ?? this.progressMessage),
        activeAssetId:
            clearProgress ? null : (activeAssetId ?? this.activeAssetId),
      );
}
