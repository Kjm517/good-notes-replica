import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app/app.dart';
import 'app/crash_guard.dart';
import 'app/firebase_bootstrap.dart';
import 'app/providers.dart';
import 'features/auth/providers.dart';
import 'features/library/providers.dart';

void main() => runGuarded(bootstrap);

/// Prepares everything the widget tree needs and returns the app root.
///
/// Every step here is either non-fatal or reported: the only thing the app
/// truly cannot start without is SharedPreferences, and if that fails the guard
/// shows why rather than letting the process vanish.
Future<Widget> bootstrap() async {
  // Never fatal: if Firebase isn't configured the app runs local-only.
  await initFirebase();

  final prefs = await SharedPreferences.getInstance();

  final container = ProviderContainer(
    overrides: [sharedPrefsProvider.overrideWithValue(prefs)],
  );

  // "Keep me signed in" was turned off, so a cold start must not resume the
  // session. Web enforces this with session-scoped persistence; the mobile SDKs
  // always persist a login, so the only way to honour the choice is to end the
  // restored session before the router can route anyone home.
  if (!kIsWeb && !(prefs.getBool(keepSignedInKey) ?? true)) {
    try {
      await container.read(authRepositoryProvider)?.signOut();
    } catch (e) {
      debugPrint('Could not end the previous session: $e');
    }
  }

  unawaited(_migrateLegacyAssets(container));

  return UncontrolledProviderScope(
    container: container,
    child: const NotablyApp(),
  );
}

/// Assets used to be base64 inside SQLite; move any legacy rows onto disk so
/// large PDFs stop bloating the database. Cheap no-op once done.
///
/// Reading the repository can itself throw (it opens the database), so the whole
/// call sits inside the try — a device that cannot run the migration should
/// still get an app.
Future<void> _migrateLegacyAssets(ProviderContainer container) async {
  try {
    final moved = await container
        .read(assetRepositoryProvider)
        .migrateInlineAssetsToDisk();
    if (moved > 0) debugPrint('Moved $moved asset(s) out of the database');
  } catch (e) {
    debugPrint('Asset migration skipped: $e');
  }
}
