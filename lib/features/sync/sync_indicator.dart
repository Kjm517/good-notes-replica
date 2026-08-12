import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/sync/sync_providers.dart';
import '../../core/sync/sync_state.dart';

/// Compact cloud icon showing sync state; tap to sync now.
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
    if (engine == null || status.phase == SyncPhase.disabled) {
      return const SizedBox.shrink();
    }

    final scheme = Theme.of(context).colorScheme;
    final tint = switch (status.phase) {
      SyncPhase.error => scheme.error,
      SyncPhase.idle => color ?? scheme.onSurface,
      _ => color ?? scheme.onSurface,
    };

    return Tooltip(
      message: switch (status.phase) {
        SyncPhase.syncing => 'Syncing…',
        SyncPhase.idle => status.lastSyncedAt == null
            ? 'Synced'
            : 'Synced • tap to sync now',
        SyncPhase.pending => '${status.pendingChanges} change(s) pending',
        SyncPhase.error => status.message ?? 'Sync error',
        SyncPhase.disabled => 'Local only',
      },
      child: IconButton(
        visualDensity: VisualDensity.compact,
        onPressed: status.isBusy ? null : engine.syncNow,
        icon: status.isBusy
            ? SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2, color: tint),
              )
            : Icon(
                switch (status.phase) {
                  SyncPhase.error => Icons.cloud_off_rounded,
                  SyncPhase.pending => Icons.cloud_upload_outlined,
                  _ => Icons.cloud_done_rounded,
                },
                size: 19,
                color: tint,
              ),
      ),
    );
  }
}
