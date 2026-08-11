import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../features/editor/editor_screen.dart';
import '../features/library/library_screen.dart';
import '../features/library/trash_screen.dart';
import '../features/settings/settings_screen.dart';

/// App routes.
final appRouter = GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(
      path: '/',
      builder: (context, state) => const LibraryScreen(parentId: null),
    ),
    GoRoute(
      path: '/folder/:id',
      builder: (context, state) =>
          LibraryScreen(parentId: state.pathParameters['id']),
    ),
    GoRoute(
      path: '/doc/:id',
      builder: (context, state) =>
          EditorScreen(documentId: state.pathParameters['id']!),
    ),
    GoRoute(
      path: '/trash',
      builder: (context, state) => const TrashScreen(),
    ),
    GoRoute(
      path: '/settings',
      builder: (context, state) => const SettingsScreen(),
    ),
  ],
  errorBuilder: (context, state) => Scaffold(
    body: Center(child: Text('Route error: ${state.error}')),
  ),
);
