import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app/app.dart';
import 'app/firebase_bootstrap.dart';
import 'app/providers.dart';
import 'features/library/providers.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Never fatal: if Firebase isn't configured the app runs local-only.
  await initFirebase();

  final prefs = await SharedPreferences.getInstance();

  final container = ProviderContainer(
    overrides: [sharedPrefsProvider.overrideWithValue(prefs)],
  );

  // Assets used to be base64 inside SQLite; move any legacy rows onto disk so
  // large PDFs stop bloating the database. Cheap no-op once done.
  unawaited(
    container
        .read(assetRepositoryProvider)
        .migrateInlineAssetsToDisk()
        .then((moved) {
      if (moved > 0) debugPrint('Moved $moved asset(s) out of the database');
    }).catchError((Object e) {
      debugPrint('Asset migration skipped: $e');
    }),
  );

  runApp(
    UncontrolledProviderScope(
      container: container,
      child: const NotablyApp(),
    ),
  );
}
