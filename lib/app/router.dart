import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/admin/admin_console_gate.dart';
import '../features/admin/admin_section.dart';
import '../features/auth/data/auth_repository.dart';
import '../features/auth/providers.dart';
import '../features/auth/sign_in_screen.dart';
import '../features/editor/editor_screen.dart';
import '../features/library/library_screen.dart';
import '../features/library/trash_screen.dart';
import '../features/settings/billing_history_screen.dart';
import '../features/settings/global_quiz_history_page.dart';
import '../features/settings/settings_screen.dart';
import 'admin_route.dart';
import 'supabase_bootstrap.dart';
import 'page_routes.dart';

/// Top-level app routing, including the auth gate that keeps an
/// unauthenticated user on the sign-in screen when Supabase is configured.
///
/// Admin routes (`/admin/...`) bypass the main sign-in gate so
/// [AdminConsoleGate] can show the staff sign-in screen instead.
final routerProvider = Provider<GoRouter>((ref) {
  final user = ValueNotifier<AppUser?>(
    ref.read(authStateProvider).asData?.value,
  );
  ref.onDispose(user.dispose);

  ref.listen<AsyncValue<AppUser?>>(authStateProvider, (_, next) {
    user.value = next.asData?.value;
  });

  return GoRouter(
    initialLocation: '/',
    refreshListenable: user,
    redirect: (context, state) {
      if (!supabaseReady) return null;

      final loc = state.matchedLocation;
      final signedIn = user.value != null;
      final admin = isAdminRoute(state);

      if (!signedIn) {
        if (admin) return null;
        return loc == '/sign-in' ? null : '/sign-in';
      }

      if (loc == '/sign-in') {
        final next = state.uri.queryParameters['next'];
        if (next != null && next.startsWith('/admin')) return next;
        return '/';
      }

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
      GoRoute(
        path: '/quiz-history',
        pageBuilder: (context, state) => notablyPage(
          key: state.pageKey,
          child: const GlobalQuizHistoryPage(),
        ),
      ),
      GoRoute(
        path: '/billing-history',
        pageBuilder: (context, state) => notablyPage(
          key: state.pageKey,
          child: const BillingHistoryScreen(),
        ),
      ),
      GoRoute(
        path: '/admin',
        redirect: (context, state) => AdminSection.overview.location,
      ),
      for (final section in AdminSection.values)
        GoRoute(
          path: section.location,
          pageBuilder: (context, state) => notablyPage(
            key: state.pageKey,
            child: AdminConsoleGate(section: section),
          ),
        ),
    ],
    errorBuilder: (context, state) {
      // Deep-link `/admin` variants that missed a child segment.
      if (isAdminRoute(state)) {
        return AdminConsoleGate(section: AdminSection.overview);
      }
      return Scaffold(
        body: Center(child: Text('Route error: ${state.error}')),
      );
    },
  );
});
