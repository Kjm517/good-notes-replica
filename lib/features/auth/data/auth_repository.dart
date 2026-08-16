import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

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

/// Wraps Firebase Auth. The app is fully usable signed out — signing in only
/// enables cross-device sync, so every call here is optional.
class AuthRepository {
  AuthRepository({FirebaseAuth? auth}) : _auth = auth ?? FirebaseAuth.instance;

  final FirebaseAuth _auth;

  /// Emits the current user, or null when signed out.
  Stream<AppUser?> authStateChanges() =>
      _auth.authStateChanges().map(_toAppUser);

  AppUser? get currentUser => _toAppUser(_auth.currentUser);

  AppUser? _toAppUser(User? user) => user == null
      ? null
      : AppUser(
          uid: user.uid,
          email: user.email,
          displayName: user.displayName,
          photoUrl: user.photoURL,
        );

  // ---- Email + password ----------------------------------------------------

  Future<AppUser> signInWithEmail(String email, String password) async {
    try {
      final result = await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      return _toAppUser(result.user)!;
    } on FirebaseAuthException catch (e) {
      throw AuthFailure(_messageFor(e));
    }
  }

  Future<AppUser> signUpWithEmail(
    String email,
    String password, {
    String? displayName,
  }) async {
    try {
      final result = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      final name = displayName?.trim();
      if (name != null && name.isNotEmpty) {
        await result.user?.updateDisplayName(name);
        // Reload so the profile the app reads back carries the new name
        // rather than the empty one the account was created with.
        await result.user?.reload();
      }
      return _toAppUser(_auth.currentUser ?? result.user)!;
    } on FirebaseAuthException catch (e) {
      throw AuthFailure(_messageFor(e));
    }
  }

  Future<void> sendPasswordReset(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email.trim());
    } on FirebaseAuthException catch (e) {
      throw AuthFailure(_messageFor(e));
    }
  }

  // ---- Google --------------------------------------------------------------

  Future<AppUser> signInWithGoogle() async {
    try {
      if (kIsWeb) {
        // On web the popup flow avoids needing the GIS button plumbing.
        final provider = GoogleAuthProvider();
        final result = await _auth.signInWithPopup(provider);
        return _toAppUser(result.user)!;
      }

      final signIn = GoogleSignIn.instance;
      await signIn.initialize();
      final account = await signIn.authenticate();
      final auth = account.authentication;
      final credential = GoogleAuthProvider.credential(idToken: auth.idToken);
      final result = await _auth.signInWithCredential(credential);
      return _toAppUser(result.user)!;
    } on FirebaseAuthException catch (e) {
      throw AuthFailure(_messageFor(e));
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled) {
        throw const AuthFailure('Sign-in cancelled.');
      }
      throw AuthFailure('Google sign-in failed: ${e.description ?? e.code}');
    }
  }

  // ---- Session -------------------------------------------------------------

  /// Applies a "keep me signed in" choice, which has to be set *before* the
  /// sign-in call it should govern.
  ///
  /// Only web can express this: [Persistence.session] drops the session when
  /// the tab closes. The mobile SDKs always persist, so there the choice is
  /// enforced by signing out on the next cold start (see [main]).
  Future<void> applyPersistence({required bool keepSignedIn}) async {
    if (!kIsWeb) return;
    try {
      await _auth.setPersistence(
        keepSignedIn ? Persistence.LOCAL : Persistence.SESSION,
      );
    } catch (_) {
      // Private-mode or partitioned storage can refuse; the default stands and
      // sign-in should still go ahead.
    }
  }

  Future<void> signOut() async {
    await _auth.signOut();
    if (!kIsWeb) {
      try {
        await GoogleSignIn.instance.signOut();
      } catch (_) {
        // Not signed in with Google; nothing to do.
      }
    }
  }

  /// Turns Firebase's error codes into something a person can act on.
  String _messageFor(FirebaseAuthException e) => switch (e.code) {
        'invalid-email' => 'That email address doesn\'t look right.',
        'user-disabled' => 'This account has been disabled.',
        'user-not-found' ||
        'wrong-password' ||
        'invalid-credential' =>
          'Wrong email or password.',
        'email-already-in-use' =>
          'That email already has an account — try signing in.',
        'weak-password' => 'Choose a longer password (at least 6 characters).',
        'network-request-failed' =>
          'No connection. Your notes are safe on this device.',
        'too-many-requests' => 'Too many attempts. Try again in a moment.',
        'operation-not-allowed' =>
          'That sign-in method isn\'t enabled in Firebase yet.',
        _ => e.message ?? 'Sign-in failed (${e.code}).',
      };
}
