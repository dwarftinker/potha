// Feature 002 on a device or in Chrome, with real pdfrx (T070):
//   flutter test integration_test/reader_flow_test.dart -d <device>
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:potha/core/db/app_database.dart';
import 'package:potha/core/document/reading_position.dart';
import 'package:potha/main.dart' as app;

import 'helpers.dart';

/// 12 pages with an outline, a link on page 1 to page 9, a web link on page 2 and
/// "whale" on pages 4 and 11.
List<TestPage> _book() => [
      for (var i = 1; i <= 12; i++)
        TestPage(
          lines: ['Page $i', ...proseLines(i, extra: i == 4 || i == 11 ? 'a whale rose' : null)],
          linkTo: i == 1 ? 9 : null,
          webLink: i == 2 ? 'https://example.org/potha' : null,
        ),
    ];

const _outline = [
  ('Chapter One', 1, [('Section 1.1', 2), ('Section 1.2', 3)]),
  ('Chapter Two', 5, [('Section 2.1', 6)]),
  ('Chapter Three', 9, <(String, int)>[]),
];

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  Future<void> showControls(WidgetTester tester) async {
    // Let any page animation finish: a tap while the page moves is not a tap.
    await settleFor(tester, const Duration(milliseconds: 500));
    final controls = find.byKey(const ValueKey('reader-controls'));
    if (!tester.widget<IgnorePointer>(controls).ignoring) return;
    final size = tester.getSize(find.byType(Scaffold).last);
    await tester.tapAt(Offset(size.width / 2, size.height / 2));
    await settleFor(tester, const Duration(milliseconds: 300));
  }

  testWidgets('read, turn, zoom, jump, go back, search and resume', (tester) async {
    await app.main();
    await tester.pumpAndSettle();
    final title = 'Flow ${DateTime.now().microsecondsSinceEpoch}';
    await importBook(tester, title, buildReaderPdf(_book(), outline: _outline));
    var view = await openBook(tester, title);
    final size = tester.getSize(find.byType(Scaffold).last);

    // Paged by default (FR-009): a swipe and edge taps turn one page each.
    expect(view.mode, PageMode.paged);
    await tester.flingFrom(Offset(size.width * 0.7, size.height / 2), Offset(-size.width / 2, 0),
        2000);
    await pumpUntilTrue(tester, () => view.position.page == 2, reason: 'swipe to page 2');
    await tester.tapAt(Offset(size.width * 0.95, size.height / 2));
    await pumpUntilTrue(tester, () => view.position.page == 3, reason: 'edge tap to 3');
    await tester.tapAt(Offset(size.width * 0.05, size.height / 2));
    await pumpUntilTrue(tester, () => view.position.page == 2, reason: 'edge tap back to 2');

    // Zoom with the buttons; the next page keeps the zoom (FR-016, FR-021).
    await showControls(tester);
    await tester.tap(find.byTooltip('Zoom in'));
    await settleFor(tester, const Duration(milliseconds: 500));
    expect(view.zoom, greaterThan(1.1));
    view.next();
    await pumpUntilTrue(tester, () => view.position.page == 3, reason: 'zoomed turn');
    expect(view.zoom, greaterThan(1.1));
    await showControls(tester);
    await tester.tap(find.byTooltip('Zoom out'));
    await settleFor(tester, const Duration(milliseconds: 500));
    expect(view.zoom, closeTo(1, 0.01));

    // Contents, then Back to page N (FR-024, FR-026).
    await showControls(tester);
    await tester.tap(find.byTooltip('Table of contents'));
    await settleFor(tester, const Duration(milliseconds: 600));
    await tester.tap(find.text('Chapter Three'));
    await pumpUntilTrue(tester, () => view.position.page == 9, reason: 'contents jump');
    await settleFor(tester, const Duration(milliseconds: 500));
    await tester.tap(find.text('Back to page 3'));
    await pumpUntilTrue(tester, () => view.position.page == 3, reason: 'back step');

    // A link on page 1 (FR-025).
    view.goTo(const ReadingPosition(1, 0), animate: false);
    await settleFor(tester, const Duration(milliseconds: 500));
    // testLinkRect is in PDF points on a 612 x 792 page.
    final link = globalOnPage(view, 1, const Offset(186 / 612, (792 - 620) / 792));
    await tester.tapAt(link);
    await pumpUntilTrue(tester, () => view.position.page == 9, reason: 'link to page 9');
    await settleFor(tester, const Duration(milliseconds: 500));

    // Continuous mode keeps the place (FR-015).
    await showControls(tester);
    await tester.tap(find.byTooltip('Reader settings'));
    await settleFor(tester, const Duration(milliseconds: 600));
    await tester.tap(find.text('Continuous'));
    await settleFor(tester, const Duration(milliseconds: 800));
    await tester.tapAt(const Offset(10, 10)); // close the sheet
    await settleFor(tester, const Duration(milliseconds: 500));
    expect(view.mode, PageMode.continuous);
    expect(view.position.page, 9);

    // Search (FR-030 to FR-032).
    await showControls(tester);
    await tester.tap(find.byTooltip('Search in book'));
    await settleFor(tester, const Duration(milliseconds: 600));
    useTestTextInput(tester);
    await tester.enterText(find.byType(TextField), 'WHALE');
    await pumpUntil(tester, find.text('2 matches'));
    await tester.tap(find.text('Page 11'));
    await pumpUntilTrue(tester, () => view.position.page == 11, reason: 'search jump');
    await settleFor(tester, const Duration(milliseconds: 500));
    // Search starts at the current page (9) and wraps, so page 11 is the first match.
    expect(find.text('Match 1 of 2'), findsOneWidget);
    await tester.tap(find.byTooltip('Close search'));
    await settleFor(tester, const Duration(milliseconds: 300));

    // Rotation keeps the place (FR-015).
    final before = view.position;
    final portrait = tester.view.physicalSize;
    tester.view.physicalSize = Size(portrait.height, portrait.width);
    await settleFor(tester, const Duration(milliseconds: 800));
    expect(view.position.page, before.page);
    tester.view.resetPhysicalSize();
    await settleFor(tester, const Duration(milliseconds: 800));

    // Leave and reopen: same page and place (FR-011, FR-012).
    view.goTo(const ReadingPosition(7, 0.4), animate: false);
    await settleFor(tester, const Duration(milliseconds: 500));
    final left = view.position;
    await systemBack(tester);
    await settleFor(tester, const Duration(seconds: 1));
    view = await openBook(tester, title);
    expect(view.position.page, left.page);
    expect(view.position.offsetY, closeTo(left.offsetY, 0.02));
    expect(view.mode, PageMode.continuous);
    await systemBack(tester);
    await settleFor(tester, const Duration(seconds: 1));
  });

  testWidgets('20 books resume on the right page and place (SC-005)', (tester) async {
    await app.main();
    await tester.pumpAndSettle();
    final stamp = DateTime.now().microsecondsSinceEpoch;
    final bytes = buildReaderPdf([for (var i = 1; i <= 30; i++) TestPage(lines: proseLines(i))]);
    var correct = 0;
    for (var b = 0; b < 20; b++) {
      final title = 'Resume $stamp $b';
      // Each book is a different file (duplicates are refused), so vary one byte at the end.
      await importBook(tester, title, Uint8List.fromList([...bytes, 0x0A, ...'%$b'.codeUnits]));
      var view = await openBook(tester, title);
      final target = ReadingPosition(1 + (b * 7) % 30, (b % 5) / 5);
      view.goTo(target, animate: false);
      await settleFor(tester, const Duration(milliseconds: 400));
      final left = view.position;
      await systemBack(tester);
      await settleFor(tester, const Duration(milliseconds: 600));
      view = await openBook(tester, title);
      if (view.position.page == left.page && (view.position.offsetY - left.offsetY).abs() < 0.02) {
        correct++;
      }
      await systemBack(tester);
      await settleFor(tester, const Duration(milliseconds: 600));
    }
    // ignore: avoid_print
    print('resume: $correct of 20 correct');
    expect(correct, 20);
  });

  testWidgets('a damaged page does not stop the book (FR-037)', (tester) async {
    await app.main();
    await tester.pumpAndSettle();
    final title = 'Damaged ${DateTime.now().microsecondsSinceEpoch}';
    await importBook(
        tester,
        title,
        buildReaderPdf([
          for (var i = 1; i <= 5; i++) TestPage(lines: ['Page $i'], broken: i == 3),
        ]));
    final view = await openBook(tester, title);
    for (var p = 2; p <= 5; p++) {
      view.next();
      await pumpUntilTrue(tester, () => view.position.page == p, reason: 'page $p');
    }
    expect(tester.takeException(), isNull);
    await systemBack(tester);
  });
}
