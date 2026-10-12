import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:potha/core/db/app_database.dart';
import 'package:potha/features/library/ui/book_row.dart';
import 'package:potha/features/library/ui/book_tile.dart';

import 'test_app.dart';

void main() {
  testWidgets('the toggle switches between grid and list (FR-022)', (tester) async {
    final app = TestApp();
    await app.pump(tester);
    await seedBook(tester, app.db,
        id: 'e', title: 'Emma', author: 'Jane Austen', cover: true, currentPage: 150);

    expect(find.byType(BookTile), findsOneWidget);
    await tester.tap(find.byTooltip('Show as list'));
    await settleReal(tester);

    expect(find.byType(BookTile), findsNothing);
    final row = find.byType(BookRow);
    expect(row, findsOneWidget);
    expect(find.descendant(of: row, matching: find.text('Emma')), findsOneWidget);
    expect(find.descendant(of: row, matching: find.text('Jane Austen')), findsOneWidget);
    expect(find.descendant(of: row, matching: find.text('50%')), findsOneWidget);
    expect(find.bySemanticsLabel('Emma, by Jane Austen, 50%'), findsOneWidget);

    await tester.tap(find.byTooltip('Show as grid'));
    await settleReal(tester);
    expect(find.byType(BookTile), findsOneWidget);

    await app.dispose(tester);
  });

  testWidgets('the choice is remembered (FR-019)', (tester) async {
    final app = TestApp();
    await app.pump(tester);
    await seedBook(tester, app.db, id: 'e', title: 'Emma');
    await tester.tap(find.byTooltip('Show as list'));
    await settleReal(tester);

    final prefs = await tester.runAsync(() => app.db.select(app.db.libraryPreferences).getSingle());
    expect(prefs!.viewMode, ViewMode.list);

    // A fresh screen reads it back.
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpWidget(app.widget);
    await settleReal(tester);
    expect(find.byType(BookRow), findsOneWidget);

    await app.dispose(tester);
  });
}
