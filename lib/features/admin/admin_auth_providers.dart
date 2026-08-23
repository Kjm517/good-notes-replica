import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/data/auth_repository.dart' show AppUser;
import 'admin_supabase.dart';

/// Staff Auth — independent of the end-user [authRepositoryProvider] session.
///
/// Backed by [AdminAuth] rather than a second Supabase client: see the note in
/// `admin_supabase.dart` for why a second client cannot stay separate on web.
final adminAuthRepositoryProvider = Provider<AdminAuth?>((ref) {
  if (!adminSupabaseReady) return null;
  return adminAuth;
});

final adminAuthStateProvider = StreamProvider<AppUser?>((ref) {
  final auth = ref.watch(adminAuthRepositoryProvider);
  if (auth == null) return Stream.value(null);
  return auth.authStateChanges();
});
