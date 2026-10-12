// US3 (001) on a device: open a book, move to page 3, reopen, and check it resumes there
// and shows content within 2 s (constitution V).
//   flutter test integration_test/open_resume_test.dart -d <device>
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:potha/main.dart' as app;

import 'helpers.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('a book resumes at the page where the reader stopped', (tester) async {
    await app.main();
    await tester.pumpAndSettle();
    final title = 'Resume ${DateTime.now().microsecondsSinceEpoch}';
    await importBook(tester, title, buildPdf(title: title, pages: 3));

    // Open, move to the last page, go back.
    final view = await openBook(tester, title);
    view.next();
    await settleFor(tester, const Duration(milliseconds: 400));
    view.next();
    await pumpUntilTrue(tester, () => view.position.page == 3, reason: 'page 3');
    await tester.pageBack();
    await pumpUntil(tester, find.text('100%'));

    // Reopen: starts at page 3, with content inside 2 s.
    final watch = Stopwatch()..start();
    final reopened = await openBook(tester, title);
    watch.stop();
    expect(reopened.position.page, 3);
    // ignore: avoid_print
    print('reopen: ${watch.elapsedMilliseconds} ms');
    expect(watch.elapsed, lessThan(const Duration(seconds: 2)),
        reason: 'Opening took ${watch.elapsedMilliseconds} ms');
  });
}
