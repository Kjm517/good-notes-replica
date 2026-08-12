import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/firebase_bootstrap.dart';
import 'data/auth_repository.dart';

/// Null when Firebase isn't configured, so the UI can say so instead of
/// throwing when someone taps "Sign in".
final authRepositoryProvider = Provider<AuthRepository?>((ref) {
  if (!firebaseReady) return null;
  return AuthRepository();
});

/// The signed-in user, or null. Stays null in local-only mode.
final authStateProvider = StreamProvider<AppUser?>((ref) {
  final repo = ref.watch(authRepositoryProvider);
  if (repo == null) return Stream.value(null);
  return repo.authStateChanges();
});

/// Convenience: is someone signed in right now?
final isSignedInProvider = Provider<bool>((ref) {
  return ref.watch(authStateProvider).asData?.value != null;
});
