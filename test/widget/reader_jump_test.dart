// User Story 5: jump to a place (FR-022 to FR-026).
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:potha/core/document/document_format.dart';
import 'package:potha/core/platform/link_opener.dart';
import 'package:potha/features/reader/ui/reader_screen.dart';

import 'reader_test_app.dart';
import 'test_app.dart';

class _Opener implements LinkOpener {
  final opened = <Uri>[];
  @override
  Future<bool> open(Uri uri) async {
    opened.add(uri);
    return true;
  }
}

void main() {
  Future<void> showControls(WidgetTester tester) async {
    await tapView(tester, 0.5);
    await tester.pump(const Duration(milliseconds: 200));
  }

  testWidgets('the slider jumps only on release (FR-022)', (tester) async {
    final (app, view) = await openReader(tester, FakeReaderDocument());
    final c = view.controller;
    await showControls(tester);
    final slider = find.byType(Slider);
    final g = await tester.startGesture(tester.getCenter(slider));
    await g.moveBy(const Offset(60, 0));
    await tester.pump();
    expect(c.goTos, isEmpty);
    await g.up();
    await tester.pump();
    expect(c.goTos, hasLength(1));
    expect(c.goTos.single.page, greaterThan(150));
    expect(find.text('Back to page 1'), findsOneWidget);
    await closeReader(tester, app);
  });

  testWidgets('Go to page accepts a page in range and explains the range (FR-023)',
      (tester) async {
    final (app, view) = await openReader(tester, FakeReaderDocument());
    await showControls(tester);
    await tester.tap(find.text('Page 1 of 300'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '0');
    await tester.tap(find.text('Go'));
    await tester.pump();
    expect(find.text('Enter a page from 1 to 300.'), findsOneWidget);
    await tester.enterText(find.byType(TextField), '120');
    await tester.tap(find.text('Go'));
    await tester.pumpAndSettle();
    expect(view.controller.goTos.last, const ReadingPosition(120, 0));
    expect(find.text('Back to page 1'), findsOneWidget);
    await closeReader(tester, app);
  });

  testWidgets('the contents list nests, marks the current chapter and jumps (FR-024)',
      (tester) async {
    final doc = FakeReaderDocument(outline: const [
      OutlineEntry(title: 'Chapter One', page: 1, children: [
        OutlineEntry(title: 'Section 1.1', page: 2),
      ]),
      OutlineEntry(title: 'Chapter Two', page: 5),
    ]);
    final (app, view) = await openReader(tester, doc);
    view.controller.emitPosition(const ReadingPosition(3, 0));
    await showControls(tester);
    await tester.tap(find.byTooltip('Table of contents'));
    await tester.pumpAndSettle();
    expect(find.text('Chapter One'), findsOneWidget);
    expect(find.text('Section 1.1'), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp('Section 1.1.*current chapter')), findsOneWidget);
    await tester.tap(find.text('Chapter Two'));
    await tester.pumpAndSettle();
    expect(view.controller.goTos.last, const ReadingPosition(5, 0));
    expect(find.text('Back to page 3'), findsOneWidget);
    await closeReader(tester, app);
  });

  testWidgets('a book without contents says so (FR-024)', (tester) async {
    final (app, _) = await openReader(tester, FakeReaderDocument());
    await showControls(tester);
    await tester.tap(find.byTooltip('Table of contents'));
    await tester.pumpAndSettle();
    expect(find.text('This book has no table of contents.'), findsOneWidget);
    await closeReader(tester, app);
  });

  testWidgets('a page link jumps; Back to page N returns exactly (FR-025, FR-026)',
      (tester) async {
    final doc = FakeReaderDocument(links: {
      1: const [PageLink(Rect.fromLTRB(0.3, 0.4, 0.7, 0.6), 9)],
    });
    final (app, view) = await openReader(tester, doc);
    final c = view.controller;
    c.emitPosition(const ReadingPosition(1, 0.2));
    await settleReal(tester);
    await tapView(tester, 0.5);
    expect(c.goTos.last, const ReadingPosition(9, 0));
    expect(find.text('Back to page 1'), findsOneWidget);
    await tester.tap(find.text('Back to page 1'));
    await tester.pump();
    expect(c.goTos.last, const ReadingPosition(1, 0.2));
    expect(find.text('Back to page 1'), findsNothing);
    await closeReader(tester, app);
  });

  testWidgets('a web link shows the address and opens only on confirmation (FR-025)',
      (tester) async {
    final opener = _Opener();
    final doc = FakeReaderDocument(links: {
      1: [WebLink(const Rect.fromLTRB(0.3, 0.4, 0.7, 0.6), Uri.parse('https://example.org/potha'))],
    });
    final view = FakeViewFactory();
    final app = await _openWith(tester, doc, view, opener);
    await settleReal(tester);
    await tapView(tester, 0.5);
    await tester.pumpAndSettle();
    expect(find.text('https://example.org/potha'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(opener.opened, isEmpty);

    await tapView(tester, 0.5);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    expect(opener.opened, [Uri.parse('https://example.org/potha')]);
    await closeReader(tester, app);
  });
}

Future<TestApp> _openWith(
    WidgetTester tester, FakeReaderDocument doc, FakeViewFactory view, LinkOpener opener) async {
  final app = TestApp(overrides: [
    ...readerOverrides(doc, view),
    linkOpenerProvider.overrideWithValue(opener),
  ]);
  await app.pump(tester);
  await seedBook(tester, app.db, id: 'b1', title: 'Moby-Dick', pageCount: doc.pageCount);
  final navigator = tester.state<NavigatorState>(find.byType(Navigator));
  navigator.push(MaterialPageRoute<void>(builder: (_) => const ReaderScreen(bookId: 'b1')));
  await settleReal(tester);
  await tester.pump(const Duration(milliseconds: 500));
  return app;
}
