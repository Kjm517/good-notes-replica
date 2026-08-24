import 'dart:js_interop';

import 'package:web/web.dart' as web;

extension type _PwaBridge._(JSObject _) implements JSObject {
  external JSObject? get prompt;
  external set prompt(JSObject? value);
  external bool get installed;
}

extension type _BeforeInstallPrompt(JSObject _) implements JSObject {
  external JSPromise<JSAny?> prompt();
}

@JS('_notablyPwa')
external _PwaBridge? get _notablyPwa;

bool pwaIsStandalone() {
  try {
    if (web.window.matchMedia('(display-mode: standalone)').matches) {
      return true;
    }
  } catch (_) {}
  return _notablyPwa?.installed == true;
}

bool pwaInstallAvailable() {
  if (pwaIsStandalone()) return false;
  return _notablyPwa?.prompt != null;
}

Future<bool> promptPwaInstall() async {
  final bridge = _notablyPwa;
  final raw = bridge?.prompt;
  if (raw == null) return false;
  final event = _BeforeInstallPrompt(raw);
  try {
    await event.prompt().toDart;
    bridge?.prompt = null;
    return true;
  } catch (_) {
    return false;
  }
}
