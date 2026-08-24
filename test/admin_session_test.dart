import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:notably/features/admin/admin_supabase.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The staff session must be a thing of its own.
///
/// It used to be a second [SupabaseClient] with its own persist key, which
/// looked separate and was not: gotrue joins a web BroadcastChannel named
/// after the project URL, so both clients shared one channel and signing in
/// as staff logged the note-taking app in as staff too. These tests pin the
/// replacement — REST calls and its own preference key, no Supabase client.
Map<String, Object?> _session({
  required String accessToken,
  String refreshToken = 'refresh-1',
  int expiresIn = 3600,
  String email = 'admin@example.com',
}) {
  return {
    'access_token': accessToken,
    'refresh_token': refreshToken,
    'expires_in': expiresIn,
    'user': {
      'id': 'uid-1',
      'email': email,
      'user_metadata': {'full_name': 'Staff One'},
    },
  };
}

Future<AdminAuth> _auth(MockClient client) async {
  return AdminAuth(
    url: 'https://project.supabase.co',
    anonKey: 'anon-key',
    prefs: await SharedPreferences.getInstance(),
    client: client,
  );
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('signing in stores the staff session under its own key', () async {
    late Uri called;
    final auth = await _auth(MockClient((request) async {
      called = request.url;
      return http.Response(jsonEncode(_session(accessToken: 'access-1')), 200);
    }));

    await auth.signInWithEmail('admin@example.com', 'hunter2');

    expect(called.path, '/auth/v1/token');
    expect(called.queryParameters['grant_type'], 'password');
    expect(auth.currentUser?.email, 'admin@example.com');
    expect(await auth.accessToken(), 'access-1');

    final prefs = await SharedPreferences.getInstance();
    // Its own key, and — just as importantly — nothing written under the key
    // the app's Supabase client persists to.
    expect(prefs.getString(kAdminPersistSessionKey), isNotNull);
    expect(
      prefs.getKeys().where((k) => k.contains('project-auth-token')),
      isEmpty,
    );
  });

  test('a restored session survives a restart', () async {
    final auth = await _auth(MockClient((_) async =>
        http.Response(jsonEncode(_session(accessToken: 'access-1')), 200)));
    await auth.signInWithEmail('admin@example.com', 'hunter2');

    // A second instance over the same preferences, as a page reload would be.
    final reopened = await _auth(MockClient((_) async {
      throw StateError('restore must not need the network');
    }));
    await reopened.restore();

    expect(reopened.currentUser?.uid, 'uid-1');
  });

  test('an expired token is refreshed before it is handed out', () async {
    var grant = '';
    final auth = await _auth(MockClient((request) async {
      grant = request.url.queryParameters['grant_type'] ?? '';
      if (grant == 'password') {
        // Already expired, so the very next read has to refresh.
        return http.Response(
          jsonEncode(_session(accessToken: 'stale', expiresIn: -10)),
          200,
        );
      }
      return http.Response(
        jsonEncode(_session(accessToken: 'fresh', refreshToken: 'refresh-2')),
        200,
      );
    }));

    await auth.signInWithEmail('admin@example.com', 'hunter2');
    expect(await auth.accessToken(), 'fresh');
    expect(grant, 'refresh_token');
  });

  test('a rejected refresh ends the session instead of looping', () async {
    final auth = await _auth(MockClient((request) async {
      if (request.url.queryParameters['grant_type'] == 'password') {
        return http.Response(
          jsonEncode(_session(accessToken: 'stale', expiresIn: -10)),
          200,
        );
      }
      return http.Response('{"error":"invalid_grant"}', 400);
    }));

    await auth.signInWithEmail('admin@example.com', 'hunter2');

    expect(await auth.accessToken(), isNull);
    expect(auth.currentUser, isNull);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString(kAdminPersistSessionKey), isNull);
  });

  test('bad credentials report something a person can act on', () async {
    final auth = await _auth(MockClient((_) async => http.Response(
          '{"error":"invalid_grant","error_description":"Invalid login credentials"}',
          400,
        )));

    await expectLater(
      auth.signInWithEmail('admin@example.com', 'wrong'),
      throwsA(
        isA<Exception>().having(
          (e) => '$e',
          'message',
          contains('Wrong email or password'),
        ),
      ),
    );
    expect(auth.currentUser, isNull);
  });

  test('signing out of staff clears only the staff session', () async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('sb-project-auth-token', 'the-app-session');

    final auth = await _auth(MockClient((_) async =>
        http.Response(jsonEncode(_session(accessToken: 'access-1')), 200)));
    await auth.signInWithEmail('admin@example.com', 'hunter2');
    await auth.signOut();

    expect(auth.currentUser, isNull);
    expect(prefs.getString(kAdminPersistSessionKey), isNull);
    // The whole point: the app's session is untouched by staff sign-out.
    expect(prefs.getString('sb-project-auth-token'), 'the-app-session');
  });
}
