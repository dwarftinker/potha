// User Story 7: search in the book (FR-030 to FR-034).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:potha/core/document/document_format.dart';

import 'reader_test_app.dart';
import 'test_app.dart';

void main() {
  FakeReaderDocument book() => FakeReaderDocument(pageCount: 10, texts: {
        3: 'Call me Ishmael. A whale was seen.',
        7: 'The white whale and another whale.',
      });

  Future<void> openSearch(WidgetTester tester) async {
    await tapView(tester, 0.5);
    await tester.pump(const Duration(milliseconds: 200));
    await tester.tap(find.byTooltip('Search in book'));
    await tester.pumpAndSettle();
  }

  Future<void> type(WidgetTester tester, String text) async {
    await tester.enterText(find.byType(TextField), text);
    await tester.pump(const Duration(milliseconds: 400)); // typing pause
    await settleReal(tester);
    await tester.pump();
  }

  testWidgets('results stream in with page numbers and text around them (FR-031)',
      (tester) async {
    final (app, _) = await openReader(tester, book());
    await openSearch(tester);
    await type(tester, 'WHALE');
    expect(find.text('Page 3'), findsOneWidget);
    expect(find.text('Page 7'), findsNWidgets(2));
    expect(find.textContaining('A whale was seen', findRichText: true), findsOneWidget);
    expect(find.text('3 matches'), findsOneWidget);
    await closeReader(tester, app);
  });

  testWidgets('choosing a result jumps and highlights; Next and Previous step (FR-032)',
      (tester) async {
    final (app, view) = await openReader(tester, book());
    final c = view.controller;
    await openSearch(tester);
    await type(tester, 'whale');
    await tester.tap(find.text('Page 7').first);
    await tester.pumpAndSettle();
    expect(c.goTos.last.page, 7);
    expect(find.text('Back to page 1'), findsOneWidget);
    expect(find.text('Match 2 of 3'), findsOneWidget);
    final highlights = c.config!.highlights;
    expect(highlights.where((h) => h.active).single.page, 7);
    expect(highlights.map((h) => h.page).toSet(), {3, 7});

    await tester.tap(find.byTooltip('Next match'));
    await tester.pump();
    expect(find.text('Match 3 of 3'), findsOneWidget);
    await tester.tap(find.byTooltip('Next match'));
    await tester.pump();
    expect(find.text('Match 1 of 3'), findsOneWidget);
    expect(c.goTos.last.page, 3);
    await tester.tap(find.byTooltip('Previous match'));
    await tester.pump();
    expect(find.text('Match 3 of 3'), findsOneWidget);

    await tester.tap(find.byTooltip('Close search'));
    await tester.pump();
    expect(find.textContaining('Match'), findsNothing);
    expect(c.config!.highlights, isEmpty);
    await closeReader(tester, app);
  });

  testWidgets('no matches says so; a new query replaces the old one (FR-033)', (tester) async {
    final (app, _) = await openReader(tester, book());
    await openSearch(tester);
    await type(tester, 'whale');
    expect(find.text('3 matches'), findsOneWidget);
    await type(tester, 'kraken');
    expect(find.text('No matches.'), findsOneWidget);
    expect(find.text('Page 7'), findsNothing);
    await closeReader(tester, app);
  });

  testWidgets('a book with no text says so, and can be searched anyway (FR-034)',
      (tester) async {
    final (app, _) = await openReader(tester, FakeReaderDocument(pageCount: 40));
    await openSearch(tester);
    await settleReal(tester);
    await tester.pump();
    expect(find.text('This book has no searchable text.'), findsOneWidget);
    await tester.tap(find.text('Search anyway'));
    await tester.pump();
    await type(tester, 'whale');
    expect(find.text('This book has no searchable text.'), findsOneWidget);
    await closeReader(tester, app);
  });

  testWidgets('keys type into the search field instead of turning pages', (tester) async {
    final (app, view) = await openReader(tester, book());
    await openSearch(tester);
    view.controller.calls.clear();
    await tester.showKeyboard(find.byType(TextField));
    await tester.enterText(find.byType(TextField), 'a b');
    expect(view.controller.calls.where((x) => x == 'next'), isEmpty);
    await closeReader(tester, app);
  });
}
