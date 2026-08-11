import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:notably/app/providers.dart';
import 'package:notably/features/settings/settings_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Note: full library/editor flows depend on the native SQLite plugin, which is
// not available under `flutter test`. Those are exercised via device/web runs
// and (later) integration tests. This keeps a fast, DB-free smoke test.
void main() {
  testWidgets('Settings screen renders appearance options', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [sharedPrefsProvider.overrideWithValue(prefs)],
        child: const MaterialApp(home: SettingsScreen()),
      ),
    );
    await tester.pump();

    expect(find.text('Settings'), findsOneWidget);
    expect(find.text('System default'), findsOneWidget);
    expect(find.text('Dark'), findsOneWidget);
  });
}
