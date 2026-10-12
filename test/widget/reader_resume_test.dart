// User Story 3: resume where I left off (FR-011 to FR-015).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:potha/core/db/app_database.dart';
import 'package:potha/core/document/reading_position.dart';
import 'package:potha/features/reader/data/reader_repository.dart';

import 'reader_test_app.dart';
import 'test_app.dart';

void main() {
  Future<ReadingPosition?> saved(WidgetTester tester, TestApp app) =>
      tester.runAsync(() => ReaderRepository(app.db).loadPosition('b1')).then((p) => p);

  testWidgets('a new book opens on its first page (FR-012)', (tester) async {
    final (app, view) = await openReader(tester, FakeReaderDocument());
    expect(view.controller.config!.initialPosition, const ReadingPosition(1, 0));
    await closeReader(tester, app);
  });

  testWidgets('the saved position is where the view starts (FR-012)', (tester) async {
    final (app, view) = await openReader(tester, FakeReaderDocument(), before: (app) async {
      await tester.runAsync(
          () => ReaderRepository(app.db).savePosition('b1', const ReadingPosition(57, 0.5)));
    });
    expect(view.controller.config!.initialPosition, const ReadingPosition(57, 0.5));
    await closeReader(tester, app);
  });

  testWidgets('positions are saved within a second while reading (FR-011)', (tester) async {
    final (app, view) = await openReader(tester, FakeReaderDocument());
    view.controller.emitPosition(const ReadingPosition(12, 0.25));
    await tester.pump(const Duration(milliseconds: 1100));
    await settleReal(tester);
    expect(await saved(tester, app), const ReadingPosition(12, 0.25));
    await closeReader(tester, app);
  });

  testWidgets('leaving the reader saves at once (FR-011)', (tester) async {
    final (app, view) = await openReader(tester, FakeReaderDocument());
    await tester.pump(const Duration(seconds: 2));
    view.controller.emitPosition(const ReadingPosition(40, 0.6));
    // Well before the saver's 1 s timer: only disposing the reader can have saved.
    await leaveReader(tester);
    await settleReal(tester);
    expect(await saved(tester, app), const ReadingPosition(40, 0.6));
    await closeReader(tester, app);
  });

  testWidgets('the app going to the background saves at once (FR-011)', (tester) async {
    final (app, view) = await openReader(tester, FakeReaderDocument());
    await tester.pump(const Duration(seconds: 2));
    view.controller.emitPosition(const ReadingPosition(41, 0.1));
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump();
    await settleReal(tester);
    expect(await saved(tester, app), const ReadingPosition(41, 0.1));
    for (final state in [
      AppLifecycleState.hidden,
      AppLifecycleState.inactive,
      AppLifecycleState.resumed,
    ]) {
      tester.binding.handleAppLifecycleStateChanged(state);
    }
    await closeReader(tester, app);
  });

  testWidgets('a book last read in 001 opens on its page, in paged mode (FR-014)',
      (tester) async {
    final (app, view) = await openReader(tester, FakeReaderDocument(), currentPage: 12);
    expect(view.controller.config!.initialPosition, const ReadingPosition(12, 0));
    expect(view.controller.config!.mode, PageMode.paged);
    await closeReader(tester, app);
  });

  testWidgets('the library shows progress from the saved page (FR-013)', (tester) async {
    final (app, view) = await openReader(tester, FakeReaderDocument(pageCount: 100));
    view.controller.emitPosition(const ReadingPosition(57, 0.3));
    Navigator.of(tester.element(find.byKey(fakeViewKey))).pop();
    await tester.pump(const Duration(seconds: 1));
    await settleReal(tester);
    expect(find.text('57%'), findsOneWidget);
    await closeReader(tester, app);
  });

  testWidgets('a mode change updates the same view, which keeps its place (FR-015)',
      (tester) async {
    final (app, view) = await openReader(tester, FakeReaderDocument());
    final c = view.controller;
    c.emitPosition(const ReadingPosition(20, 0.4));
    await tester.pump();
    await tapView(tester, 0.5);
    await tester.tap(find.byTooltip('Reader settings'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continuous'));
    await tester.pump();
    await settleReal(tester);
    // Same controller, new config; the PDF view keeps the position itself (see
    // pdf_view_test.dart), and nothing here moves it.
    expect(view.controllers, hasLength(1));
    expect(c.config!.mode, PageMode.continuous);
    expect(c.goTos, isEmpty);
    await closeReader(tester, app);
  });
}
