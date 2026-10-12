// User Story 6: reading themes and keeping the screen on (FR-027 to FR-029).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:potha/core/db/app_database.dart';
import 'package:potha/features/reader/data/reader_repository.dart';
import 'package:potha/features/reader/domain/reader_theme.dart';
import 'package:potha/features/reader/ui/reader_bars.dart';

import 'reader_test_app.dart';
import 'test_app.dart';

void main() {
  testWidgets('dark is saved for all books and recolours pages and bars (FR-027)',
      (tester) async {
    final (app, view) = await openReader(tester, FakeReaderDocument());
    expect(view.controller.config!.pageFilter, isNull);
    await tapView(tester, 0.5);
    await tester.tap(find.byTooltip('Reader settings'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Dark'));
    await tester.tap(find.text('Dark'));
    await tester.pump();
    await settleReal(tester);
    final dark = ReaderTheme.of(ReadingTheme.dark);
    final config = view.controller.config!;
    expect(config.pageFilter, dark.pageFilter);
    expect(config.backgroundColor, dark.background);
    expect(config.highlightColor, dark.highlightPaintColor);
    final prefs = await tester.runAsync(() => ReaderRepository(app.db).watchPreferences().first);
    expect(prefs!.theme, ReadingTheme.dark);

    // The bars follow the theme.
    Navigator.of(tester.element(find.text('Theme'))).pop();
    await tester.pumpAndSettle();
    final bar = tester.widget<Material>(find
        .descendant(of: find.byType(ReaderTopBar), matching: find.byType(Material))
        .first);
    expect(bar.color, dark.barBackground);
    await closeReader(tester, app);
  });

  testWidgets('a theme chosen earlier is used when a book opens (FR-027)', (tester) async {
    final (app, view) = await openReader(tester, FakeReaderDocument(), before: (app) async {
      await tester.runAsync(() => ReaderRepository(app.db).setTheme(ReadingTheme.sepia));
    });
    await settleReal(tester);
    expect(view.controller.config!.pageFilter, ReaderTheme.of(ReadingTheme.sepia).pageFilter);
    await closeReader(tester, app);
  });

  testWidgets('the screen stays on while a book is open (FR-029)', (tester) async {
    final (app, _) = await openReader(tester, FakeReaderDocument());
    expect(app.keepAwake.isOn, isTrue);
    await leaveReader(tester);
    expect(app.keepAwake.isOn, isFalse);
    await closeReader(tester, app);
  });

  testWidgets('not while the app is in the background (FR-029)', (tester) async {
    final (app, _) = await openReader(tester, FakeReaderDocument());
    for (final state in [AppLifecycleState.inactive, AppLifecycleState.hidden]) {
      tester.binding.handleAppLifecycleStateChanged(state);
    }
    await tester.pump();
    expect(app.keepAwake.isOn, isFalse);
    for (final state in [AppLifecycleState.inactive, AppLifecycleState.resumed]) {
      tester.binding.handleAppLifecycleStateChanged(state);
    }
    await tester.pump();
    expect(app.keepAwake.isOn, isTrue);
    await closeReader(tester, app);
  });
}
