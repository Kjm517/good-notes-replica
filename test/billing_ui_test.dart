import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:notably/app/providers.dart';
import 'package:notably/core/db/database.dart';
import 'package:notably/features/settings/billing_plan.dart';
import 'package:notably/features/settings/manage_plan_sheet.dart';
import 'package:notably/features/settings/premium_providers.dart';
import 'package:notably/features/settings/renewal_reminder_card.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Blackbox checks on the billing UI: given a stored plan state, does the user
/// see the right thing? These drive real widgets rather than calling providers
/// directly, so they catch wiring mistakes a unit test would miss.
Future<Widget> _host(
  Widget child, {
  Map<String, Object> prefs = const {},
}) async {
  SharedPreferences.setMockInitialValues(prefs);
  final store = await SharedPreferences.getInstance();
  final db = AppDatabase(NativeDatabase.memory());
  addTearDown(db.close);

  return ProviderScope(
    overrides: [
      sharedPrefsProvider.overrideWithValue(store),
      databaseProvider.overrideWithValue(db),
    ],
    child: MaterialApp(home: Scaffold(body: child)),
  );
}

/// Prefs that make the app treat this device as holding a paid term.
Map<String, Object> premiumPrefs({
  required Duration expiresIn,
  String plan = 'monthly',
  String method = 'gcash',
  bool cancelled = false,
  bool reminders = true,
}) {
  return {
    'is_premium': true,
    'billing_plan': plan,
    'premium_renews_at':
        DateTime.now().add(expiresIn).toIso8601String(),
    'premium_paid_with': method,
    'notifications_enabled': true,
    'premium_renewal_reminder': reminders,
    if (cancelled) 'premium_cancelled_at': DateTime.now().toIso8601String(),
  };
}

