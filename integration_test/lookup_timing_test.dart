// 003 SC-002: a definition appears within 300 ms of the gesture (p95), on the Galaxy S24
// in profile mode, with the full dictionary built into the app:
//   flutter drive --profile --no-dds --driver=test_driver/perf_driver.dart \
//     --target=integration_test/lookup_timing_test.dart -d <device>
// Twenty words on different pages; half are pressed before the page's text is cached.
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:potha/core/dictionary/dictionary_store.dart';
import 'package:potha/core/document/document_format.dart';
import 'package:potha/core/document/pdf/pdf_document_format.dart';
import 'package:potha/features/reader/ui/lookup_panel.dart';
import 'package:potha/main.dart' as app;

import 'helpers.dart';

/// TapDetector's long-press threshold.
const longPressMs = 500;

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;

  testWidgets('a long-pressed word shows its definition within 300 ms (SC-002)', (tester) async {
    await app.main();
    await tester.pumpAndSettle();
    final title = 'Lookup timing ${DateTime.now().microsecondsSinceEpoch}';
    final bytes = buildReaderPdf([for (var i = 1; i <= 30; i++) TestPage(lines: proseLines(i))]);
    await importBook(tester, title, bytes);

    // The dictionary must be unpacked first (once per install; measured in T083).
    final store = containerOf(tester).read(dictionaryStoreProvider)..ensureStarted();
    await tester.runAsync(() => store.ready.timeout(const Duration(minutes: 2)));

    // Word positions from a separate copy of the book, so the reader's page-text cache
    // stays cold for the pages pressed without waiting.
    final copy = (await tester.runAsync(
      () => const PdfDocumentFormat().open(
        BookFileRef(readAll: () async => bytes, sizeBytes: bytes.length),
      ),
    ))!;
    Future<Offset> wordOn(int page) async {
      final text = (await tester.runAsync(() => copy.loadPageText(page)))!;
      final i = text.text.indexOf('calm');
      final at = i >= 0 ? i + 1 : text.text.indexOf('sea') + 1;
      return text.charRects[at].center;
    }

    final view = await openBook(tester, title);
    final times = <int>[];
    for (var n = 0; n < 20; n++) {
      final page = 2 + n;
      view.goTo(ReadingPosition(page, 0), animate: false);
      final cached = n.isEven;
      // Cached: let the reader prefetch (the view is still for 300 ms). Not cached:
      // press at once.
      await settleFor(tester, Duration(milliseconds: cached ? 700 : 120));
      final at = globalOnPage(view, page, await wordOn(page));
      // Timed from the finger going down, polling every frame; the long-press is
      // recognised 500 ms later (TapDetector), so that is subtracted.
      final watch = Stopwatch()..start();
      final gesture = await tester.startGesture(at);
      bool shown() => find
          .descendant(of: find.byKey(lookupPanelKey), matching: find.textContaining('1. '))
          .evaluate()
          .isNotEmpty;
      while (!shown()) {
        if (watch.elapsed > const Duration(seconds: 20)) fail('no definition on page $page');
        await tester.pump();
      }
      expect(view.interactionLock.value, isTrue, reason: 'locked by the long-press');
      times.add(watch.elapsedMilliseconds - longPressMs);
      await gesture.up();
      await systemBack(tester); // closes the panel
    }
    await tester.runAsync(copy.close);

    final sorted = [...times]..sort();
    final p50 = sorted[sorted.length ~/ 2];
    final p95 = sorted[(sorted.length * 0.95).ceil() - 1];
    // ignore: avoid_print
    print('lookup: $times ms; p50 $p50 ms, p95 $p95 ms (SC-002 p95 <= 300)');
    binding.reportData = {
      'lookup_timing': {'times_ms': times, 'p50_ms': p50, 'p95_ms': p95},
    };
    expect(p95, lessThanOrEqualTo(300));
    await systemBack(tester);
  });
}
