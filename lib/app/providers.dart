import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../core/db/database.dart';

/// Single app database instance.
final databaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(db.close);
  return db;
});

/// Shared UUID generator.
final uuidProvider = Provider<Uuid>((ref) => const Uuid());

/// SharedPreferences, provided asynchronously and overridden at startup.
final sharedPrefsProvider = Provider<SharedPreferences>(
  (ref) => throw UnimplementedError('sharedPrefsProvider must be overridden'),
);

/// App theme mode, persisted to SharedPreferences.
final themeModeProvider =
    NotifierProvider<ThemeModeController, ThemeMode>(ThemeModeController.new);

class ThemeModeController extends Notifier<ThemeMode> {
  static const _key = 'theme_mode';

  @override
  ThemeMode build() {
    final prefs = ref.watch(sharedPrefsProvider);
    final stored = prefs.getString(_key);
    return switch (stored) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      _ => ThemeMode.system,
    };
  }

  Future<void> set(ThemeMode mode) async {
    state = mode;
    final prefs = ref.read(sharedPrefsProvider);
    await prefs.setString(_key, mode.name);
  }
}
