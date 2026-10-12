import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:potha/features/library/import/import_service.dart';

import 'test_app.dart';

const _title = 'Your books stay in this browser';

FakeImportService addsOneBook() => FakeImportService((emit, ask, cancelled) async {
      emit(ImportFinished([added('book.pdf', 'Book')]));
    });

void main() {
  testWidgets('on the web, the notice shows once after the first import (FR-027)',
      (tester) async {
    final app = TestApp(importService: addsOneBook(), isWeb: true);
    await app.pump(tester);

    await tapAddBook(tester);
    await tester.pumpAndSettle();
    expect(find.text(_title), findsOneWidget);
    await tester.tap(find.text('Got it'));
    await tester.pumpAndSettle();
    expect(find.text(_title), findsNothing);

    await tapAddBook(tester);
    await tester.pumpAndSettle();
    expect(find.text(_title), findsNothing);

    await app.dispose(tester);
  });

  testWidgets('the notice is not shown for a failed import', (tester) async {
    final service = FakeImportService((emit, ask, cancelled) async {
      emit(const ImportFinished([
        ImportResult(
            fileName: 'x.pdf', outcome: ImportOutcome.failed, failure: ImportFailure.notAPdf),
      ]));
    });
    final app = TestApp(importService: service, isWeb: true);
    await app.pump(tester);

    await tapAddBook(tester);
    await tester.pumpAndSettle();
    expect(find.text(_title), findsNothing);

    await app.dispose(tester);
  });

  testWidgets('the notice is never shown on Android', (tester) async {
    final app = TestApp(importService: addsOneBook(), isWeb: false);
    await app.pump(tester);

    await tapAddBook(tester);
    await tester.pumpAndSettle();
    expect(find.text(_title), findsNothing);
    expect(find.byType(AlertDialog), findsNothing);

    await app.dispose(tester);
  });
}
