import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:potha/core/db/app_database.dart';
import 'package:potha/features/library/ui/book_tile.dart';

import 'test_app.dart';

List<String> visibleTitles(WidgetTester tester) => tester
    .widgetList<BookTile>(find.byType(BookTile))
    .map((t) => t.book.title)
    .toList();

Future<void> seedThree(WidgetTester tester, TestApp app) async {
  await seedBook(tester, app.db,
      id: 'w', title: 'War and Peace', author: 'Leo Tolstoy', addedAt: DateTime.utc(2026, 10, 3));
  await seedBook(tester, app.db,
      id: 'i', title: 'The Idiot', author: 'Fyodor Dostoevsky', addedAt: DateTime.utc(2026, 10, 1));
  await seedBook(tester, app.db, id: 'a', title: 'Anna Karenina', author: 'Lev Tolstóy',
      addedAt: DateTime.utc(2026, 10, 2));
}

Future<void> search(WidgetTester tester, String text) async {
  await tester.enterText(find.byType(TextField), text);
  await tester.pump(const Duration(milliseconds: 200)); // debounce
  await settleReal(tester);
}

void main() {
  testWidgets('typing filters the library as you type (FR-018)', (tester) async {
    final app = TestApp();
    await app.pump(tester);
    await seedThree(tester, app);

    await tester.tap(find.byTooltip('Search library'));
    await tester.pump();
    await search(tester, 'tolst');
    expect(visibleTitles(tester).toSet(), {'War and Peace', 'Anna Karenina'});

    await search(tester, 'idiot');
    expect(visibleTitles(tester), ['The Idiot']);

    await app.dispose(tester);
  });

  testWidgets('no matches shows a message with Clear search', (tester) async {
    final app = TestApp();
    await app.pump(tester);
    await seedThree(tester, app);

    await tester.tap(find.byTooltip('Search library'));
    await tester.pump();
    await search(tester, 'zzz');
    expect(find.text('No books match “zzz”'), findsOneWidget);
    expect(find.textContaining('Your library is empty'), findsNothing);

    await tester.tap(find.text('Clear search'));
    await tester.pump(const Duration(milliseconds: 200));
    await settleReal(tester);
    expect(visibleTitles(tester), hasLength(3));

    await app.dispose(tester);
  });

  testWidgets('the sort menu changes the order and is remembered (FR-017, FR-019)',
      (tester) async {
    final app = TestApp();
    await app.pump(tester);
    await seedThree(tester, app);
    expect(visibleTitles(tester), ['War and Peace', 'Anna Karenina', 'The Idiot']);

    await tester.tap(find.byTooltip('Sort'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Title').last);
    await tester.pumpAndSettle();
    await settleReal(tester);
    expect(visibleTitles(tester), ['Anna Karenina', 'The Idiot', 'War and Peace']);

    final prefs = await tester.runAsync(() => app.db.select(app.db.libraryPreferences).getSingle());
    expect(prefs!.sortOrder, SortOrder.title);

    await app.dispose(tester);
  });
}
