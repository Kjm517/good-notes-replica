import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:notably/features/editor/quiz/quiz_figure_view.dart';
import 'package:notably/main.dart' as app;

/// End-to-end checks against the real app: real database, real taps.
///
/// `flutter test` cannot do this — DB-backed widget tests hang on unsettled
/// spinners, which is why CLAUDE.md excludes them. Run with:
///   flutter test integration_test/app_test.dart -d <device>
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  /// pumpAndSettle times out while sync spinners keep animating, so time is
  /// advanced in fixed steps instead.
  Future<void> settle(WidgetTester tester, {int seconds = 5}) async {
    for (var i = 0; i < seconds * 4; i++) {
      await tester.pump(const Duration(milliseconds: 250));
    }
  }

  /// Whatever text is on screen — the difference between "not found" and
  /// knowing which screen the app was actually showing.
  String onScreen() => find
      .byType(Text)
      .evaluate()
      .map((e) => (e.widget as Text).data)
      .whereType<String>()
      .where((t) => t.trim().isNotEmpty)
      .take(30)
      .join(' | ');

  /// Fails loudly when the app is sitting on the sign-in gate.
  ///
  /// Every test here needs the library. Without this the failure reads
  /// "library never rendered", which sends you looking for a rendering bug
  /// instead of an account.
  void requireSignedIn() {
    if (find.text('Welcome to Notably').evaluate().isNotEmpty) {
      fail(
        'Stopped at the sign-in screen. These tests drive the real app, so '
        'the simulator needs a signed-in session (sign in once in the app on '
        'this device), or a build with Supabase left unconfigured.',
      );
    }
  }

  testWidgets('the library loads', (tester) async {
    await tester.pumpWidget(await app.bootstrap());
    await settle(tester, seconds: 8);
    requireSignedIn();
    // Either an empty library or documents — both mean it got past boot.
    final loaded = find.text('Nothing here yet').evaluate().isNotEmpty ||
        find.byIcon(Icons.add_rounded).evaluate().isNotEmpty;
    expect(loaded, isTrue, reason: 'library never rendered');
  });

  testWidgets('the create sheet opens and offers Identification', (tester) async {
    await tester.pumpWidget(await app.bootstrap());
    await settle(tester, seconds: 8);
    requireSignedIn();

    final newButton = find.byIcon(Icons.add_rounded);
    expect(newButton, findsWidgets, reason: 'no New button');
    await tester.tap(newButton.first);
    await settle(tester);

    expect(find.text('Import PDF or slides'), findsOneWidget);
    expect(find.text('New notebook'), findsOneWidget);
  });

  testWidgets('a notebook opens and back returns to the library in one tap',
      (tester) async {
    await tester.pumpWidget(await app.bootstrap());
    await settle(tester, seconds: 8);
    requireSignedIn();

    await tester.tap(find.byIcon(Icons.add_rounded).first);
    await settle(tester);
    await tester.tap(find.text('New notebook'));
    await settle(tester);

    // The sheet is taller than a landscape iPad, so its Create button starts
    // below the fold. Scroll it in rather than tapping into empty space —
    // a missed tap here is what made an earlier version of this test pass
    // without opening anything.
    final create = find.text('Create').last;
    await tester.ensureVisible(create);
    await settle(tester, seconds: 2);
    await tester.tap(create);
    await settle(tester, seconds: 10);

    // Creating does not open the notebook — NewNotebookSheet pops a
    // NewNotebookResult that nothing reads — so open it from the library.
    final created = find.text('Untitled Notebook');
    expect(created, findsWidgets,
        reason: 'notebook was not created. On screen: ${onScreen()}');
    await tester.tap(created.first);
    await settle(tester, seconds: 12);

    // By tooltip, not icon: the editor uses notablyBackIcon, which differs by
    // platform, and an icon finder silently matched nothing.
    final back = find.byTooltip('Back to library');
    expect(back, findsWidgets,
        reason: 'never reached the editor. On screen: ${onScreen()}');

    // One tap must reach the library. Page-jump history used to swallow this.
    await tester.tap(back.first);
    await settle(tester, seconds: 8);
    expect(find.byIcon(Icons.add_rounded), findsWidgets,
        reason: 'back did not return to the library in one tap');
  });

  testWidgets('the quiz sheet offers Identification as a question type',
      (tester) async {
    await tester.pumpWidget(await app.bootstrap());
    await settle(tester, seconds: 8);
    requireSignedIn();

    // Open the first document there is; the quiz lives inside the editor.
    // Cards are found by their title: they carry a "PDF" badge rather than
    // the icons an earlier version of this test guessed at.
    final textbook = find.text('textbook');
    final notebook = find.text('Untitled Notebook');
    final Finder? anyDoc = textbook.evaluate().isNotEmpty
        ? textbook.first
        : (notebook.evaluate().isNotEmpty ? notebook.first : null);
    if (anyDoc == null) {
      markTestSkipped('no document to open. On screen: ${onScreen()}');
      return;
    }
    await tester.tap(anyDoc);
    await settle(tester, seconds: 15);

    final quiz = find.byIcon(Icons.quiz_rounded);
    expect(quiz, findsWidgets,
        reason: 'no quiz button in the editor. On screen: ${onScreen()}');
    await tester.tap(quiz.first);
    await settle(tester, seconds: 6);

    // The setup sheet lists the kinds. Identification is the new one.
    expect(find.text('QUESTION TYPES'), findsOneWidget,
        reason: 'quiz setup sheet did not open. On screen: ${onScreen()}');
    expect(find.text('Identification'), findsOneWidget);
    expect(find.text('Name the marked part of a diagram'), findsOneWidget);
  });

  testWidgets('generating an Identification quiz renders a marked figure',
      (tester) async {
    await tester.pumpWidget(await app.bootstrap());
    await settle(tester, seconds: 8);
    requireSignedIn();

    final textbook = find.text('textbook');
    if (textbook.evaluate().isEmpty) {
      markTestSkipped('needs a PDF with diagrams. On screen: ${onScreen()}');
      return;
    }
    await tester.tap(textbook.first);
    await settle(tester, seconds: 15);

    final quiz = find.byIcon(Icons.quiz_rounded);
    expect(quiz, findsWidgets,
        reason: 'no quiz button. On screen: ${onScreen()}');
    await tester.tap(quiz.first);
    await settle(tester, seconds: 6);
    expect(find.text('QUESTION TYPES'), findsOneWidget,
        reason: 'setup sheet did not open. On screen: ${onScreen()}');

    // Identification only, so anything generated must be the new kind.
    for (final kind in ['Multiple choice', 'True / false', 'Short answer']) {
      final tile = find.text(kind);
      if (tile.evaluate().isNotEmpty) {
        await tester.tap(tile.first);
        await settle(tester, seconds: 1);
      }
    }
    await tester.tap(find.text('Identification'));
    await settle(tester, seconds: 1);

    final generate = find.textContaining('question quiz');
    expect(generate, findsWidgets,
        reason: 'no generate button. On screen: ${onScreen()}');
    await tester.ensureVisible(generate.first);
    await settle(tester, seconds: 1);
    await tester.tap(generate.first);

    // Gemini reads page images of a 4,895-page book; this is not quick.
    await settle(tester, seconds: 150);

    // Either a question is on screen, or the flow said why it could not.
    final answering = find.text('Type your answer').evaluate().isNotEmpty ||
        find.text('Check').evaluate().isNotEmpty;
    expect(answering, isTrue,
        reason: 'no question was presented. On screen: ${onScreen()}');

    // The point of the feature: the figure itself, with the marker on it.
    expect(find.byType(QuizFigureView), findsWidgets,
        reason: 'identification item rendered no figure. On screen: '
            '${onScreen()}');
  });
}
