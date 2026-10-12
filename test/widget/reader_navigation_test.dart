// User Story 2: move through the book (FR-005 to FR-010, FR-040).
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:potha/core/db/app_database.dart';
import 'package:potha/features/reader/data/reader_repository.dart';

import 'reader_test_app.dart';
import 'test_app.dart';

void main() {
  testWidgets('edge taps go back and forward (FR-007)', (tester) async {
    final (app, view) = await openReader(tester, FakeReaderDocument());
    final c = view.controller;
    await tapView(tester, 0.95);
    await tapView(tester, 0.95);
    await tapView(tester, 0.05);
    expect(c.calls.where((x) => x == 'next' || x == 'previous'), ['next', 'next', 'previous']);
    expect(find.textContaining('View page 2'), findsOneWidget);
    await closeReader(tester, app);
  });

  testWidgets('keys move through the book (FR-008)', (tester) async {
    final (app, view) = await openReader(tester, FakeReaderDocument());
    final c = view.controller;
    c.calls.clear();
    for (final key in [
      LogicalKeyboardKey.arrowRight,
      LogicalKeyboardKey.pageDown,
      LogicalKeyboardKey.space,
      LogicalKeyboardKey.arrowLeft,
      LogicalKeyboardKey.pageUp,
    ]) {
      await tester.sendKeyEvent(key);
    }
    await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
    expect(c.calls, ['next', 'next', 'next', 'previous', 'previous', 'previous']);

    c.calls.clear();
    await tester.sendKeyEvent(LogicalKeyboardKey.end);
    await tester.sendKeyEvent(LogicalKeyboardKey.home);
    expect(c.calls, ['goTo(300, 0.0)', 'goTo(1, 0.0)']);
    await closeReader(tester, app);
  });

  testWidgets('arrow up and down scroll a small step in continuous mode (FR-008)',
      (tester) async {
    final (app, view) = await openReader(tester, FakeReaderDocument(), before: (app) async {
      await tester.runAsync(() => ReaderRepository(app.db).setPageMode('b1', PageMode.continuous));
    });
    final c = view.controller;
    c.calls.clear();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    expect(c.calls, ['scrollBy(0.1)', 'scrollBy(-0.1)']);
    await closeReader(tester, app);
  });

  testWidgets('Esc goes back to the library', (tester) async {
    final (app, _) = await openReader(tester, FakeReaderDocument());
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump(const Duration(seconds: 1));
    await settleReal(tester);
    expect(find.text('Library'), findsOneWidget);
    await closeReader(tester, app);
  });

  testWidgets('a new book is paged; the mode is saved per book (FR-005, FR-009)',
      (tester) async {
    final (app, view) = await openReader(tester, FakeReaderDocument());
    expect(view.controller.config!.mode, PageMode.paged);

    await tapView(tester, 0.5);
    await tester.tap(find.byTooltip('Reader settings'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continuous'));
    await tester.pump();
    await settleReal(tester);
    expect(view.controller.config!.mode, PageMode.continuous);
    final repo = ReaderRepository(app.db);
    expect(await tester.runAsync(() => repo.pageMode('b1')), PageMode.continuous);
    expect(await tester.runAsync(() => repo.pageMode('other')), PageMode.paged);
    await closeReader(tester, app);
  });

  testWidgets('the page view offers next and previous page to screen readers (FR-040)',
      (tester) async {
    final handle = tester.ensureSemantics();
    final (app, view) = await openReader(tester, FakeReaderDocument());
    final node = tester.getSemantics(find.byKey(const ValueKey('reader-page-view')));
    expect(node.label, contains('Page 1 of 300'));
    final actions = node.getSemanticsData().customSemanticsActionIds!
        .map((id) => CustomSemanticsAction.getAction(id)!.label);
    expect(actions, containsAll(['Next page', 'Previous page']));

    final nextId = node.getSemanticsData().customSemanticsActionIds!
        .firstWhere((id) => CustomSemanticsAction.getAction(id)!.label == 'Next page');
    node.owner!.performAction(node.id, SemanticsAction.customAction, nextId);
    await tester.pump();
    expect(view.controller.calls.last, 'next');
    handle.dispose();
    await closeReader(tester, app);
  });
}
