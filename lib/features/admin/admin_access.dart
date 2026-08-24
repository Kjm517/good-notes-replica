import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../../app/supabase_bootstrap.dart';
import '../../core/sync/sync_providers.dart';
import 'admin_auth_providers.dart';
import 'admin_supabase.dart';

class AdminAccessState {
  const AdminAccessState({
    required this.isAdmin,
    this.canWrite = false,
    this.role,
    this.error,
  });

  /// May open the console (admin or viewer).
  final bool isAdmin;

  /// May mutate users, vouchers, team, bugs.
  final bool canWrite;
  final String? role;
  final String? error;
}

/// True when the *admin* session user is staff (`public.admins`).
///
/// Queried over the Worker first (`/admin/me`), then PostgREST.
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

  final endpoint = kFileEndpoint.trim();
  if (endpoint.isNotEmpty) {
    try {
      final me = await http.get(
        Uri.parse('$endpoint/admin/me'),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );
      if (me.statusCode < 300) {
        final body = jsonDecode(me.body);
        if (body is Map<String, dynamic>) {
          final staff = body['admin'] as bool? ?? false;
          final role = body['role'] as String?;
          return AdminAccessState(
            isAdmin: staff,
            canWrite: body['canWrite'] as bool? ?? role == 'admin',
            role: role,
            error: staff ? null : 'No public.admins row for ${user.uid}',
          );
        }
      }
    } catch (e) {
      debugPrint('admin/me lookup failed: $e');
    }
  }

  final rest = '${kSupabaseUrl.replaceAll(RegExp(r'/+$'), '')}/rest/v1';
  final headers = {
    'apikey': kSupabaseAnonKey,
    'Authorization': 'Bearer $token',
    'Content-Type': 'application/json',
  };

  try {
    try {
      final rpc = await http.post(
        Uri.parse('$rest/rpc/is_staff'),
        headers: headers,
        body: '{}',
      );
      if (rpc.statusCode < 300 && jsonDecode(rpc.body) == true) {
        // Staff, but role (admin vs viewer) still lives on the row.
      }
    } catch (e) {
      debugPrint('is_staff rpc unavailable: $e');
    }

    try {
      final rpc = await http.post(
        Uri.parse('$rest/rpc/is_admin'),
        headers: headers,
        body: '{}',
      );
      if (rpc.statusCode < 300 && jsonDecode(rpc.body) == true) {
        return const AdminAccessState(
          isAdmin: true,
          canWrite: true,
          role: 'admin',
        );
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
    if (rows.isNotEmpty) {
      final role = (rows.first as Map)['role'] as String? ?? 'admin';
      return AdminAccessState(
        isAdmin: true,
        canWrite: role == 'admin',
        role: role,
      );
    }

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

final adminCanWriteProvider = Provider<bool>((ref) {
  if (!ref.watch(isAdminProvider)) return false;
  return ref.watch(adminAccessStateProvider).asData?.value.canWrite ?? false;
});
