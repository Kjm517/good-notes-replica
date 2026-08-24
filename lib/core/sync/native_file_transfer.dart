import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// iOS background URLSession downloads. Android keeps using Dart HTTP behind
/// the keep-alive service — OkHttp already continues while the isolate lives.
class NativeFileTransfer {
  NativeFileTransfer._();

  static const _channel = MethodChannel('notably/file_transfer');
  static const _events = EventChannel('notably/file_transfer/events');

  static bool get isSupported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;

  /// Downloads [url] to [destPath]. Returns false if the plugin is missing
  /// or the server rejected the request.
  static Future<bool> download({
    required String url,
    required Map<String, String> headers,
    required String destPath,
    void Function(double fraction)? onProgress,
  }) async {
    if (!isSupported) return false;
    StreamSubscription<dynamic>? sub;
    try {
      sub = _events.receiveBroadcastStream().listen((event) {
        if (event is! Map) return;
        final fraction = event['progress'];
        if (fraction is num) onProgress?.call(fraction.toDouble().clamp(0, 1));
      });
      final ok = await _channel.invokeMethod<bool>('download', {
        'url': url,
        'headers': headers,
        'destPath': destPath,
      });
      return ok == true;
    } on MissingPluginException {
      return false;
    } on PlatformException catch (e) {
      debugPrint('Native download failed: ${e.message}');
      return false;
    } finally {
      await sub?.cancel();
    }
  }
}
