// User Story 4: zoom (FR-016, FR-018, FR-021).
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:potha/core/db/app_database.dart';
import 'package:potha/features/reader/data/reader_repository.dart';

import 'reader_test_app.dart';
import 'test_app.dart';

void main() {
  for (final platform in [TargetPlatform.android, TargetPlatform.linux]) {
    testWidgets('zoom buttons are in the bottom bar on ${platform.name} (FR-016)',
        (tester) async {
      debugDefaultTargetPlatformOverride = platform;
      final (app, view) = await openReader(tester, FakeReaderDocument());
      await tapView(tester, 0.5);
      await tester.tap(find.byTooltip('Zoom in'));
      await tester.tap(find.byTooltip('Zoom in'));
      await tester.tap(find.byTooltip('Zoom out'));
      expect(view.controller.calls.where((c) => c.startsWith('zoom')),
          ['zoomIn', 'zoomIn', 'zoomOut']);
      debugDefaultTargetPlatformOverride = null;
      await closeReader(tester, app);
    });
  }

  testWidgets('Ctrl + = and Ctrl + - zoom (FR-016)', (tester) async {
    final (app, view) = await openReader(tester, FakeReaderDocument());
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.equal);
    await tester.sendKeyEvent(LogicalKeyboardKey.minus);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    expect(view.controller.calls.where((c) => c.startsWith('zoom')), ['zoomIn', 'zoomOut']);
    await closeReader(tester, app);
  });

  testWidgets('fit page applies to all books and is saved (FR-021)', (tester) async {
    final (app, view) = await openReader(tester, FakeReaderDocument());
    expect(view.controller.config!.fit, PageFit.fitWidth);
    await tapView(tester, 0.5);
    await tester.tap(find.byTooltip('Reader settings'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Fit page'));
    await tester.pump();
    await settleReal(tester);
    expect(view.controller.config!.fit, PageFit.fitPage);
    final prefs = await tester.runAsync(() => ReaderRepository(app.db).watchPreferences().first);
    expect(prefs!.fit, PageFit.fitPage);
    await closeReader(tester, app);
  });
}
