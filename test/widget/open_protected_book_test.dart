import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:potha/core/document/document_format.dart';
import 'package:potha/core/document/pdf/pdf_document_format.dart';
import 'package:potha/features/reader/ui/reader_screen.dart';

import 'reader_test_app.dart';
import 'test_app.dart';

/// Opens only with "secret", trying the known password first like pdfrx does.
class _LockedFormat implements DocumentFormat {
  var asked = 0;
  @override
  String get id => 'pdf';
  @override
  bool sniff(Uint8List header) => true;
  @override
  Future<ReaderDocument> open(BookFileRef file,
      {String? knownPassword, AskPassword? askPassword}) async {
    if (knownPassword == 'secret') return FakeReaderDocument(pageCount: 5, usedPassword: 'secret');
    var retry = false;
    while (true) {
      asked++;
      final given = await askPassword!(retry: retry);
      if (given == null) throw const DocumentOpenException(DocumentOpenFailure.passwordCancelled);
      if (given == 'secret') return FakeReaderDocument(pageCount: 5, usedPassword: given);
      retry = true;
    }
  }
}

void main() {
  Future<(TestApp, _LockedFormat)> openBook(WidgetTester tester, Map<String, String> saved) async {
    final format = _LockedFormat();
    final app = TestApp(passwordStore: MemoryPasswordStore(saved), overrides: [
      documentFormatsProvider.overrideWithValue([format]),
      documentViewFactoriesProvider.overrideWithValue({'pdf': FakeViewFactory()}),
    ]);
    await app.pump(tester);
    await seedBook(tester, app.db, id: 'locked', title: 'Locked book');
    await tester.runAsync(() => app.db.customStatement(
        "UPDATE books SET is_password_protected = 1 WHERE id = 'locked'"));
    final navigator = tester.state<NavigatorState>(find.byType(Navigator));
    navigator.push(MaterialPageRoute<void>(builder: (_) => const ReaderScreen(bookId: 'locked')));
    await settleReal(tester);
    // Not pumpAndSettle: the "Opening book" spinner animates behind the dialog.
    await tester.pump(const Duration(milliseconds: 500));
    return (app, format);
  }

  testWidgets('a stored password opens the book without asking (FR-028)', (tester) async {
    final (app, format) = await openBook(tester, {'locked': 'secret'});
    await settleReal(tester);

    expect(format.asked, 0);
    expect(find.text('Password needed'), findsNothing);
    expect(find.textContaining('View page 1'), findsOneWidget);

    // Opening alone records the starting page (no longer "New").
    await tester.pump(const Duration(seconds: 1));
    await settleReal(tester);
    final progress = await tester.runAsync(() => app.db.select(app.db.readingProgress).get());
    expect(progress!.single.currentPage, 1);

    await app.dispose(tester);
  });

  testWidgets('a wrong stored password asks again and replaces it', (tester) async {
    final saved = {'locked': 'old'};
    final (app, _) = await openBook(tester, saved);

    expect(find.text('Password needed'), findsOneWidget);
    expect(find.text('Wrong password, try again'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'secret');
    await tester.tap(find.text('Open'));
    await tester.pump(const Duration(milliseconds: 500));
    await settleReal(tester);

    expect(find.textContaining('View page 1'), findsOneWidget);
    expect(saved['locked'], 'secret');

    await app.dispose(tester);
  });
}
