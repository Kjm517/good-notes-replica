import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

export '../../features/settings/premium_providers.dart' show isPremiumProvider;

import 'gemini_service.dart';

/// The Gemini AI service, or null when `.env` has no API key.
///
/// Quiz generation only needs the key — it must not wait on Supabase, or a
/// local-only session silently falls back to fill-in-the-blank items.
final geminiServiceProvider = Provider<GeminiService?>((ref) {
  final service = GeminiService();
  if (!service.enabled) {
    debugPrint('Gemini disabled: add GEMINI_API_KEY to .env and rebuild');
    return null;
  }
  debugPrint('Gemini ready (${service.keyKind})');
  return service;
});

/// Whether the Gemini key is loaded and quiz generation can call the API.
final aiAvailableProvider = Provider<bool>((ref) {
  return ref.watch(geminiServiceProvider) != null;
});
