// US3 on a device: open a book, move to page 3, reopen, and check it resumes there and
// shows content within 2 s (constitution V).
//   flutter test integration_test/open_resume_test.dart -d <device>
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:pdfrx/pdfrx.dart';
import 'package:potha/features/library/import/import_controller.dart';
import 'package:potha/main.dart' as app;

import 'helpers.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('a book resumes at the page where the reader stopped', (
    tester,
  ) async {
    await app.main();
    await tester.pumpAndSettle();
    final title = 'Resume ${DateTime.now().microsecondsSinceEpoch}';
    await containerOf(tester)
        .read(importControllerProvider.notifier)
        .importSources([
          sourceFromBytes('three.pdf', buildPdf(title: title, pages: 3)),
        ], askPassword: (_, {required retry}) async => null);
    await pumpUntil(tester, find.text(title));

    // Open, jump to the last page, go back.
    await tester.tap(find.text(title).first);
    await pumpUntil(tester, find.text('Page 1 of 3'));
    for (var i = 0; i < 5 && find.text('Page 3 of 3').evaluate().isEmpty; i++) {
      await tester.fling(find.byType(PdfViewer), const Offset(0, -2000), 3000);
      await tester.pump(const Duration(seconds: 1));
    }
    await pumpUntil(tester, find.text('Page 3 of 3'));
    await tester.pageBack();
    await pumpUntil(tester, find.text('100%'));

    // Reopen: starts at page 3, with content inside 2 s.
    final watch = Stopwatch()..start();
    await tester.tap(find.text(title).first);
    await pumpUntil(tester, find.text('Page 3 of 3'));
    await pumpUntil(tester, find.byType(PdfViewer));
    watch.stop();
    // ignore: avoid_print
    print('reopen: ${watch.elapsedMilliseconds} ms');
    expect(
      watch.elapsed,
      lessThan(const Duration(seconds: 2)),
      reason: 'Opening took ${watch.elapsedMilliseconds} ms',
    );
    expect(find.byType(Scaffold), findsWidgets);
  });
}
