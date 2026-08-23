import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../../app/supabase_bootstrap.dart';
import 'admin_auth_providers.dart';
import 'admin_supabase.dart';

class AdminAccessState {
  const AdminAccessState({
    required this.isAdmin,
    this.error,
  });

  final bool isAdmin;
  final String? error;
}

/// True when the *admin* session user is in `public.admins`.
///
/// Queried over PostgREST with the staff token rather than through a Supabase
/// client, for the same reason the session is: a second client would rejoin
/// gotrue's broadcast channel and hand the app its session.
final adminAccessStateProvider = FutureProvider<AdminAccessState>((ref) async {
  final user = ref.watch(adminAuthStateProvider).asData?.value;
  if (user == null || !adminSupabaseReady) {
    return const AdminAccessState(isAdmin: false);
  }

  final token = await adminAccessToken();
  if (token == null) {
    return const AdminAccessState(
      isAdmin: false,
      error: 'Staff session expired — sign in again.',
    );
  }

  final rest = '${kSupabaseUrl.replaceAll(RegExp(r'/+$'), '')}/rest/v1';
  final headers = {
    'apikey': kSupabaseAnonKey,
    'Authorization': 'Bearer $token',
    'Content-Type': 'application/json',
  };

  try {
    // Preferred: the security-definer helper, which answers without the
    // caller needing to read the table (and without tripping RLS recursion).
    try {
      final rpc = await http.post(
        Uri.parse('$rest/rpc/is_admin'),
        headers: headers,
        body: '{}',
      );
      if (rpc.statusCode < 300 && jsonDecode(rpc.body) == true) {
        return const AdminAccessState(isAdmin: true);
      }
    } catch (e) {
      debugPrint('is_admin rpc unavailable, falling back to table: $e');
    }

    final res = await http.get(
      Uri.parse(
        '$rest/admins'
        '?user_id=eq.${Uri.encodeQueryComponent(user.uid)}'
        '&select=user_id,role',
      ),
      headers: headers,
    );
    if (res.statusCode >= 300) {
      return AdminAccessState(
        isAdmin: false,
        error: 'admins lookup failed (${res.statusCode}): ${res.body}',
      );
    }
    final rows = jsonDecode(res.body) as List;
    if (rows.isNotEmpty) return const AdminAccessState(isAdmin: true);

    return AdminAccessState(
      isAdmin: false,
      error: 'No public.admins row for ${user.uid}',
    );
  } catch (e) {
    debugPrint('Admin check failed: $e');
    return AdminAccessState(isAdmin: false, error: '$e');
  }
});

/// Staff console access for the separate admin Auth session.
final isAdminProvider = Provider<bool>((ref) {
  final uid = ref.watch(adminAuthStateProvider).asData?.value?.uid;
  if (uid == null) return false;
  return ref.watch(adminAccessStateProvider).asData?.value.isAdmin ?? false;
});
