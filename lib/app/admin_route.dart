import 'package:go_router/go_router.dart';

/// True when navigation targets the staff admin console.
bool isAdminRoute(GoRouterState state) {
  final loc = state.matchedLocation;
  if (loc.startsWith('/admin')) return true;
  final fullPath = state.fullPath;
  if (fullPath != null && fullPath.startsWith('/admin')) return true;
  final path = state.uri.path;
  if (path.startsWith('/admin')) return true;
  // Hash URLs on web: `localhost:50703/admin#/sign-in` — path is still /admin.
  if (path == '/admin' || path.startsWith('/admin/')) return true;
  return false;
}
