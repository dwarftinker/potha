import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:potha/features/library/ui/book_cover.dart';
import 'package:potha/features/library/ui/book_tile.dart';

import 'test_app.dart';

void main() {
  testWidgets('an empty library shows the empty state with an Add book button (FR-014)',
      (tester) async {
    final app = TestApp();
    await app.pump(tester);

    expect(find.textContaining('Your library is empty'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Add book'), findsOneWidget);
    expect(find.byType(BookTile), findsNothing);

    await app.dispose(tester);
  });

  testWidgets('books show cover or placeholder, title, author and progress', (tester) async {
    final app = TestApp();
    await app.pump(tester);
    await seedBook(tester, app.db,
        id: 'a', title: 'Anna Karenina', author: 'Leo Tolstoy', cover: true, currentPage: 126);
    await seedBook(tester, app.db, id: 'b', title: 'Untitled notes');

    expect(find.byType(BookTile), findsNWidgets(2));
    expect(find.textContaining('Your library is empty'), findsNothing);

    final anna = find.ancestor(of: find.text('Anna Karenina'), matching: find.byType(BookTile));
    expect(find.descendant(of: anna, matching: find.text('Leo Tolstoy')), findsOneWidget);
    expect(find.descendant(of: anna, matching: find.text('42%')), findsOneWidget);

    final notes = find.ancestor(
        of: find.text('Untitled notes').first, matching: find.byType(BookTile));
    expect(find.descendant(of: notes, matching: find.text('New')), findsOneWidget);
    // No cover: the placeholder repeats the title on the card (FR-012).
    expect(find.descendant(of: notes, matching: find.byType(CoverPlaceholder)), findsOneWidget);

    await app.dispose(tester);
  });

  testWidgets('each tile has one screen-reader label', (tester) async {
    final app = TestApp();
    await app.pump(tester);
    await seedBook(tester, app.db, id: 'a', title: 'Emma', author: 'Jane Austen', currentPage: 1);
    await seedBook(tester, app.db, id: 'b', title: 'Persuasion');

    expect(find.bySemanticsLabel('Emma, by Jane Austen, 0%'), findsOneWidget);
    expect(find.bySemanticsLabel('Persuasion, New'), findsOneWidget);

    await app.dispose(tester);
  });

  testWidgets('a newly inserted book appears without a refresh (FR-015)', (tester) async {
    final app = TestApp();
    await app.pump(tester);
    expect(find.byType(BookTile), findsNothing);

    await seedBook(tester, app.db, id: 'new', title: 'Middlemarch');
    expect(find.text('Middlemarch'), findsWidgets);

    await app.dispose(tester);
  });

  testWidgets('the menu opens About Potha with the licences (003 FR-034)', (tester) async {
    final app = TestApp();
    await app.pump(tester);
    await tester.tap(find.byTooltip('More'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('About Potha'));
    await tester.pumpAndSettle();
    expect(find.byType(LicensePage), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();
    await app.dispose(tester);
  });
}
