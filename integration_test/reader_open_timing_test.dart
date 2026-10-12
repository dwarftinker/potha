// 002 SC-001, SC-006, SC-007 on a mid-range Android phone, in profile mode:
//   flutter drive --profile --no-dds --driver=test_driver/perf_driver.dart \
//     --target=integration_test/reader_open_timing_test.dart -d <device>
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:potha/core/document/pdf/pdf_document_view.dart';
import 'package:potha/core/document/reading_position.dart';
import 'package:potha/features/reader/domain/text_search.dart';
import 'package:potha/main.dart' as app;

import 'helpers.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;

  Future<int> timeReopen(WidgetTester tester, String title) async {
    // First open, so the book counts as previously opened; move into the book.
    var view = await openBook(tester, title);
    view.goTo(ReadingPosition(view.pdf.pageCount ~/ 2, 0.3), animate: false);
    await settleFor(tester, const Duration(milliseconds: 600));
    await tester.pageBack();
    await settleFor(tester, const Duration(seconds: 1));
    final watch = Stopwatch()..start();
    view = await openBookFast(tester, title);
    watch.stop();
    expect(view.position.page, view.pdf.pageCount ~/ 2);
    return watch.elapsedMilliseconds;
  }

  testWidgets(
    'reopening, jumping and searching are fast',
    (tester) async {
      await app.main();
      await tester.pumpAndSettle();
      final stamp = DateTime.now().microsecondsSinceEpoch;
      final short = 'Short $stamp', long = 'Long $stamp', text = 'Text $stamp';
      await importBook(
          tester, short, buildReaderPdf([for (var i = 1; i <= 20; i++) TestPage(lines: proseLines(i))]));
      await importBook(tester, long,
          buildReaderPdf([for (var i = 1; i <= 2000; i++) TestPage(lines: proseLines(i))]));
      await importBook(tester, text, buildReaderPdf([
        for (var i = 1; i <= 500; i++)
          TestPage(lines: proseLines(i, extra: i % 97 == 0 ? 'a whale rose' : null)),
      ]));

      // SC-001: a previously opened book shows its page in under 2 s.
      final shortMs = await timeReopen(tester, short);
      await tester.pageBack();
      await settleFor(tester, const Duration(seconds: 1));
      final longMs = await timeReopen(tester, long);
      // ignore: avoid_print
      print('reopen: 20 pages $shortMs ms, 2,000 pages $longMs ms (SC-001 < 2000)');
      expect(shortMs, lessThan(2000));
      expect(longMs, lessThan(2000));

      // SC-006: jumps in the 2,000-page book (slider, Go to page, contents and thumbnails
      // all end in the same goTo) show the page in under 1 s.
      final view = readerView(tester);
      final doc = tester.widget<PdfDocumentView>(find.byType(PdfDocumentView)).document;
      final jumps = <int>[];
      for (final page in [1500, 12, 1999, 640, 2000, 1]) {
        final w = Stopwatch()..start();
        view.goTo(ReadingPosition(page, 0));
        await pumpUntilTrue(tester, () => view.position.page == page, reason: 'jump to $page');
        await tester.runAsync(() async => (await doc.renderPageImage(page, width: 400))?.dispose());
        jumps.add(w.elapsedMilliseconds);
      }
      // ignore: avoid_print
      print('jumps: $jumps ms (SC-006 < 1000)');
      expect(jumps.every((ms) => ms < 1000), isTrue);
      await tester.pageBack();
      await settleFor(tester, const Duration(seconds: 1));

      // SC-007: first search results within 2 s, and reading stays smooth meanwhile.
      final textView = await openBook(tester, text);
      final textDoc = tester.widget<PdfDocumentView>(find.byType(PdfDocumentView)).document;
      final w = Stopwatch()..start();
      int? firstResultMs;
      final run = TextSearch(textDoc).start('whale', fromPage: 1);
      run.addListener(() {
        if (run.results.isNotEmpty) firstResultMs ??= w.elapsedMilliseconds;
      });
      final size = tester.getSize(find.byType(Scaffold).last);
      await binding.traceAction(() async {
        for (var i = 0; i < 8; i++) {
          await tester.flingFrom(
              Offset(size.width * 0.8, size.height / 2), Offset(-size.width * 0.5, 0), 2500);
          await settleFor(tester, const Duration(milliseconds: 300));
        }
      }, reportKey: 'turning_while_searching');
      await pumpUntilTrue(tester, () => firstResultMs != null, reason: 'first search result');
      // ignore: avoid_print
      print('first search result: $firstResultMs ms (SC-007 < 2000); '
          'page ${textView.position.page}');
      expect(firstResultMs, lessThan(2000));
      run.cancel();
    },
    semanticsEnabled: false,
    timeout: const Timeout(Duration(minutes: 10)),
  );
}
