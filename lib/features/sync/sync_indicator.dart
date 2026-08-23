import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/design.dart';
import '../../core/network/network_status.dart';
import '../../core/sync/sync_providers.dart';
import '../../core/sync/sync_state.dart';

enum _SyncMenuAction { stop, resume, now }

/// Compact cloud icon showing sync state. Tap for Stop / Resume / Resync.
///
/// Hidden entirely when signed out, so local-only users see no clutter.
/// A green cloud-with-check means every local change has been pushed and
/// the cloud copy matches this device.
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
    final synced = !disconnected && status.phase == SyncPhase.idle;
    final tint = disconnected
        ? (color ?? t.textSecondary)
        : status.phase == SyncPhase.error
            ? Theme.of(context).colorScheme.error
            : synced
                ? t.success
                : (color ?? t.textSecondary);

    final pct = status.progress != null
        ? (status.progress! * 100).round().clamp(0, 100)
        : null;

    final tooltip = paused
        ? 'Sync paused'
        : !online || status.phase == SyncPhase.offline
            ? kNoWifiOrMobileData
            : switch (status.phase) {
                SyncPhase.syncing => pct != null
                    ? '${status.progressMessage ?? "Syncing…"} $pct%'
                    : 'Syncing…',
                SyncPhase.idle => status.lastSyncedAt == null
                    ? 'Synced — tap to resync'
                    : 'Synced • tap to resync',
                SyncPhase.pending => status.message ??
                    '${status.pendingChanges} change(s) pending',
                SyncPhase.error => status.message ?? 'Sync error',
                SyncPhase.paused => 'Sync paused',
                SyncPhase.offline => kNoWifiOrMobileData,
                SyncPhase.disabled => 'Local only',
              };

    final icon = showSpinner
        ? SizedBox(
            width: 19,
            height: 19,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Icon(
                  Icons.cloud_upload_outlined,
                  size: 19,
                  color: tint,
                ),
                if (pct != null)
                  Text(
                    '$pct',
                    style: TextStyle(
                      fontSize: 7,
                      fontWeight: FontWeight.w800,
                      color: tint,
                    ),
                  ),
              ],
            ),
          )
        : Icon(
            disconnected || status.phase == SyncPhase.error
                ? Icons.cloud_off_rounded
                : status.phase == SyncPhase.pending
                    ? Icons.cloud_upload_outlined
                    : Icons.cloud_done_rounded,
            size: 19,
            color: tint,
          );

    return PopupMenuButton<_SyncMenuAction>(
      tooltip: tooltip,
      padding: const EdgeInsets.all(8),
      iconSize: 19,
      color: t.surface,
      icon: icon,
      itemBuilder: (context) {
        final statusLine = paused
            ? 'Sync paused'
            : !online || status.phase == SyncPhase.offline
                ? kNoWifiOrMobileData
                : switch (status.phase) {
                    SyncPhase.syncing => pct != null
                        ? '${status.progressMessage ?? 'Syncing…'} · $pct%'
                        : (status.progressMessage ?? 'Syncing…'),
                    SyncPhase.idle => 'Fully synced',
                    SyncPhase.pending => status.message ??
                        (status.pendingChanges > 0
                            ? '${status.pendingChanges} change(s) pending'
                            : 'Pending'),
                    SyncPhase.error => status.message ?? 'Sync error',
                    SyncPhase.paused => 'Sync paused',
                    SyncPhase.offline => kNoWifiOrMobileData,
                    SyncPhase.disabled => 'Local only',
                  };

        return [
          PopupMenuItem<_SyncMenuAction>(
            enabled: false,
            height: 36,
            child: Text(
              statusLine,
              style: AppTokens.mono(size: 12, color: t.textMuted),
            ),
          ),
          if (paused)
            PopupMenuItem(
              value: _SyncMenuAction.resume,
              child: Text('Resume syncing', style: TextStyle(color: t.text)),
            )
          else
            PopupMenuItem(
              value: _SyncMenuAction.stop,
              child: Text('Stop syncing', style: TextStyle(color: t.text)),
            ),
          if (online)
            PopupMenuItem(
              value: _SyncMenuAction.now,
              child: Text(
                synced ? 'Resync' : 'Sync now',
                style: TextStyle(color: t.text),
              ),
            ),
        ];
      },
      onSelected: (action) async {
        switch (action) {
          case _SyncMenuAction.stop:
            await ref.read(syncPausedProvider.notifier).setPaused(true);
          case _SyncMenuAction.resume:
            await ref.read(syncPausedProvider.notifier).setPaused(false);
            await engine.syncNowFromUser(full: false);
          case _SyncMenuAction.now:
            // "Sync now" must work even after Stop — previously syncNow()
            // no-op'd while the engine stayed paused, and the menu hid the
            // action entirely.
            if (ref.read(syncPausedProvider)) {
              await ref.read(syncPausedProvider.notifier).setPaused(false);
            }
            await engine.syncNowFromUser();
        }
      },
    );
  }
}
