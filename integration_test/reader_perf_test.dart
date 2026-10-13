// 002 SC-002, SC-003, SC-004 on a mid-range Android phone, in profile mode:
//   flutter drive --profile --no-dds --driver=test_driver/perf_driver.dart \
//     --target=integration_test/reader_perf_test.dart -d <device>
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:potha/core/document/pdf/pdf_document_view.dart';
import 'package:potha/main.dart' as app;

import 'helpers.dart';

int _p90(List<int> ms) => (ms..sort())[(ms.length * 0.9).floor().clamp(0, ms.length - 1)];

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  // Render every vsync like the real app (see scroll_perf_test.dart).
  binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;

  testWidgets(
    'page turns and scrolling stay smooth; pages and zoom turn sharp quickly',
    (tester) async {
      await app.main();
      await tester.pumpAndSettle();
      final title = 'Perf ${DateTime.now().microsecondsSinceEpoch}';
      await importBook(
          tester, title, buildReaderPdf([for (var i = 1; i <= 60; i++) TestPage(lines: proseLines(i))]));
      final view = await openBook(tester, title);
      final size = tester.getSize(find.byType(Scaffold).last);

      // SC-003: 50 page turns in paged mode, by swipe.
      await binding.traceAction(() async {
        for (var i = 0; i < 50; i++) {
          await tester.flingFrom(
              Offset(size.width * 0.8, size.height / 2), Offset(-size.width * 0.5, 0), 2500);
          await settleFor(tester, const Duration(milliseconds: 350));
        }
      }, reportKey: 'paged_turns');
      expect(view.position.page, greaterThan(40));

      // SC-003: continuous scrolling over the book.
      await tester.tap(find.byType(PdfDocumentView)); // show the controls
      await settleFor(tester, const Duration(milliseconds: 300));
      await tester.tap(find.byTooltip('Reader settings'));
      await settleFor(tester, const Duration(milliseconds: 600));
      await tester.tap(find.text('Continuous'));
      await settleFor(tester, const Duration(milliseconds: 600));
      await tester.tapAt(const Offset(10, 10));
      await settleFor(tester, const Duration(milliseconds: 600));
      await binding.traceAction(() async {
        for (var i = 0; i < 8; i++) {
          await tester.flingFrom(Offset(size.width / 2, size.height * 0.7),
              Offset(0, i < 4 ? size.height * 0.5 : -size.height * 0.5), 4000);
          await settleFor(tester, const Duration(milliseconds: 800));
        }
      }, reportKey: 'continuous_scroll');

      // SC-002 and SC-004: how long PDFium takes to draw a page sharp at screen size,
      // and at 2x zoom (what the viewer redraws after a turn and after a zoom).
      final doc = tester.widget<PdfDocumentView>(find.byType(PdfDocumentView)).document;
      final px = (size.width * tester.view.devicePixelRatio).round();
      final turn = <int>[], zoom = <int>[];
      await tester.runAsync(() async {
        for (var p = 10; p < 30; p++) {
          final w = Stopwatch()..start();
          (await doc.renderPageImage(p, width: px))?.dispose();
          turn.add(w.elapsedMilliseconds);
          final z = Stopwatch()..start();
          (await doc.renderPageImage(p, width: px * 2))?.dispose();
          zoom.add(z.elapsedMilliseconds);
        }
      });
      // ignore: avoid_print
      print('page render p90: ${_p90(turn)} ms (SC-002 < 200); '
          '2x zoom render p90: ${_p90(zoom)} ms (SC-004 < 500)');
      expect(_p90(turn), lessThan(200));
      expect(_p90(zoom), lessThan(500));
    },
    semanticsEnabled: false,
  );
}
