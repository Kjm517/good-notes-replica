import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../../app/providers.dart';
import '../../app/supabase_bootstrap.dart';
import '../../core/storage/asset_store.dart';
import '../../core/sync/sync_providers.dart';
import '../auth/providers.dart';

/// Raised when the account could not be deleted. The message is shown to the
/// user, so it says what happened rather than which call failed.
class DeleteAccountFailure implements Exception {
  const DeleteAccountFailure(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Deletes the signed-in account and everything it owns.
///
/// The work happens on the Worker: removing an auth user needs the service
/// role key, which deliberately never ships in the app. This sends the
/// request, and the Worker decides — the account it deletes is whichever one
/// the access token proves, so there is nothing here that could point it at
/// somebody else.
class DeleteAccountService {
  DeleteAccountService({required this.endpoint, http.Client? client})
      : _client = client ?? http.Client();

  final String endpoint;
  final http.Client _client;

  Future<void> deleteAccount() async {
    final base = endpoint.trim().replaceAll(RegExp(r'/+$'), '');
    if (base.isEmpty) {
      throw const DeleteAccountFailure(
        'Account deletion is not available in this build.',
      );
    }
    final token = await supabaseAccessToken();
    if (token == null || token.isEmpty) {
      throw const DeleteAccountFailure('Sign in again, then try once more.');
    }

    final http.Response response;
    try {
      response = await _client
          .post(
            Uri.parse('$base/user/account/delete'),
            headers: {
              'Authorization': 'Bearer $token',
              'Content-Type': 'application/json',
            },
          )
          // Deleting a large library walks every object in the bucket, so this
          // is deliberately patient compared with the rest of the app.
          .timeout(const Duration(seconds: 120));
    } catch (e) {
      throw DeleteAccountFailure(
        'Could not reach the server. Check your connection and try again.\n$e',
      );
    }

    if (response.statusCode == 401) {
      throw const DeleteAccountFailure('Sign in again, then try once more.');
    }
    if (response.statusCode >= 400) {
      String message;
      try {
        message = (jsonDecode(response.body) as Map)['error'] as String? ??
            'Deletion failed (${response.statusCode}).';
      } catch (_) {
        message = 'Deletion failed (${response.statusCode}).';
      }
      throw DeleteAccountFailure(message);
    }
  }
}

final deleteAccountServiceProvider = Provider<DeleteAccountService>((ref) {
  return DeleteAccountService(endpoint: kFileEndpoint);
});

/// Deletes the account, then leaves this device with nothing behind.
///
/// Order matters. The server goes first: if it fails the account still exists
/// and the user can try again, whereas wiping locally first would leave them
/// signed into an account whose data had already gone from this device only.
final deleteAccountProvider = Provider<Future<void> Function()>((ref) {
  return () async {
    await ref.read(deleteAccountServiceProvider).deleteAccount();

    // Stop sync before clearing, or an in-flight run pushes rows from the
    // local database back up to an account that no longer exists.
    ref.read(syncPausedProvider.notifier).setPaused(true);

    // Past this point the account is gone. Anything that fails while tidying
    // up this device is logged rather than raised: telling the user the
    // deletion failed would be untrue, and would invite them to retry
    // something that has already happened.
    final db = ref.read(databaseProvider);
    try {
      final assets = await db.select(db.assets).get();
      for (final asset in assets) {
        await deleteAsset(asset.localPath);
      }
    } catch (e) {
      debugPrint('Could not remove local files after deletion: $e');
    }

    try {
      // Children before parents, so the foreign keys stay satisfied — pages
      // and strokes reference documents.
      await db.transaction(() async {
        await db.delete(db.strokes).go();
        await db.delete(db.canvasElements).go();
        await db.delete(db.notePages).go();
        await db.delete(db.quizAttempts).go();
        await db.delete(db.assets).go();
        await db.delete(db.userPrefs).go();
        await db.delete(db.documents).go();
      });
    } catch (e) {
      debugPrint('Could not clear the local database after deletion: $e');
    }

    try {
      await ref.read(sharedPrefsProvider).clear();
    } catch (e) {
      debugPrint('Could not clear preferences after deletion: $e');
    }

    // Last, so the app returns to the sign-in screen with nothing left to
    // show behind it.
    try {
      await ref.read(authRepositoryProvider)?.signOut();
    } catch (e) {
      debugPrint('Sign-out after account deletion failed: $e');
    }
  };
});
