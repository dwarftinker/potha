import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:potha/features/library/ui/book_tile.dart';

import 'test_app.dart';

const _message = 'Remove “Emma”? This deletes Potha’s copy and your reading progress. '
    'The original file is not affected.';

Future<void> openRemoveDialog(WidgetTester tester) async {
  await tester.tap(find.byTooltip('More options for Emma'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Remove from library'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('the remove dialog names the book; Cancel changes nothing (FR-020)',
      (tester) async {
    final app = TestApp();
    await app.pump(tester);
    await seedBook(tester, app.db, id: 'e', title: 'Emma');

    await openRemoveDialog(tester);
    expect(find.text(_message), findsOneWidget);

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    await settleReal(tester);
    expect(find.byType(BookTile), findsOneWidget);
    expect((app.fileStore as MemoryFileStore).deleted, isEmpty);

    await app.dispose(tester);
  });

  testWidgets('Remove deletes the book and its file (FR-021)', (tester) async {
    final app = TestApp();
    await app.pump(tester);
    await seedBook(tester, app.db, id: 'e', title: 'Emma');

    await openRemoveDialog(tester);
    await tester.tap(find.widgetWithText(FilledButton, 'Remove'));
    await tester.pumpAndSettle();
    await settleReal(tester);

    expect(find.byType(BookTile), findsNothing);
    expect((app.fileStore as MemoryFileStore).deleted, ['e']);
    expect(find.textContaining('Your library is empty'), findsOneWidget);

    await app.dispose(tester);
  });

  testWidgets('long-press opens the same options', (tester) async {
    final app = TestApp();
    await app.pump(tester);
    await seedBook(tester, app.db, id: 'e', title: 'Emma');

    await tester.longPress(find.byType(BookTile));
    await tester.pumpAndSettle();
    expect(find.text('Remove from library'), findsOneWidget);

    await app.dispose(tester);
  });
}
