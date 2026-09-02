import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../app/supabase_bootstrap.dart';

/// Result of a sign-in or sign-up attempt.
class AuthResult {
  const AuthResult({required this.user, this.isNewUser = false});

  final AppUser user;

  /// True when the account was just created (email sign-up or first OAuth).
  final bool isNewUser;
}

/// A signed-in user, reduced to what the app actually needs.
class AppUser {
  const AppUser({
    required this.uid,
    this.email,
    this.displayName,
    this.photoUrl,
  });

  final String uid;
  final String? email;
  final String? displayName;
  final String? photoUrl;

  /// Best label for the account menu.
  String get label => displayName?.isNotEmpty == true
      ? displayName!
      : (email ?? 'Signed in');
}

/// Something went wrong signing in, with a message safe to show the user.
class AuthFailure implements Exception {
  const AuthFailure(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Wraps Supabase Auth. The app is fully usable signed out — signing in only
/// enables cross-device sync, so every call here is optional.
class AuthRepository {
  AuthRepository({GoTrueClient? auth}) : _auth = auth ?? supabase.auth;

  final GoTrueClient _auth;

  /// Emits the current user, or null when signed out.
  Stream<AppUser?> authStateChanges() async* {
    yield _toAppUser(_auth.currentUser);
    yield* _auth.onAuthStateChange.map(
      (event) => _toAppUser(event.session?.user),
    );
  }

  AppUser? get currentUser => _toAppUser(_auth.currentUser);

  AppUser? _toAppUser(User? user) {
    if (user == null) return null;
    final meta = user.userMetadata ?? const <String, dynamic>{};
    final name = meta['full_name'] as String? ??
        meta['name'] as String? ??
        meta['display_name'] as String?;
    final photo = meta['avatar_url'] as String? ?? meta['picture'] as String?;
    return AppUser(
      uid: user.id,
      email: user.email,
      displayName: name,
      photoUrl: photo,
    );
  }

  // ---- Email + password ----------------------------------------------------

  Future<AuthResult> signInWithEmail(String email, String password) async {
    try {
      final result = await _auth.signInWithPassword(
        email: email.trim(),
        password: password,
      );
      final user = _toAppUser(result.user ?? _auth.currentUser);
      if (user == null) throw const AuthFailure('Sign-in failed.');
      return AuthResult(user: user);
    } on AuthException catch (e) {
      throw AuthFailure(_messageFor(e));
    }
  }

  Future<AuthResult> signUpWithEmail(
    String email,
    String password, {
    String? displayName,
  }) async {
    try {
      final name = displayName?.trim();
      final result = await _auth.signUp(
        email: email.trim(),
        password: password,
        data: name != null && name.isNotEmpty
            ? {'full_name': name, 'display_name': name}
            : null,
      );
      var user = _toAppUser(result.user ?? _auth.currentUser);
      // If the project doesn't require email confirm, signUp usually returns a
      // session. If it doesn't, sign in immediately so the app can enter home.
      if (user != null && _auth.currentSession == null && result.session == null) {
        try {
          final signedIn = await _auth.signInWithPassword(
            email: email.trim(),
            password: password,
          );
          user = _toAppUser(signedIn.user ?? _auth.currentUser);
        } on AuthException {
          // Email confirmation required (or other gate) — fall through.
        }
      }
      if (user == null || _auth.currentSession == null) {
        throw const AuthFailure(
          'Check your email to confirm the account, then sign in.',
        );
      }
      return AuthResult(user: user, isNewUser: true);
    } on AuthException catch (e) {
      throw AuthFailure(_messageFor(e));
    }
  }

  Future<void> sendPasswordReset(String email) async {
    try {
      await _auth.resetPasswordForEmail(email.trim());
    } on AuthException catch (e) {
      throw AuthFailure(_messageFor(e));
    }
  }

  // ---- Google --------------------------------------------------------------

  /// Native / mobile return URL. Must be listed in Supabase → Authentication →
  /// URL Configuration → Redirect URLs, and registered on Android / iOS.
  static const nativeOAuthRedirect = 'io.supabase.notably://login-callback/';

  String _oauthRedirectTo() {
    if (kIsWeb) {
      // Same origin so the PKCE code verifier in localStorage still applies.
      return Uri.base.origin;
    }
    return nativeOAuthRedirect;
  }

  bool _createdRecently(User user) {
    final created = DateTime.tryParse(user.createdAt);
    if (created == null) return false;
    return DateTime.now().toUtc().difference(created.toUtc()).inMinutes.abs() <
        10;
  }

  /// Message shown when the browser hands control back without a session.
  ///
  /// Almost always one thing: the return URL is not on the project's allow
  /// list, so GoTrue redirects to the Site URL instead of back into the app
  /// and the browser shows "site can't be reached".
  static const _redirectNotAllowed =
      'Google sign-in did not come back to the app. In Supabase → '
      'Authentication → URL Configuration, add this return URL under '
      'Redirect URLs: $nativeOAuthRedirect (and your web origin, e.g. '
      'http://localhost:5000, for the browser build).';

  Future<AuthResult> signInWithGoogle() async {
    try {
      final pending = Completer<AuthResult>();
      final sub = _auth.onAuthStateChange.listen((data) {
        final raw = data.session?.user;
        final user = _toAppUser(raw);
        if (user != null && !pending.isCompleted) {
          pending.complete(
            AuthResult(user: user, isNewUser: raw != null && _createdRecently(raw)),
          );
        }
      });
      // On native the browser is a separate app, so coming back to Notably
      // without a session means the round trip failed. Detecting that beats
      // spinning for the full timeout, which is what a bad redirect URL used
      // to look like.
      AppLifecycleListener? lifecycle;
      if (!kIsWeb) {
        lifecycle = AppLifecycleListener(
          onResume: () async {
            // Let the deep link land first — it arrives around the resume.
            await Future<void>.delayed(const Duration(seconds: 2));
            if (pending.isCompleted) return;
            if (_auth.currentSession != null) return;
            pending.completeError(const AuthFailure(_redirectNotAllowed));
          },
        );
      }
      try {
        final ok = await _auth.signInWithOAuth(
          OAuthProvider.google,
          redirectTo: _oauthRedirectTo(),
          authScreenLaunchMode: kIsWeb
              ? LaunchMode.platformDefault
              : LaunchMode.externalApplication,
        );
        if (!ok) throw const AuthFailure('Google sign-in was cancelled.');
        // Web navigates away; mobile returns via the deep link.
        return await pending.future.timeout(
          const Duration(minutes: 2),
          onTimeout: () => throw const AuthFailure(_redirectNotAllowed),
        );
      } finally {
        lifecycle?.dispose();
        await sub.cancel();
      }
    } on AuthException catch (e) {
      throw AuthFailure(_messageFor(e));
    }
  }

  /// Finishes a PKCE redirect that landed back on this origin with `?code=`.
  Future<AuthResult?> completeOAuthRedirect(Uri uri) async {
    final code = uri.queryParameters['code'];
    if (code == null || code.isEmpty) return null;
    if (currentUser != null) {
      return AuthResult(user: currentUser!);
    }
    try {
      final result = await _auth.exchangeCodeForSession(code);
      final raw = result.session.user;
      final user = _toAppUser(raw);
      if (user == null) return null;
      return AuthResult(
        user: user,
        isNewUser: raw != null && _createdRecently(raw),
      );
    } on AuthException catch (e) {
      throw AuthFailure(_messageFor(e));
    }
  }

  // ---- Session -------------------------------------------------------------

  /// Supabase persists the session locally by default. On web, "don't keep me
  /// signed in" is enforced by signing out on cold start in `main.dart`.
  Future<void> applyPersistence({required bool keepSignedIn}) async {}

  /// Bearer token for the Cloudflare Worker (file sync, billing, etc.).
  Future<String?> idToken({bool forceRefresh = false}) async {
    if (forceRefresh) {
      try {
        final refreshed = await _auth.refreshSession();
        return refreshed.session?.accessToken;
      } on AuthException {
        // Fall through to whatever session is still cached.
      }
    }
    return supabaseAccessToken();
  }

  Future<void> signOut() async {
    await _auth.signOut();
  }

  String _messageFor(AuthException e) {
    final code = (e.code ?? '').toLowerCase();
    final msg = e.message.toLowerCase();

    // Prefer GoTrue error codes — a bare "contains('email')" match used to
    // rewrite SMTP / confirm-email failures as "doesn't look right".
    switch (code) {
      case 'invalid_credentials':
      case 'invalid_login_credentials':
        return 'Wrong email or password.';
      case 'user_already_exists':
      case 'email_exists':
        return 'An account already exists for that email.';
      case 'weak_password':
        return 'Choose a stronger password (at least 6 characters).';
      case 'email_address_invalid':
      case 'validation_failed':
        if (msg.contains('email')) {
          return 'That email address doesn\'t look right.';
        }
        break;
      case 'email_not_confirmed':
        return 'This account is still unconfirmed. In Supabase → Authentication → '
            'Users, open the user menu and choose Confirm user, then try again.';
      case 'over_email_send_rate_limit':
      case 'over_request_rate_limit':
        return 'Too many attempts. Wait a moment and try again.';
    }

    if (msg.contains('invalid login') || msg.contains('invalid credentials')) {
      return 'Wrong email or password.';
    }
    if (msg.contains('already registered') ||
        msg.contains('already been registered') ||
        msg.contains('user already exists')) {
      return 'An account already exists for that email.';
    }
    if (msg.contains('weak password') ||
        (msg.contains('password') &&
            (msg.contains('least') || msg.contains('short') || msg.contains('weak')))) {
      return 'Choose a stronger password (at least 6 characters).';
    }
    if (msg.contains('invalid format') ||
        msg.contains('email address is invalid') ||
        msg.contains('unable to validate email')) {
      return 'That email address doesn\'t look right.';
    }
    if (msg.contains('confirm') && msg.contains('email')) {
      return 'This account is still unconfirmed. In Supabase → Authentication → '
          'Users, open the user menu and choose Confirm user, then try again.';
    }
    if ((msg.contains('sending') && msg.contains('email')) ||
        msg.contains('error sending') ||
        msg.contains('smtp')) {
      return 'Could not send the confirmation email. '
          'In Supabase → Auth → Providers, turn off “Confirm email”, '
          'or configure SMTP, then try again.';
    }
    if (msg.contains('rate') || msg.contains('too many')) {
      return 'Too many attempts. Wait a moment and try again.';
    }
    if (msg.contains('network') || msg.contains('fetch')) {
      return 'Network error. Check your connection and try again.';
    }
    return e.message.isNotEmpty ? e.message : 'Sign-in failed.';
  }
}
