import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

/// Android channel for anything the server or a schedule pushes at the user.
const _channel = AndroidNotificationChannel(
  'notably_general',
  'Notably',
  description: 'Plan reminders and announcements.',
  importance: Importance.defaultImportance,
);

/// Where a notification permission request ended up.
enum NotificationPermission {
  /// Allowed to post.
  granted,

  /// Refused, but asking again is still possible.
  denied,

  /// Refused for good — only the OS settings screen can change it now.
  permanentlyDenied,

  /// Desktop/web, where there is nothing to ask for.
  unsupported,
}

/// Local notification display and OS permission state.
///
/// Deliberately separate from any push transport: FCM decides *when* a message
/// arrives, this decides whether and how it is shown. Keeping them apart means
/// scheduled reminders work with no server involved.
class NotificationService {
  NotificationService._();

  static final NotificationService instance = NotificationService._();

  final _plugin = FlutterLocalNotificationsPlugin();
  var _ready = false;
  var _timezoneReady = false;

  /// Whether the platform can show notifications at all.
  bool get supported =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  /// Safe to call more than once; later calls are no-ops.
  Future<void> init() async {
    if (_ready || !supported) return;

    const settings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      // Permission is requested explicitly later, not at init: asking on first
      // launch, before the user knows what the app does, is how people end up
      // permanently denying it.
      iOS: DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      ),
    );

    try {
      await _initTimezone();
      await _plugin.initialize(settings: settings);
      await _plugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(_channel);
      _ready = true;
    } catch (e) {
      debugPrint('Notifications unavailable: $e');
    }
  }

  /// Scheduling needs a real local zone; the timezone package defaults to UTC,
  /// which would fire reminders hours off for anyone outside it.
  Future<void> _initTimezone() async {
    if (_timezoneReady) return;
    try {
      tzdata.initializeTimeZones();
      final name = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(name.identifier));
      _timezoneReady = true;
    } catch (e) {
      // Falls back to UTC. Reminders still fire, just less precisely.
      debugPrint('Timezone lookup failed, scheduling in UTC: $e');
    }
  }

  /// Posts [title]/[body] at [when], surviving app restarts and reboots.
  ///
  /// A time already past is dropped rather than fired immediately — a reminder
  /// that arrives late is worse than none.
  Future<void> scheduleAt({
    required int id,
    required DateTime when,
    required String title,
    required String body,
    bool silent = false,
  }) async {
    if (!supported) return;
    await init();
    if (!_ready) return;
    if (!when.isAfter(DateTime.now())) return;

    try {
      await _plugin.zonedSchedule(
        id: id,
        title: title,
        body: body,
        scheduledDate: tz.TZDateTime.from(when, tz.local),
        notificationDetails: _details(silent: silent),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      );
    } catch (e) {
      debugPrint('Notification schedule failed: $e');
    }
  }

  NotificationDetails _details({required bool silent}) {
    return NotificationDetails(
      android: AndroidNotificationDetails(
        _channel.id,
        _channel.name,
        channelDescription: _channel.description,
        importance: silent ? Importance.low : Importance.defaultImportance,
        priority: silent ? Priority.low : Priority.defaultPriority,
        playSound: !silent,
        enableVibration: !silent,
      ),
      iOS: DarwinNotificationDetails(
        presentSound: !silent,
        presentAlert: true,
        presentBadge: true,
      ),
    );
  }

  /// Current permission state without prompting.
  Future<NotificationPermission> status() async {
    if (!supported) return NotificationPermission.unsupported;
    final status = await Permission.notification.status;
    return _map(status);
  }

  /// Prompts if the OS still allows it.
  Future<NotificationPermission> request() async {
    if (!supported) return NotificationPermission.unsupported;
    await init();
    final status = await Permission.notification.request();
    return _map(status);
  }

  /// Opens the OS settings page — the only route once permanently denied.
  Future<void> openSettings() => openAppSettings();

  /// Shows a notification now. Silent posts drop sound and vibration but still
  /// appear in the tray, which is what the in-app "silent" toggle selects.
  Future<void> show({
    required int id,
    required String title,
    required String body,
    bool silent = false,
  }) async {
    if (!supported) return;
    await init();
    if (!_ready) return;

    final details = _details(silent: silent);

    try {
      await _plugin.show(
        id: id,
        title: title,
        body: body,
        notificationDetails: details,
      );
    } catch (e) {
      debugPrint('Notification show failed: $e');
    }
  }

  Future<void> cancel(int id) async {
    if (!supported) return;
    try {
      await _plugin.cancel(id: id);
    } catch (_) {
      // Cancelling something that was never posted is not an error.
    }
  }

  Future<void> cancelAll() async {
    if (!supported) return;
    try {
      await _plugin.cancelAll();
    } catch (_) {}
  }

  NotificationPermission _map(PermissionStatus status) {
    if (status.isGranted || status.isLimited || status.isProvisional) {
      return NotificationPermission.granted;
    }
    if (status.isPermanentlyDenied) {
      return NotificationPermission.permanentlyDenied;
    }
    return NotificationPermission.denied;
  }
}
