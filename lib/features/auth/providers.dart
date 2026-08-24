import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../app/supabase_bootstrap.dart';
import 'data/auth_repository.dart';

/// Null when Supabase isn't configured, so the UI can say so instead of
/// throwing when someone taps "Sign in".
final authRepositoryProvider = Provider<AuthRepository?>((ref) {
  if (!supabaseReady) return null;
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

/// Preference key for "keep me signed in". Read directly in `main` too, before
/// any provider exists, to end a session the user asked not to keep.
const keepSignedInKey = 'keep_signed_in';

/// Whether a session should outlive closing the app. Defaults to on.
final keepSignedInProvider =
    NotifierProvider<KeepSignedInController, bool>(KeepSignedInController.new);

class KeepSignedInController extends Notifier<bool> {
  @override
  bool build() =>
      ref.watch(sharedPrefsProvider).getBool(keepSignedInKey) ?? true;

  Future<void> set(bool value) async {
    state = value;
    await ref.read(sharedPrefsProvider).setBool(keepSignedInKey, value);
  }
}