void main() {
  group('ManagePlanSheet', () {
    testWidgets('shows the plan, method and expiry of an active term',
        (tester) async {
      await tester.pumpWidget(
        await _host(
          const ManagePlanSheet(),
          prefs: premiumPrefs(expiresIn: const Duration(days: 20)),
        ),
      );
      await tester.pump();

      expect(find.text('Your Premium'), findsOneWidget);
      expect(find.text('Monthly'), findsOneWidget);
      expect(find.text('GCash'), findsOneWidget);
      // A wallet term does not renew, so it must not claim it will.
      expect(find.text('Access until'), findsOneWidget);
      expect(find.text('Renews'), findsNothing);
    });

    testWidgets('offers cancel and extend while active', (tester) async {
      await tester.pumpWidget(
        await _host(
          const ManagePlanSheet(),
          prefs: premiumPrefs(expiresIn: const Duration(days: 20)),
        ),
      );
      await tester.pump();

      expect(find.text('Extend Premium'), findsOneWidget);
      expect(find.text('Cancel Premium'), findsOneWidget);
    });

    testWidgets('a cancelled term still shows access, not a dead plan',
        (tester) async {
      await tester.pumpWidget(
        await _host(
          const ManagePlanSheet(),
          prefs: premiumPrefs(
            expiresIn: const Duration(days: 3),
            cancelled: true,
          ),
        ),
      );
      await tester.pump();

      // The whole point of cancel: access continues to the paid-for date.
      expect(find.textContaining('Cancelled'), findsWidgets);
      expect(find.text('Keep Premium'), findsOneWidget);
      expect(find.text('Cancel Premium'), findsNothing);
    });

    testWidgets('lifetime never offers to cancel or extend', (tester) async {
      await tester.pumpWidget(
        await _host(
          const ManagePlanSheet(),
          prefs: premiumPrefs(
            expiresIn: const Duration(days: 3650),
            plan: 'lifetime',
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Never'), findsOneWidget);
      expect(find.text('Cancel Premium'), findsNothing);
      expect(find.text('Extend Premium'), findsNothing);
    });

    testWidgets('QR Ph payments are named correctly', (tester) async {
      await tester.pumpWidget(
        await _host(
          const ManagePlanSheet(),
          prefs: premiumPrefs(
            expiresIn: const Duration(days: 10),
            method: 'qrph',
          ),
        ),
      );
      await tester.pump();

      expect(find.text('QR Ph'), findsOneWidget);
    });

    testWidgets('an admin grant with no payment method still renders',
        (tester) async {
      await tester.pumpWidget(
        await _host(
          const ManagePlanSheet(),
          prefs: {
            'is_premium': true,
            'billing_plan': 'monthly',
            'premium_renews_at':
                DateTime.now().add(const Duration(days: 5)).toIso8601String(),
          },
        ),
      );
      await tester.pump();

      expect(find.text('Granted'), findsOneWidget);
    });
  });

  group('RenewalReminderCard', () {
    testWidgets('stays hidden when the term is comfortably far off',
        (tester) async {
      await tester.pumpWidget(
        await _host(
          const RenewalReminderCard(),
          prefs: premiumPrefs(expiresIn: const Duration(days: 20)),
        ),
      );
      await tester.pump();

      expect(find.textContaining('Premium ends'), findsNothing);
    });

    testWidgets('warns inside the reminder window', (tester) async {
      await tester.pumpWidget(
        await _host(
          const RenewalReminderCard(),
          prefs: premiumPrefs(expiresIn: const Duration(days: 2)),
        ),
      );
      await tester.pump();

      expect(find.textContaining('Premium ends'), findsOneWidget);
      // The button quotes the price; the body copy also says "Extend".
      expect(find.textContaining('Extend · '), findsOneWidget);
    });

    testWidgets('says "tomorrow" rather than "in 1 days"', (tester) async {
      await tester.pumpWidget(
        await _host(
          const RenewalReminderCard(),
          prefs: premiumPrefs(expiresIn: const Duration(hours: 30)),
        ),
      );
      await tester.pump();

      expect(find.text('Premium ends tomorrow'), findsOneWidget);
    });

    testWidgets('stays silent once cancelled — there is nothing to nag about',
        (tester) async {
      await tester.pumpWidget(
        await _host(
          const RenewalReminderCard(),
          prefs: premiumPrefs(
            expiresIn: const Duration(days: 2),
            cancelled: true,
          ),
        ),
      );
      await tester.pump();

      expect(find.textContaining('Premium ends'), findsNothing);
    });

    testWidgets('respects the reminder switch being off', (tester) async {
      await tester.pumpWidget(
        await _host(
          const RenewalReminderCard(),
          prefs: premiumPrefs(
            expiresIn: const Duration(days: 2),
            reminders: false,
          ),
        ),
      );
      await tester.pump();

      expect(find.textContaining('Premium ends'), findsNothing);
    });

    testWidgets('never nags a lifetime plan', (tester) async {
      await tester.pumpWidget(
        await _host(
          const RenewalReminderCard(),
          prefs: premiumPrefs(
            expiresIn: const Duration(days: 1),
            plan: 'lifetime',
          ),
        ),
      );
      await tester.pump();

      expect(find.textContaining('Premium ends'), findsNothing);
    });

    testWidgets('shows nothing for a free account', (tester) async {
      await tester.pumpWidget(
        await _host(const RenewalReminderCard(), prefs: const {}),
      );
      await tester.pump();

      expect(find.textContaining('Premium ends'), findsNothing);
    });
  });

  group('regression: expiry reactivity', () {
    /// Extending a live plan changed no watched provider — premium stayed
    /// true, the plan stayed monthly — so the cached expiry survived the
    /// renewal and the sheet kept showing the old date.
    test('a new expiry reaches the UI after an extension', () async {
      SharedPreferences.setMockInitialValues(
        premiumPrefs(expiresIn: const Duration(days: 2)),
      );
      final store = await SharedPreferences.getInstance();
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);

      final container = ProviderContainer(
        overrides: [
          sharedPrefsProvider.overrideWithValue(store),
          databaseProvider.overrideWithValue(db),
        ],
      );
      addTearDown(container.dispose);

      final before = container.read(premiumRenewsAtProvider);
      expect(before, isNotNull);

      // Simulate the worker reporting a longer term.
      final extended = DateTime.now().add(const Duration(days: 32));
      await container
          .read(billingPlanProvider.notifier)
          .syncFromPayMongo(plan: BillingPlan.monthly, expiresAt: extended);

      final after = container.read(premiumRenewsAtProvider);
      expect(after, isNotNull);
      expect(
        after!.isAfter(before!),
        isTrue,
        reason: 'expiry must move forward after an extension',
      );
    });
  });
}
