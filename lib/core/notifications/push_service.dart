import 'dart:async';
import 'dart:convert';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'notification_service.dart';

/// FCM registration and foreground display.
///
/// Every entry point is guarded: the app must keep working with no Firebase
/// config at all, since the config files are added per-platform and web has
/// none. A missing google-services.json degrades push to "off", never to a
/// crash on launch.
class PushService {
  PushService._();

  static final PushService instance = PushService._();

  var _started = false;
  String? _token;
  StreamSubscription<RemoteMessage>? _foregroundSub;
  StreamSubscription<String>? _refreshSub;

  /// Last token handed to us by FCM, or null if registration never succeeded.
  String? get token => _token;

  bool get supported =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  String get platform =>
      defaultTargetPlatform == TargetPlatform.iOS ? 'ios' : 'android';

  /// Initializes Firebase and starts listening. Returns false when push is
  /// unavailable for any reason — no config, no permission, unsupported host.
  Future<bool> start({
    required Future<String?> Function() accessToken,
    required String endpoint,
    required bool Function() silent,
  }) async {
    if (_started || !supported) return false;

    try {
      await Firebase.initializeApp();
    } catch (e) {
      // Almost always a missing google-services.json / GoogleService-Info.plist.
      debugPrint('Push disabled — Firebase not configured: $e');
      return false;
    }

    try {
      final messaging = FirebaseMessaging.instance;

      // Only ask iOS for the APNs alert permission if the user has already
      // opted in locally; NotificationService owns the prompt.
      final permission = await NotificationService.instance.status();
      if (permission != NotificationPermission.granted) return false;

      _token = await messaging.getToken();
      if (_token != null) {
        await _register(_token!, accessToken, endpoint);
      }

      _refreshSub = messaging.onTokenRefresh.listen((fresh) {
        _token = fresh;
        unawaited(_register(fresh, accessToken, endpoint));
      });

      // Android shows nothing for a data/notification message while the app is
      // foregrounded, so mirror it through the local plugin. Background and
      // terminated states are handled by the OS itself.
      _foregroundSub = FirebaseMessaging.onMessage.listen((message) {
        final n = message.notification;
        if (n == null) return;
        unawaited(
          NotificationService.instance.show(
            id: message.messageId.hashCode,
            title: n.title ?? 'Notably',
            body: n.body ?? '',
            silent: silent(),
          ),
        );
      });

      _started = true;
      return true;
    } catch (e) {
      debugPrint('Push start failed: $e');
      return false;
    }
  }

  Future<void> _register(
    String token,
    Future<String?> Function() accessToken,
    String endpoint,
  ) async {
    if (endpoint.trim().isEmpty) return;
    try {
      final jwt = await accessToken();
      if (jwt == null || jwt.isEmpty) return;
      await http.post(
        Uri.parse('$endpoint/user/devices'),
        headers: {
          'Authorization': 'Bearer $jwt',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'token': token, 'platform': platform}),
      );
    } catch (e) {
      // A failed registration just means no push until next launch.
      debugPrint('Device token registration failed: $e');
    }
  }

  /// Unregisters this device — call on sign-out so a shared phone stops
  /// receiving the previous account's notifications.
  Future<void> unregister({
    required Future<String?> Function() accessToken,
    required String endpoint,
  }) async {
    final token = _token;
    if (token == null || endpoint.trim().isEmpty) return;
    try {
      final jwt = await accessToken();
      if (jwt == null || jwt.isEmpty) return;
      await http.delete(
        Uri.parse('$endpoint/user/devices'),
        headers: {
          'Authorization': 'Bearer $jwt',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'token': token}),
      );
    } catch (e) {
      debugPrint('Device token removal failed: $e');
    }
  }

  Future<void> stop() async {
    await _foregroundSub?.cancel();
    await _refreshSub?.cancel();
    _foregroundSub = null;
    _refreshSub = null;
    _started = false;
  }
}
