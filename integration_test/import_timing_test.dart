// SC-002: a ~20 MB PDF appears in the library within 3 s of starting the import.
// Run on a mid-range Android phone: flutter test integration_test/import_timing_test.dart -d <device>
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:potha/features/library/import/import_controller.dart';
import 'package:potha/main.dart' as app;

import 'helpers.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('a 20 MB PDF is in the library within 3 s', (tester) async {
    await app.main();
    await tester.pumpAndSettle();
    final title = 'Large ${DateTime.now().microsecondsSinceEpoch}';
    final pdf = buildPdf(title: title, pages: 20, imageBytesPerPage: 1 << 20);
    expect(pdf.length, greaterThan(20 * 1000 * 1000));

    final watch = Stopwatch()..start();
    await containerOf(tester).read(importControllerProvider.notifier).importSources(
        [sourceFromBytes('large.pdf', pdf)],
        askPassword: (_, {required retry}) async => null);
    await pumpUntil(tester, find.text(title), timeout: const Duration(seconds: 10));
    watch.stop();

    expect(watch.elapsed, lessThan(const Duration(seconds: 3)),
        reason: 'Import took ${watch.elapsedMilliseconds} ms');
  });
}
