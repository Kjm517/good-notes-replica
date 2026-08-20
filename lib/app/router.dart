import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/auth/data/auth_repository.dart';
import '../features/auth/providers.dart';
import '../features/auth/sign_in_screen.dart';
import '../features/editor/editor_screen.dart';
import '../features/library/library_screen.dart';
import '../features/library/trash_screen.dart';
import '../features/settings/settings_screen.dart';
import 'firebase_bootstrap.dart';
import 'page_routes.dart';

/// Top-level app routing, including the auth gate that keeps an
/// unauthenticated user on the sign-in screen when Firebase is configured.
///
/// The gate reads the current user through a plain [ValueNotifier] fed from
/// `ref.listen` (rather than rebuilding the router on every auth tick), so the
/// navigation stack stays intact while sign-in/out re-runs the redirect on its
/// own — no imperative navigation.
final routerProvider = Provider<GoRouter>((ref) {
  // The router is only built once auth has resolved (see NotablyApp), so the
  // seed here already reflects the restored session.
  final user = ValueNotifier<AppUser?>(
    ref.read(authStateProvider).asData?.value,
  );
  ref.onDispose(user.dispose);

  ref.listen<AsyncValue<AppUser?>>(authStateProvider, (_, next) {
    user.value = next.asData?.value;
  });

  return GoRouter(
    // The redirect below funnels unsigned users to the gate; nothing to
    // pre-load here because the router doesn't exist until auth resolves.
    initialLocation: '/',
    refreshListenable: user,
    redirect: (context, state) {
      // Local-only mode: no backend to sign into, no gate — stay put.
      if (!firebaseReady) return null;

      final loc = state.matchedLocation;
      final signedIn = user.value != null;

      if (!signedIn) {
        // Unsigned users funnel to the gate; once on it, stop redirecting so
        // the form can render.
        return loc == '/sign-in' ? null : '/sign-in';
      }

      // A signed-in user should never be stranded on the gate screen.
      if (loc == '/sign-in') return '/';

      return null;
    },
    routes: [
      GoRoute(
        path: '/sign-in',
        pageBuilder: (context, state) => notablyPage(
          key: state.pageKey,
          fullscreenDialog: true,
          child: const SignInScreen(),
        ),
      ),
      GoRoute(
        path: '/',
        pageBuilder: (context, state) => notablyPage(
          key: state.pageKey,
          child: const LibraryScreen(parentId: null),
        ),
      ),
      GoRoute(
        path: '/folder/:id',
        pageBuilder: (context, state) => notablyPage(
          key: state.pageKey,
          child: LibraryScreen(parentId: state.pathParameters['id']),
        ),
      ),
      GoRoute(
        path: '/doc/:id',
        pageBuilder: (context, state) => notablyPage(
          key: state.pageKey,
          child: EditorScreen(documentId: state.pathParameters['id']!),
        ),
      ),
      GoRoute(
        path: '/trash',
        pageBuilder: (context, state) => notablyPage(
          key: state.pageKey,
          child: const TrashScreen(),
        ),
      ),
      GoRoute(
        path: '/settings',
        pageBuilder: (context, state) => notablyPage(
          key: state.pageKey,
          child: const SettingsScreen(),
        ),
      ),
    ],
    errorBuilder: (context, state) => Scaffold(
      body: Center(child: Text('Route error: ${state.error}')),
    ),
  );
});
