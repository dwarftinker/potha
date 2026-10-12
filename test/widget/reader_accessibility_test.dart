// FR-040 / constitution VII: the reader's controls are labelled, large enough, readable
// in every theme, and fit at 2× text size.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:potha/core/db/app_database.dart';
import 'package:potha/features/reader/data/reader_repository.dart';

import 'reader_test_app.dart';
import 'test_app.dart';

void main() {
  for (final theme in ReadingTheme.values) {
    testWidgets('${theme.name}: controls meet label, tap-target and contrast guidelines',
        (tester) async {
      final handle = tester.ensureSemantics();
      final (app, _) = await openReader(tester, FakeReaderDocument(), before: (app) async {
        await tester.runAsync(() => ReaderRepository(app.db).setTheme(theme));
      });
      await settleReal(tester);
      await tapView(tester, 0.5);
      await tester.pump(const Duration(milliseconds: 300));
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(textContrastGuideline));
      handle.dispose();
      await closeReader(tester, app);
    });
  }

  testWidgets('the bars fit a phone at 2× text size', (tester) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 2.75;
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(() {
      tester.view.reset();
      tester.platformDispatcher.clearTextScaleFactorTestValue();
    });
    final (app, _) = await openReader(tester, FakeReaderDocument());
    await tapView(tester, 0.5);
    await tester.pump(const Duration(milliseconds: 300));
    expect(tester.takeException(), isNull); // no RenderFlex overflow
    expect(find.text('Page 1 of 300'), findsOneWidget);
    await closeReader(tester, app);
  });
}
