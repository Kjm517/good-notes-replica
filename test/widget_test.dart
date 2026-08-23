import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:notably/app/providers.dart';
import 'package:notably/core/db/database.dart';
import 'package:notably/features/library/providers.dart';
import 'package:notably/features/settings/premium_providers.dart';
import 'package:notably/features/settings/settings_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('Settings screen renders section 12 groups', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPrefsProvider.overrideWithValue(prefs),
          databaseProvider.overrideWithValue(db),
          libraryStorageProvider.overrideWith((ref) => Stream.value(0)),
          quizStatsProvider.overrideWith(
            (ref) => Future.value((count: 0, avgPercent: 0)),
          ),
        ],
        child: const MaterialApp(home: SettingsScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Settings'), findsOneWidget);
    expect(find.text('Go Premium'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Report a bug'),
      48,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Report a bug'), findsOneWidget);
  });
}
