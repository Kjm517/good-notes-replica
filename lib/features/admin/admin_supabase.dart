import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../../app/supabase_bootstrap.dart';
import '../auth/data/auth_repository.dart' show AppUser, AuthFailure;

/// Staff Auth session for the admin console, deliberately **not** built on a
/// second [SupabaseClient].
///
/// A second client looks like the obvious way to hold a separate session, and
/// it is what this used to do — with its own persist key, so nothing was
/// shared on disk. It still leaked, because gotrue synchronises sessions
/// between clients over a web `BroadcastChannel` whose name comes from the
/// project URL alone:
///
/// ```dart
/// final broadcastKey = "sb-${Uri.parse(_url).host.split(".").first}-auth-token";
/// ```
///
/// Two clients against one project therefore share a channel no matter how
/// their storage is configured. Signing in on the admin client broadcast
/// `SIGNED_IN`, the app's client adopted the session, and the note-taking app
/// silently became logged in as the staff account. The channel is started
/// unconditionally in the `GoTrueClient` constructor, so there is nothing to
/// switch off.
///
/// So the admin session talks to the GoTrue REST API directly and keeps its
/// tokens in ordinary preferences. No second client, no channel, no bleed —
/// and signing out of one side leaves the other alone.
const kAdminPersistSessionKey = 'notably_admin_session';

/// Refresh this far before actual expiry, so a slow request cannot start with
/// a token that dies mid-flight.
const Duration _refreshSkew = Duration(seconds: 60);

AdminAuth? _adminAuth;
var _adminReady = false;

bool get adminSupabaseReady => _adminReady && supabaseReady;

/// The staff session. Throws if [initAdminSupabase] has not run.
AdminAuth get adminAuth {
  final auth = _adminAuth;
  if (auth == null) {
    throw StateError('Admin auth is not initialized.');
  }
  return auth;
}

Future<void> initAdminSupabase() async {
  if (!supabaseReady || _adminReady) return;
  try {
    final auth = AdminAuth(
      url: kSupabaseUrl,
      anonKey: kSupabaseAnonKey,
      prefs: await SharedPreferences.getInstance(),
    );
    await auth.restore();
    _adminAuth = auth;
    _adminReady = true;
  } catch (e) {
    debugPrint('Admin auth init failed: $e');
    _adminReady = false;
  }
}

/// Bearer token for admin Worker and PostgREST calls, refreshed if stale.
Future<String?> adminAccessToken() async {
  if (!_adminReady) return null;
  return _adminAuth?.accessToken();
}

Future<void> disposeAdminSupabase() async {
  await _adminAuth?.dispose();
  _adminAuth = null;
  _adminReady = false;
}

/// Email/password auth against GoTrue's REST API, with its own token storage.
class AdminAuth {
  AdminAuth({
    required String url,
    required this.anonKey,
    required SharedPreferences prefs,
    http.Client? client,
  })  : _authUrl = '${url.replaceAll(RegExp(r'/+$'), '')}/auth/v1',
        _prefs = prefs,
        _client = client ?? http.Client();

  final String _authUrl;
  final String anonKey;
  final SharedPreferences _prefs;
  final http.Client _client;

  final _users = StreamController<AppUser?>.broadcast();

  String? _accessToken;
  String? _refreshToken;
  DateTime? _expiresAt;
  AppUser? _user;

  AppUser? get currentUser => _user;

  /// Emits the current staff user immediately, then on every change — the
  /// same contract as the app's `authStateChanges`, so the gate can watch it
  /// without caring which implementation is underneath.
  Stream<AppUser?> authStateChanges() async* {
    yield _user;
    yield* _users.stream;
  }

  Map<String, String> get _headers => {
        'apikey': anonKey,
        'Content-Type': 'application/json',
      };

  /// Reloads a stored session. Tokens are refreshed lazily, so an expired one
  /// is still worth keeping: the refresh token usually outlives it by weeks.
  Future<void> restore() async {
    final raw = _prefs.getString(kAdminPersistSessionKey);
    if (raw == null || raw.isEmpty) return;
    try {
      _apply(jsonDecode(raw) as Map<String, dynamic>, persist: false);
    } catch (e) {
      debugPrint('Admin session restore failed: $e');
      await _prefs.remove(kAdminPersistSessionKey);
    }
  }

  Future<void> signInWithEmail(String email, String password) async {
    final response = await _post(
      'token?grant_type=password',
      {'email': email.trim(), 'password': password},
    );
    _apply(response, persist: true);
  }

  /// Kept for call-site parity with the app's repository. A staff session is
  /// always persisted: the console is a desktop tool, and being signed out by
  /// a page refresh mid-investigation helps nobody.
  Future<void> applyPersistence({required bool keepSignedIn}) async {}

