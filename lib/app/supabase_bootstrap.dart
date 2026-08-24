import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Whether Supabase started successfully this run.
///
/// The app is usable without it: notes stay local, and sign-in/sync stay
/// unavailable — same local-only story as the old Firebase bootstrap.
bool get supabaseReady => _ready;

/// Back-compat alias used by older call sites / comments.
bool get firebaseReady => supabaseReady;

bool _ready = false;

/// Why auth/sync is unavailable (shown on sign-in / settings).
String? get supabaseError => _error;
String? get firebaseError => supabaseError;
String? _error;

String get kSupabaseUrl {
  final raw = () {
    if (dotenv.isInitialized) {
      final v = dotenv.env['SUPABASE_URL']?.trim() ?? '';
      if (v.isNotEmpty) return v;
    }
    return const String.fromEnvironment('SUPABASE_URL');
  }();
  // Project URL only — never include /rest/v1 (that breaks Auth paths).
  return raw.replaceAll(RegExp(r'/+$'), '').replaceAll(RegExp(r'/rest/v1$', caseSensitive: false), '');
}

String get kSupabaseAnonKey {
  if (dotenv.isInitialized) {
    final v = dotenv.env['SUPABASE_ANON_KEY']?.trim() ?? '';
    if (v.isNotEmpty) return v;
  }
  return const String.fromEnvironment('SUPABASE_ANON_KEY');
}

Future<void> initSupabase() async {
  final url = kSupabaseUrl;
  final key = kSupabaseAnonKey;
  if (url.isEmpty || key.isEmpty) {
    _error = 'Add SUPABASE_URL and SUPABASE_ANON_KEY to .env';
    debugPrint('Supabase unavailable, running local-only: $_error');
    return;
  }

  try {
    await Supabase.initialize(
      url: url,
      // Same value as Project Settings → API → anon / publishable key.
      publishableKey: key,
      authOptions: const FlutterAuthClientOptions(
        authFlowType: AuthFlowType.pkce,
      ),
    );
    _ready = true;
  } catch (e) {
    _error = '$e';
    debugPrint('Supabase unavailable, running local-only: $e');
  }
}

/// Current access token for Worker / billing / admin Bearer calls.
Future<String?> supabaseAccessToken() async {
  if (!_ready) return null;
  final session = Supabase.instance.client.auth.currentSession;
  if (session == null) return null;
  // Refresh if expired / about to expire.
  if (session.isExpired) {
    final refreshed = await Supabase.instance.client.auth.refreshSession();
    return refreshed.session?.accessToken;
  }
  return session.accessToken;
}

SupabaseClient get supabase => Supabase.instance.client;
