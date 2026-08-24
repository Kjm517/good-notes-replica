import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:notably/app/providers.dart';
import 'package:notably/core/db/database.dart';
import 'package:notably/features/settings/settings_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('Settings screen renders section 12 appearance picker', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPrefsProvider.overrideWithValue(prefs),
          databaseProvider.overrideWithValue(db),
        ],
        child: const MaterialApp(home: SettingsScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Settings'), findsOneWidget);
    expect(find.text('Go Premium'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('Report a bug'),
      120,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    expect(find.text('Report a bug'), findsOneWidget);
    expect(find.text('System'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('About Notably'),
      120,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    expect(find.text('About Notably'), findsOneWidget);
    expect(find.text('Version 1.0.0'), findsOneWidget);
  });
}