  Future<void> signOut() async {
    final token = _accessToken;
    if (token != null) {
      // Best effort: the local session is cleared either way, so a failure
      // here must not leave the console stuck looking signed in.
      try {
        await _client.post(
          Uri.parse('$_authUrl/logout'),
          headers: {..._headers, 'Authorization': 'Bearer $token'},
        );
      } catch (e) {
        debugPrint('Admin sign-out call failed: $e');
      }
    }
    _accessToken = null;
    _refreshToken = null;
    _expiresAt = null;
    _user = null;
    await _prefs.remove(kAdminPersistSessionKey);
    _users.add(null);
  }

  /// A valid access token, refreshing first when the current one is spent.
  Future<String?> accessToken() async {
    final expires = _expiresAt;
    if (_accessToken != null &&
        expires != null &&
        DateTime.now().isBefore(expires.subtract(_refreshSkew))) {
      return _accessToken;
    }
    if (_refreshToken == null) return _accessToken;
    try {
      final response = await _post(
        'token?grant_type=refresh_token',
        {'refresh_token': _refreshToken},
      );
      _apply(response, persist: true);
      return _accessToken;
    } catch (e) {
      // A refresh token that GoTrue rejects is not coming back; drop the
      // session so the console asks for a fresh sign-in rather than looping.
      debugPrint('Admin token refresh failed: $e');
      await signOut();
      return null;
    }
  }

  Future<Map<String, dynamic>> _post(
    String path,
    Map<String, Object?> body,
  ) async {
    final http.Response response;
    try {
      response = await _client.post(
        Uri.parse('$_authUrl/$path'),
        headers: _headers,
        body: jsonEncode(body),
      );
    } catch (e) {
      throw const AuthFailure('Network error. Check your connection.');
    }

    Map<String, dynamic> decoded;
    try {
      decoded = (jsonDecode(response.body) as Map).cast<String, dynamic>();
    } catch (_) {
      decoded = const {};
    }

    if (response.statusCode >= 300) {
      throw AuthFailure(_messageFor(response.statusCode, decoded));
    }
    return decoded;
  }

  void _apply(Map<String, dynamic> session, {required bool persist}) {
    final access = session['access_token'] as String?;
    if (access == null || access.isEmpty) {
      throw const AuthFailure('Sign-in did not return a session.');
    }
    _accessToken = access;
    _refreshToken = session['refresh_token'] as String? ?? _refreshToken;

    final expiresIn = (session['expires_in'] as num?)?.toInt();
    final expiresAt = (session['expires_at'] as num?)?.toInt();
    _expiresAt = expiresAt != null
        ? DateTime.fromMillisecondsSinceEpoch(expiresAt * 1000)
        : DateTime.now().add(Duration(seconds: expiresIn ?? 3600));

    final user = session['user'];
    if (user is Map) _user = _toUser(user.cast<String, dynamic>());

    if (persist) {
      unawaited(
        _prefs.setString(
          kAdminPersistSessionKey,
          jsonEncode({
            'access_token': _accessToken,
            'refresh_token': _refreshToken,
            'expires_at': _expiresAt!.millisecondsSinceEpoch ~/ 1000,
            'user': user,
          }),
        ),
      );
    }
    _users.add(_user);
  }

  AppUser _toUser(Map<String, dynamic> user) {
    final meta = (user['user_metadata'] as Map?)?.cast<String, dynamic>() ??
        const <String, dynamic>{};
    return AppUser(
      uid: user['id'] as String? ?? '',
      email: user['email'] as String?,
      displayName: (meta['full_name'] ?? meta['name'] ?? meta['display_name'])
          as String?,
      photoUrl: (meta['avatar_url'] ?? meta['picture']) as String?,
    );
  }

  String _messageFor(int status, Map<String, dynamic> body) {
    final raw = (body['error_description'] ??
            body['msg'] ??
            body['message'] ??
            body['error'] ??
            body['error_code'])
        ?.toString();
    final lower = raw?.toLowerCase() ?? '';
    if (status == 400 || status == 401) {
      if (lower.contains('confirm')) {
        return 'Confirm this email address before signing in.';
      }
      return 'Wrong email or password.';
    }
    if (status == 422) {
      if (lower.contains('already') || lower.contains('exists')) {
        return 'An account already exists for that email.';
      }
      if (lower.contains('password')) {
        return 'Choose a stronger password (at least 6 characters).';
      }
      if (lower.contains('invalid') && lower.contains('email')) {
        return 'That email address doesn\'t look right.';
      }
      if (raw != null && raw.isNotEmpty) return raw;
      return 'Could not complete that request.';
    }
    if (status == 429) {
      return 'Too many attempts. Wait a moment and try again.';
    }
    if (raw != null && raw.isNotEmpty) return raw;
    return 'Could not sign in ($status).';
  }

  Future<void> dispose() async {
    await _users.close();
    _client.close();
  }
}
