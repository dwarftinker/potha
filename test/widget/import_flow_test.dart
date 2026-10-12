import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:potha/features/library/import/import_service.dart';

import 'test_app.dart';

void main() {
  testWidgets('a fast import shows no progress bar, then a snackbar', (tester) async {
    final service = FakeImportService((emit, ask, cancelled) async {
      emit(const ImportStarted(0, 1, 'book.pdf'));
      await Future<void>.delayed(const Duration(milliseconds: 300));
      emit(ImportFinished([added('book.pdf', 'The Idiot')]));
    });
    final app = TestApp(importService: service);
    await app.pump(tester);

    await tapAddBook(tester);
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.byType(LinearProgressIndicator), findsNothing);

    await tester.pump(const Duration(milliseconds: 200));
    await tester.pump();
    expect(find.text('Added “The Idiot”'), findsOneWidget);
    await tester.pump(const Duration(seconds: 1));
    expect(find.byType(LinearProgressIndicator), findsNothing);

    await app.dispose(tester);
  });

  testWidgets('a slow import shows progress and Cancel after 1 s (FR-008)', (tester) async {
    final service = FakeImportService((emit, ask, cancelled) async {
      emit(const ImportStarted(0, 1, 'big.pdf'));
      emit(const ImportProgress(0, 10, 100));
      await cancelled.future;
      emit(const ImportFinished([
        ImportResult(
            fileName: 'big.pdf', outcome: ImportOutcome.failed, failure: ImportFailure.cancelled)
      ]));
    });
    final app = TestApp(importService: service);
    await app.pump(tester);

    await tapAddBook(tester);
    await tester.pump(const Duration(milliseconds: 900));
    expect(find.byType(LinearProgressIndicator), findsNothing);

    await tester.pump(const Duration(milliseconds: 200));
    expect(find.byType(LinearProgressIndicator), findsOneWidget);
    expect(find.textContaining('Adding “big.pdf”'), findsOneWidget);

    await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
    await tester.pump();
    await tester.pump();
    expect(service.cancelCalls, 1);
    expect(find.byType(LinearProgressIndicator), findsNothing);

    await app.dispose(tester);
  });

  testWidgets('asks for a password and says so after a wrong one', (tester) async {
    final answers = <String?>[];
    final service = FakeImportService((emit, ask, cancelled) async {
      emit(const ImportStarted(0, 1, 'locked.pdf'));
      answers.add(await ask('locked.pdf', retry: false));
      answers.add(await ask('locked.pdf', retry: true));
      emit(ImportFinished([added('locked.pdf', 'Locked')]));
    });
    final app = TestApp(importService: service);
    await app.pump(tester);

    await tapAddBook(tester);
    await tester.pumpAndSettle();
    expect(find.text('Password needed'), findsOneWidget);
    expect(find.text('Wrong password, try again'), findsNothing);

    await tester.enterText(find.byType(TextField), 'wrong');
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    expect(find.text('Wrong password, try again'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'secret');
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    expect(answers, ['wrong', 'secret']);

    await app.dispose(tester);
  });

  testWidgets('cancelling the password dialog answers null', (tester) async {
    String? answer = 'unset';
    final service = FakeImportService((emit, ask, cancelled) async {
      answer = await ask('locked.pdf', retry: false);
      emit(const ImportFinished([
        ImportResult(
            fileName: 'locked.pdf',
            outcome: ImportOutcome.failed,
            failure: ImportFailure.passwordCancelled)
      ]));
    });
    final app = TestApp(importService: service);
    await app.pump(tester);

    await tapAddBook(tester);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(answer, isNull);
    expect(find.text('No password was entered.'), findsOneWidget);

    await app.dispose(tester);
  });

  testWidgets('a multi-file import shows a summary with reasons (FR-009)', (tester) async {
    final service = FakeImportService((emit, ask, cancelled) async {
      emit(ImportFinished([
        added('one.pdf', 'One'),
        const ImportResult(
            fileName: 'dup.pdf', outcome: ImportOutcome.alreadyInLibrary, bookId: 'x'),
        const ImportResult(
            fileName: 'notes.pdf', outcome: ImportOutcome.failed, failure: ImportFailure.notAPdf),
      ]));
    });
    final app = TestApp(importService: service);
    await app.pump(tester);

    await tapAddBook(tester);
    await tester.pumpAndSettle();
    expect(find.text('Import finished'), findsOneWidget);
    expect(find.text('Added (1)'), findsOneWidget);
    expect(find.text('One'), findsOneWidget);
    expect(find.text('Already in your library (1)'), findsOneWidget);
    expect(find.text('dup.pdf'), findsOneWidget);
    expect(find.text('Not added (1)'), findsOneWidget);
    expect(find.text('This file is not a PDF.'), findsOneWidget);

    await app.dispose(tester);
  });

  testWidgets('a duplicate shows "Already in your library" with Open (FR-007)', (tester) async {
    final service = FakeImportService((emit, ask, cancelled) async {
      emit(const ImportFinished([
        ImportResult(fileName: 'dup.pdf', outcome: ImportOutcome.alreadyInLibrary, bookId: 'x'),
      ]));
    });
    final app = TestApp(importService: service);
    await app.pump(tester);

    await tapAddBook(tester);
    await tester.pumpAndSettle();
    expect(find.text('Already in your library'), findsOneWidget);
    expect(find.widgetWithText(SnackBarAction, 'Open'), findsOneWidget);

    await app.dispose(tester);
  });
}
