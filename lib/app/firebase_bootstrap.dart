import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

import '../firebase_options.dart';

/// Whether Firebase started successfully this run.
///
/// The app is deliberately usable without it: notes are stored locally, and
/// sign-in/sync simply stay unavailable. That keeps a missing, broken or
/// unreachable Firebase config from bricking the whole app.
bool get firebaseReady => _ready;
bool _ready = false;

/// Why Firebase is unavailable, shown in Settings and on the sign-in screen.
String? get firebaseError => _error;
String? _error;

Future<void> initFirebase() async {
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    _ready = true;
  } catch (e) {
    // Unsupported platform (e.g. Windows desktop), no network, or a config
    // that hasn't been generated yet — all non-fatal.
    _error = '$e';
    debugPrint('Firebase unavailable, running local-only: $e');
  }
}
