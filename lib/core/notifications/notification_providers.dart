import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../app/supabase_bootstrap.dart';
import '../sync/sync_providers.dart';
import 'notification_service.dart';
import 'push_service.dart';

const _enabledKey = 'notifications_enabled';
const _silentKey = 'notifications_silent';

/// User's in-app switch. Independent of the OS permission: someone can grant
/// permission and still turn notifications off here, and we must not post if
/// either says no.
final notificationsEnabledProvider = StateProvider<bool>((ref) {
  return ref.watch(sharedPrefsProvider).getBool(_enabledKey) ?? true;
});

/// Post without sound or vibration. The notification still appears.
final notificationsSilentProvider = StateProvider<bool>((ref) {
  return ref.watch(sharedPrefsProvider).getBool(_silentKey) ?? false;
});

/// OS-level permission, re-read whenever something asks for it.
final notificationPermissionProvider =
    FutureProvider<NotificationPermission>((ref) async {
  return NotificationService.instance.status();
});

Future<void> setNotificationsEnabled(WidgetRef ref, bool enabled) async {
  await ref.read(sharedPrefsProvider).setBool(_enabledKey, enabled);
  ref.read(notificationsEnabledProvider.notifier).state = enabled;

  if (enabled) {
    // Turning the switch on is the moment the prompt makes sense — the user
    // has just said what they want.
    await NotificationService.instance.request();
    ref.invalidate(notificationPermissionProvider);
  } else {
    await NotificationService.instance.cancelAll();
  }
}

Future<void> setNotificationsSilent(WidgetRef ref, bool silent) async {
  await ref.read(sharedPrefsProvider).setBool(_silentKey, silent);
  ref.read(notificationsSilentProvider.notifier).state = silent;
}

/// Starts FCM once the user has both switched notifications on and granted
/// the OS permission. Safe to watch unconditionally — it no-ops when push is
/// unavailable, which includes web and any build without Firebase config.
final pushRegistrationProvider = Provider<void>((ref) {
  if (!ref.watch(notificationsEnabledProvider)) return;
  final allowed = ref.watch(notificationPermissionProvider).maybeWhen(
        data: (p) => p == NotificationPermission.granted,
        orElse: () => false,
      );
  if (!allowed) return;

  unawaited(
    PushService.instance.start(
      accessToken: supabaseAccessToken,
      endpoint: kFileEndpoint,
      silent: () => ref.read(notificationsSilentProvider),
    ),
  );
});

/// Whether a notification may actually be posted right now — both the user's
/// switch and the OS must agree.
final canNotifyProvider = Provider<bool>((ref) {
  if (!ref.watch(notificationsEnabledProvider)) return false;
  return ref.watch(notificationPermissionProvider).maybeWhen(
        data: (p) => p == NotificationPermission.granted,
        orElse: () => false,
      );
});
