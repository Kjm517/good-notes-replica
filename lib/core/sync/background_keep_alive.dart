import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Asks the OS to let network work continue after the user leaves the app.
///
/// Android shows a "Syncing…" notification (data-sync foreground service).
/// iOS takes a background-task budget and uses a background URLSession for
/// file downloads. Swiping the app away still stops Dart, but switching to
/// another app no longer freezes a textbook mid-transfer.
///
/// Native start/stop is wired from [NotablyApp] so unit tests never touch
/// the Flutter binding.
class BackgroundKeepAlive {
  BackgroundKeepAlive._();

  static const channel = MethodChannel('notably/keep_alive');
  static int _holds = 0;

  /// Set from the running app. Null in tests.
  static Future<void> Function()? nativeStart;
  static Future<void> Function()? nativeStop;

  static Future<void> acquire() async {
    _holds++;
    if (_holds != 1) return;
    try {
      await nativeStart?.call();
    } catch (e) {
      debugPrint('Keep-alive start failed: $e');
    }
  }

  static Future<void> release() async {
    if (_holds == 0) return;
    _holds--;
    if (_holds != 0) return;
    try {
      await nativeStop?.call();
    } catch (e) {
      debugPrint('Keep-alive stop failed: $e');
    }
  }

  /// Called once at app startup.
  static void bindNative() {
    nativeStart = () async {
      await channel.invokeMethod<void>('start');
    };
    nativeStop = () async {
      await channel.invokeMethod<void>('stop');
    };
  }
}
