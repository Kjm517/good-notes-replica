import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

bool get notablyIsCupertino =>
    !kIsWeb &&
    (defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.macOS);

/// Back chevron on iOS/macOS, Material arrow elsewhere.
IconData get notablyBackIcon => notablyIsCupertino
    ? Icons.arrow_back_ios_new_rounded
    : Icons.arrow_back_rounded;

/// iOS edge-swipe (and Android predictive back) for pushed screens.
Route<T> notablyRoute<T extends Object?>({
  required WidgetBuilder builder,
  bool fullscreenDialog = false,
}) {
  if (notablyIsCupertino) {
    return CupertinoPageRoute<T>(
      builder: builder,
      fullscreenDialog: fullscreenDialog,
    );
  }
  return MaterialPageRoute<T>(
    builder: builder,
    fullscreenDialog: fullscreenDialog,
  );
}

/// go_router page that uses Cupertino on iOS so swipe-back matches Android back.
Page<void> notablyPage({
  required LocalKey key,
  required Widget child,
  bool fullscreenDialog = false,
}) {
  if (kIsWeb) {
    return NoTransitionPage<void>(key: key, child: child);
  }
  if (notablyIsCupertino) {
    return CupertinoPage<void>(
      key: key,
      child: child,
      fullscreenDialog: fullscreenDialog,
    );
  }
  return MaterialPage<void>(
    key: key,
    child: child,
    fullscreenDialog: fullscreenDialog,
  );
}
