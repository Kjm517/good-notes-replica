import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:notably/app/theme.dart';
import 'package:notably/features/library/widgets/document_card.dart';
import 'package:notably/features/settings/settings_widgets.dart';

void main() {
  testWidgets('cover transfer badge fits a narrow iPad grid tile',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: const Scaffold(
          body: Center(
            child: SizedBox(
              width: 132.5,
              height: 40,
              child: CoverTransferBadge(
                icon: Icons.cloud_sync_outlined,
                label: 'Waiting to sync pages…',
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(find.text('Waiting to sync pages…'), findsOneWidget);
  });

  testWidgets('appearance picker fits a narrow settings card', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 280,
              child: AppearancePicker(
                mode: ThemeMode.system,
                onChanged: (_) {},
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(find.text('System'), findsOneWidget);
  });
}
