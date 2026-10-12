// FR-025 / constitution VII: labels, tap targets, contrast and large text, in light
// and dark themes.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_app.dart';

Future<TestApp> pumpLibrary(WidgetTester tester, {required bool withBooks}) async {
  final app = TestApp();
  await app.pump(tester);
  if (withBooks) {
    await seedBook(tester, app.db,
        id: 'a', title: 'A Very Long Title That Wraps Over Several Lines In The Grid',
        author: 'An Author With A Long Name', currentPage: 10);
    await seedBook(tester, app.db, id: 'b', title: 'Emma', cover: true);
  }
  return app;
}

void main() {
  for (final brightness in Brightness.values) {
    group('${brightness.name} theme', () {

      for (final withBooks in [false, true]) {
        final label = withBooks ? 'library' : 'empty library';

        testWidgets('$label meets labelled tap target, size and contrast guidelines',
            (tester) async {
          tester.platformDispatcher.platformBrightnessTestValue = brightness;
          addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
          final handle = tester.ensureSemantics();
          final app = await pumpLibrary(tester, withBooks: withBooks);

          await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
          await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
          await expectLater(tester, meetsGuideline(textContrastGuideline));

          handle.dispose();
          await app.dispose(tester);
        });

        testWidgets('$label has no overflow at 2× text size', (tester) async {
          tester.platformDispatcher.platformBrightnessTestValue = brightness;
          tester.platformDispatcher.textScaleFactorTestValue = 2.0;
          addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
          addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
          tester.view.physicalSize = const Size(412 * 3, 860 * 3);
          tester.view.devicePixelRatio = 3;
          addTearDown(tester.view.reset);

          final app = await pumpLibrary(tester, withBooks: withBooks);
          expect(tester.takeException(), isNull);

          await app.dispose(tester);
        });
      }
    });
  }
}
