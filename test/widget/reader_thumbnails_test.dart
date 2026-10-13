// User Story 8: page thumbnails (FR-035).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:potha/core/document/document_format.dart';

import 'reader_test_app.dart';
import 'test_app.dart';

void main() {
  Future<void> openThumbnails(WidgetTester tester) async {
    await tapView(tester, 0.5);
    await tester.pump(const Duration(milliseconds: 200));
    await tester.tap(find.byTooltip('Page thumbnails'));
    await tester.pumpAndSettle();
    await settleReal(tester);
    await tester.pump();
  }

  testWidgets('opens at the current page, which is marked; choosing jumps (FR-035)',
      (tester) async {
    final handle = tester.ensureSemantics();
    final (app, view) = await openReader(tester, FakeReaderDocument(pageCount: 60));
    view.controller.emitPosition(const ReadingPosition(40, 0));
    await tester.pump();
    await openThumbnails(tester);
    expect(find.bySemanticsLabel('Page 40, current page'), findsOneWidget);
    await tester.tap(find.bySemanticsLabel('Page 41'));
    await tester.pumpAndSettle();
    expect(view.controller.goTos.last, const ReadingPosition(41, 0));
    expect(find.text('Back to page 40'), findsOneWidget);
    handle.dispose();
    await closeReader(tester, app);
  });

  testWidgets('a page that cannot be rendered shows a placeholder tile', (tester) async {
    final handle = tester.ensureSemantics();
    final (app, _) = await openReader(tester, FakeReaderDocument(pageCount: 6, failingPages: {2}));
    await openThumbnails(tester);
    expect(find.bySemanticsLabel("Page 2, can't be shown"), findsOneWidget);
    expect(find.byIcon(Icons.broken_image_outlined), findsOneWidget);
    handle.dispose();
    await closeReader(tester, app);
  });
}
