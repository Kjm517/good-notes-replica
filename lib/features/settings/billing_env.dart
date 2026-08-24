import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// RevenueCat public SDK key from `.env`.
///
/// Set [kRevenueCatFlutterKeyEnv] to the key for the platform you're running
/// (Android `goog_…` or iOS `appl_…` from RevenueCat → Project → API keys).
/// Legacy per-platform vars are still read as a fallback.
const kRevenueCatFlutterKeyEnv = 'REVENUECAT_FLUTTER_KEY';

String? revenueCatApiKeyFromEnv() {
  if (kIsWeb || !dotenv.isInitialized) return null;

  final flutterKey = dotenv.env[kRevenueCatFlutterKeyEnv]?.trim();
  if (flutterKey != null && flutterKey.isNotEmpty) return flutterKey;

  switch (defaultTargetPlatform) {
    case TargetPlatform.android:
      final key = dotenv.env['REVENUECAT_ANDROID_API_KEY']?.trim();
      return key != null && key.isNotEmpty ? key : null;
    case TargetPlatform.iOS:
      final key = dotenv.env['REVENUECAT_IOS_API_KEY']?.trim();
      return key != null && key.isNotEmpty ? key : null;
    default:
      return null;
  }
}

final revenueCatConfiguredProvider = Provider<bool>((ref) {
  return revenueCatApiKeyFromEnv() != null;
});
