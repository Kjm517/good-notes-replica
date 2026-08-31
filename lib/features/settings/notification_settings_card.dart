import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/design.dart';
import '../../core/notifications/notification_providers.dart';
import '../../core/notifications/notification_service.dart';
import 'settings_widgets.dart';

/// Notification switches plus the OS permission state.
///
/// The in-app switch and the system permission are shown separately on
/// purpose: "on but blocked by iOS" is the confusing case, and collapsing the
/// two into one toggle hides exactly the thing the user needs to fix.
class NotificationSettingsCard extends ConsumerWidget {
  const NotificationSettingsCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    final enabled = ref.watch(notificationsEnabledProvider);
    final silent = ref.watch(notificationsSilentProvider);
    final permission = ref.watch(notificationPermissionProvider);

    if (!NotificationService.instance.supported) {
      return SettingsGroupCard(
        children: [
          SettingsRow(
            icon: Icons.notifications_off_outlined,
            title: 'Notifications',
            subtitle: 'Not available on this platform',
            dimmed: true,
          ),
        ],
      );
    }

    final blocked = permission.maybeWhen(
      data: (p) =>
          p == NotificationPermission.denied ||
          p == NotificationPermission.permanentlyDenied,
      orElse: () => false,
    );

    return SettingsGroupCard(
      children: [
        SwitchListTile.adaptive(
          value: enabled,
          onChanged: (v) => setNotificationsEnabled(ref, v),
          secondary: Icon(
            enabled
                ? Icons.notifications_active_outlined
                : Icons.notifications_off_outlined,
            color: enabled ? t.accentText : t.textMuted,
          ),
          title: const Text('Notifications', style: TextStyle(fontSize: 14)),
          subtitle: Text(
            'Plan reminders and announcements',
            style: AppTokens.mono(size: 10, color: t.textFaint),
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 14),
        ),
        if (enabled)
          SwitchListTile.adaptive(
            value: silent,
            onChanged: (v) => setNotificationsSilent(ref, v),
            secondary: Icon(
              silent ? Icons.volume_off_outlined : Icons.volume_up_outlined,
              color: t.textMuted,
            ),
            title: const Text('Silent', style: TextStyle(fontSize: 14)),
            subtitle: Text(
              silent
                  ? 'Shown quietly, no sound or vibration'
                  : 'Plays a sound and vibrates',
              style: AppTokens.mono(size: 10, color: t.textFaint),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 14),
          ),
        if (enabled && blocked)
          _PermissionNotice(
            permanentlyDenied: permission.maybeWhen(
              data: (p) => p == NotificationPermission.permanentlyDenied,
              orElse: () => false,
            ),
            onFix: () async {
              final state = permission.valueOrNull;
              if (state == NotificationPermission.permanentlyDenied) {
                await NotificationService.instance.openSettings();
              } else {
                await NotificationService.instance.request();
              }
              ref.invalidate(notificationPermissionProvider);
            },
          ),
      ],
    );
  }
}

class _PermissionNotice extends StatelessWidget {
  const _PermissionNotice({
    required this.permanentlyDenied,
    required this.onFix,
  });

  final bool permanentlyDenied;
  final VoidCallback onFix;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 4, 14, 14),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: t.fill,
          borderRadius: BorderRadius.circular(Radii.control),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.info_outline_rounded, size: 18, color: t.textMuted),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    permanentlyDenied
                        ? 'Your device is blocking notifications for Notably. '
                            'Turn them on in system settings.'
                        : 'Notifications are switched on here, but the system '
                            'has not allowed them yet.',
                    style: TextStyle(
                      fontSize: 12,
                      height: 1.4,
                      color: t.textMuted,
                    ),
                  ),
                  const SizedBox(height: 6),
                  TextButton(
                    onPressed: onFix,
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.zero,
                      minimumSize: const Size(0, 32),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: Text(
                      permanentlyDenied ? 'Open settings' : 'Allow',
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
