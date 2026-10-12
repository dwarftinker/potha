// FR-023 / FR-026 / constitution II and VI: importing and opening a book never touches
// the network. Uses real PDFium (tool/fetch_test_pdfium.sh); skipped without it.
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pdfrx/pdfrx.dart';
import 'package:potha/core/db/app_database.dart';
import 'package:potha/core/document/pdf/pdf_document_format.dart';
import 'package:potha/core/secure/password_store.dart';
import 'package:potha/core/storage/book_file_store_io.dart';
import 'package:potha/features/library/data/library_repository.dart';
import 'package:potha/features/library/import/import_service.dart';
import 'package:potha/features/library/import/import_source.dart';

final _pdfium = File('build/test_pdfium/libpdfium.so');

class _NoNetwork extends HttpOverrides {
  final attempts = <String>[];
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    attempts.add('HttpClient');
    throw StateError('Network access is not allowed');
  }
}

class _Passwords implements PasswordStore {
  @override
  Future<String?> read(String bookId) async => null;
  @override
  Future<void> write(String bookId, String password) async {}
  @override
  Future<void> delete(String bookId) async {}
}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    if (!_pdfium.existsSync()) return;
    Pdfrx.pdfiumModulePath = _pdfium.absolute.path;
    Pdfrx.cacheDirectoryPath = Directory.systemTemp.createTempSync('pdfrx_test').path;
  });

  testWidgets('import, read metadata, render a cover and reopen with no network',
      (tester) async {
    final overrides = _NoNetwork();
    await tester.runAsync(() => HttpOverrides.runWithHttpOverrides(() async {
          final root = await Directory.systemTemp.createTemp('potha_offline');
          final db = AppDatabase(NativeDatabase.memory());
          final store = IoBookFileStore(root: () async => root);
          final service = ImportService(
            formats: const [PdfDocumentFormat()],
            store: store,
            passwords: _Passwords(),
            repository: LibraryRepository(db),
            isWeb: false,
          );
          final file = File('test/fixtures/with_metadata.pdf');
          final events = await service.importFiles([
            ImportSource(name: 'book.pdf', size: file.lengthSync(), openRead: file.openRead)
          ], askPassword: (_, {required retry}) async => null).toList();
          final result = (events.last as ImportFinished).results.single;
          expect(result.outcome, ImportOutcome.added);

          final doc = await const PdfDocumentFormat().open((await store.find(result.bookId!))!);
          expect(await doc.renderPagePng(1, width: 200), isNotNull);
          await doc.close();

          await db.close();
          await root.delete(recursive: true);
        }, overrides));
    expect(overrides.attempts, isEmpty);
  }, skip: !_pdfium.existsSync());
}
