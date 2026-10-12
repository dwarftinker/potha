// SC-003 / SC-004 on a mid-range Android phone, in profile mode:
//   flutter drive --profile --driver=test_driver/perf_driver.dart \
//     --target=integration_test/scroll_perf_test.dart -d <device>
// or quickly (debug timings): flutter test integration_test/scroll_perf_test.dart -d <device>
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:potha/app.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:potha/core/db/connection.dart';
import 'package:potha/features/library/import/import_controller.dart';
import 'package:potha/features/library/ui/library_screen.dart';

import 'seed_500_books.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  // Render every vsync like the real app; by default frames are drawn only when the
  // test pumps (every 100 ms in pumpAndSettle), so each frame would jump a whole row.
  binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;

  testWidgets(
    'scrolling 500 books stays smooth and search is fast',
    (tester) async {
      final db = await seededDatabase(500);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appDatabaseProvider.overrideWithValue(db),
            incomingFilesEnabledProvider.overrideWithValue(false),
            isWebProvider.overrideWithValue(false),
          ],
          child: const PothaApp(),
        ),
      );
      await tester.pumpAndSettle();

      Future<void> flingThrough(Finder scrollable) async {
        for (var i = 0; i < 6; i++) {
          await tester.fling(scrollable, const Offset(0, -1500), 4000);
          await tester.pumpAndSettle();
        }
        for (var i = 0; i < 6; i++) {
          await tester.fling(scrollable, const Offset(0, 1500), 4000);
          await tester.pumpAndSettle();
        }
      }

      // Grid, then list (SC-003).
      await binding.traceAction(
        () => flingThrough(find.byType(GridView)),
        reportKey: 'grid_scroll',
      );
      await tester.tap(find.byTooltip('Show as list'));
      await tester.pumpAndSettle();
      await binding.traceAction(
        () => flingThrough(find.byType(ListView)),
        reportKey: 'list_scroll',
      );

      // Search updates within 0.5 s of a keystroke (SC-004). On a device the integration
      // binding leaves typing to the real keyboard, so use the test text input here.
      tester.testTextInput.register();
      await tester.tap(find.byTooltip('Search library'));
      await tester.pumpAndSettle();
      final container = ProviderScope.containerOf(
        tester.element(find.byType(LibraryScreen)),
      );
      // "book 42" matches Book 42 and Book 420–429; not all of them fit on a phone
      // screen, so wait for the result list, then check the rows that are shown.
      final watch = Stopwatch()..start();
      await tester.enterText(find.byType(TextField), 'book 42');
      while (container.read(booksProvider).value?.length != 11) {
        await tester.pump(const Duration(milliseconds: 16));
        if (watch.elapsed > const Duration(seconds: 2)) break;
      }
      await tester.pump();
      watch.stop();
      expect(find.textContaining(RegExp(r'^Book 42')), findsWidgets);
      expect(find.textContaining(RegExp(r'^Book (?!42)')), findsNothing);
      tester.testTextInput.unregister();
      // ignore: avoid_print
      print('search: ${watch.elapsedMilliseconds} ms');
      expect(
        watch.elapsed,
        lessThan(const Duration(milliseconds: 500)),
        reason: 'Search took ${watch.elapsedMilliseconds} ms',
      );
    },
    // testWidgets turns semantics on by default; measure what most readers get.
    semanticsEnabled: false,
  );
}
