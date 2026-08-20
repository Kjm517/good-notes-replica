import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/design.dart';
import '../../core/network/network_status.dart';
import '../../core/sync/sync_providers.dart';
import '../../core/sync/sync_state.dart';

enum _SyncMenuAction { stop, resume, now }

/// Compact cloud icon showing sync state. Tap for Stop / Resume / Sync now.
///
/// Hidden entirely when signed out, so local-only users see no clutter.
class SyncIndicator extends ConsumerWidget {
  const SyncIndicator({super.key, this.color});

  /// Icon colour, so it can match whichever bar it sits in.
  final Color? color;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(syncStatusProvider);
    final engine = ref.watch(syncEngineProvider);
    final paused = ref.watch(syncPausedProvider);
    final online = ref.watch(onlineProvider).asData?.value ?? true;
    if (engine == null || status.phase == SyncPhase.disabled) {
      return const SizedBox.shrink();
    }

    final t = context.tokens;
    final disconnected = paused ||
        !online ||
        status.phase == SyncPhase.offline ||
        status.phase == SyncPhase.paused;
    final showSpinner = status.isBusy && online && !paused;
    final tint = disconnected
        ? (color ?? t.textSecondary)
        : status.phase == SyncPhase.error
            ? Theme.of(context).colorScheme.error
            : (color ?? t.textSecondary);

    final tooltip = paused
        ? 'Sync paused'
        : !online || status.phase == SyncPhase.offline
            ? kNoWifiOrMobileData
            : switch (status.phase) {
                SyncPhase.syncing => 'Syncing…',
                SyncPhase.idle => status.lastSyncedAt == null
                    ? 'Synced'
                    : 'Synced • tap for options',
                SyncPhase.pending => '${status.pendingChanges} change(s) pending',
                SyncPhase.error => status.message ?? 'Sync error',
                SyncPhase.paused => 'Sync paused',
                SyncPhase.offline => kNoWifiOrMobileData,
                SyncPhase.disabled => 'Local only',
              };

    return PopupMenuButton<_SyncMenuAction>(
      tooltip: tooltip,
      padding: const EdgeInsets.all(8),
      iconSize: 19,
      color: t.surface,
      icon: showSpinner
          ? SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2, color: tint),
            )
          : Icon(
              disconnected || status.phase == SyncPhase.error
                  ? Icons.cloud_off_rounded
                  : status.phase == SyncPhase.pending
                      ? Icons.cloud_upload_outlined
                      : Icons.cloud_done_rounded,
              size: 19,
              color: tint,
            ),
      itemBuilder: (context) => [
        if (paused)
          PopupMenuItem(
            value: _SyncMenuAction.resume,
            child: Text('Resume syncing', style: TextStyle(color: t.text)),
          )
        else ...[
          PopupMenuItem(
            value: _SyncMenuAction.stop,
            child: Text('Stop syncing', style: TextStyle(color: t.text)),
          ),
          if (online)
            PopupMenuItem(
              value: _SyncMenuAction.now,
              child: Text('Sync now', style: TextStyle(color: t.text)),
            ),
        ],
      ],
      onSelected: (action) {
        switch (action) {
          case _SyncMenuAction.stop:
            ref.read(syncPausedProvider.notifier).setPaused(true);
          case _SyncMenuAction.resume:
            ref.read(syncPausedProvider.notifier).setPaused(false);
          case _SyncMenuAction.now:
            engine.syncNow();
        }
      },
    );
  }
}
