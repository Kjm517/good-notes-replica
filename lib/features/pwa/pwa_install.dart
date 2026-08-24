import 'pwa_install_stub.dart'
    if (dart.library.js_interop) 'pwa_install_web.dart' as impl;

/// True when the web app is already running as an installed PWA.
bool pwaIsStandalone() => impl.pwaIsStandalone();

/// True when Chrome has a deferred install prompt we can fire.
bool pwaInstallAvailable() => impl.pwaInstallAvailable();

/// Shows the browser install dialog. Returns false if the user dismissed it
/// or the browser has no prompt (Safari: use the share sheet instead).
Future<bool> promptPwaInstall() => impl.promptPwaInstall();
