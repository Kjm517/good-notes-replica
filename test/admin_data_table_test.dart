import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:notably/app/design.dart';
import 'package:notably/app/theme.dart';
import 'package:notably/features/admin/widgets/admin_widgets.dart';

/// Layout rules for the admin tables.
///
/// Both of these are the kind of thing that looks fine in code and wrong on
/// screen: a chip that quietly fills its cell, and an icon column that takes
/// as much width as the column holding an email address.
Widget _host(Widget child, {double width = 900}) {
  return MaterialApp(
    theme: AppTheme.light(),
    home: Scaffold(
      body: Center(
        child: SizedBox(width: width, child: child),
      ),
    ),
  );
}

void main() {
  testWidgets('a status chip hugs its label instead of filling the column',
      (tester) async {
    await tester.pumpWidget(
      _host(
        AdminDataTable(
          columns: const ['Member', 'Role', ''],
          rows: [
            [
              const Text('someone@example.com'),
              AdminStatusChip(label: 'admin', color: AppTokens.light.accentText),
              const Icon(Icons.person_remove_outlined),
            ],
          ],
        ),
      ),
    );

    final chip = tester.getSize(
      find.ancestor(
        of: find.text('admin'),
        matching: find.byType(Container),
      ).first,
    );
    // The Role cell is a real share of a 900px table; the chip must be a
    // five-character pill, not that whole share.
    expect(chip.width, lessThan(80));
  });

  testWidgets('the blank-header action column is sized to its button',
      (tester) async {
    await tester.pumpWidget(
      _host(
        AdminDataTable(
          columns: const ['Member', 'Role', 'Added', ''],
          flex: const [5, 2, 2],
          rows: [
            [
              const Text('someone@example.com', key: Key('member')),
              const Text('admin'),
              const Text('2026-08-23'),
              const Icon(Icons.close, key: Key('action')),
            ],
          ],
        ),
      ),
    );

    final action = tester.getSize(
      find.ancestor(
        of: find.byKey(const Key('action')),
        matching: find.byType(SizedBox),
      ).first,
    );
    expect(action.width, 52);

    // 900 minus 32px padding minus the 52px action column, split 5:2:2 —
    // the member column should get well over half of what remains.
    final member = tester.getSize(
      find.ancestor(
        of: find.byKey(const Key('member')),
        matching: find.byType(Expanded),
      ).first,
    );
    expect(member.width, greaterThan(350));
  });

  testWidgets('a text-button column can be widened without breaking alignment',
      (tester) async {
    await tester.pumpWidget(
      _host(
        AdminDataTable(
          columns: const ['User', 'Plan', ''],
          actionWidth: 104,
          rows: [
            [
              const Text('someone@example.com'),
              const Text('yearly', key: Key('plan')),
              TextButton(onPressed: () {}, child: const Text('Revoke')),
            ],
          ],
        ),
      ),
    );

    // Matched by width rather than by position in the ancestor chain: a
    // TextButton has SizedBoxes of its own, and so does the test host.
    expect(
      find.ancestor(
        of: find.text('Revoke'),
        matching: find.byWidgetPredicate(
          (w) => w is SizedBox && w.width == 104,
        ),
      ),
      findsOneWidget,
    );
    // The label must fit rather than be clipped by the column.
    expect(tester.getSize(find.text('Revoke')).width, lessThan(104));
    expect(
      tester.getTopLeft(find.text('Plan')).dx,
      tester.getTopLeft(find.byKey(const Key('plan'))).dx,
    );
  });

  testWidgets('header and body columns line up', (tester) async {
    await tester.pumpWidget(
      _host(
        AdminDataTable(
          columns: const ['Member', 'Role', 'Added', ''],
          flex: const [5, 2, 2],
          rows: [
            [
              const Text('someone@example.com'),
              const Text('admin'),
              const Text('2026-08-23'),
              const Icon(Icons.close),
            ],
          ],
        ),
      ),
    );

    // Drift between the two would show as a header that no longer sits above
    // the values it names, which is why both go through the same sizing.
    expect(
      tester.getTopLeft(find.text('Role')).dx,
      tester.getTopLeft(find.text('admin')).dx,
    );
    expect(
      tester.getTopLeft(find.text('Added')).dx,
      tester.getTopLeft(find.text('2026-08-23')).dx,
    );
  });
}
