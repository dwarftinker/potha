// The real import pipeline on the host: pdfrx (PDFium), the IO file store and SQLite,
// with the committed fixtures. Needs tool/fetch_test_pdfium.sh (skipped otherwise).
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

class MemoryPasswords implements PasswordStore {
  final saved = <String, String>{};
  @override
  Future<String?> read(String bookId) async => saved[bookId];
  @override
  Future<void> write(String bookId, String password) async => saved[bookId] = password;
  @override
  Future<void> delete(String bookId) async => saved.remove(bookId);
}

ImportSource fixture(String name) {
  final file = File('test/fixtures/$name');
  return ImportSource(name: name, size: file.lengthSync(), openRead: file.openRead);
}

void main() {
  late Directory root;
  late AppDatabase db;
  late ImportService service;
  late MemoryPasswords passwords;

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    if (!_pdfium.existsSync()) return;
    Pdfrx.pdfiumModulePath = _pdfium.absolute.path;
    Pdfrx.cacheDirectoryPath = Directory.systemTemp.createTempSync('pdfrx_test').path;
    await pdfrxFlutterInitialize();
  });

  setUp(() async {
    root = await Directory.systemTemp.createTemp('potha_pipeline');
    db = AppDatabase(NativeDatabase.memory());
    passwords = MemoryPasswords();
    service = ImportService(
      formats: const [PdfDocumentFormat()],
      store: IoBookFileStore(root: () async => root),
      passwords: passwords,
      repository: LibraryRepository(db),
      isWeb: false,
    );
  });

  tearDown(() async {
    await db.close();
    await root.delete(recursive: true);
  });

  Future<List<ImportResult>> run(List<ImportSource> files, {String? password}) async {
    final events = await service
        .importFiles(files, askPassword: (_, {required retry}) async => retry ? null : password)
        .toList();
    return (events.last as ImportFinished).results;
  }

  testWidgets('imports real PDFs end to end', (tester) async {
    await tester.runAsync(() async {
      final results = await run([
        fixture('with_metadata.pdf'),
        fixture('object_stream_metadata.pdf'),
        fixture('no_metadata.pdf'),
        fixture('not_a_pdf.pdf'),
        fixture('truncated.pdf'),
      ]);
      expect(results.map((r) => r.outcome), [
        ImportOutcome.added,
        ImportOutcome.added, // different bytes from with_metadata.pdf
        ImportOutcome.added,
        ImportOutcome.failed,
        ImportOutcome.failed,
      ]);
      expect(results[3].failure, ImportFailure.notAPdf);
      expect(results[4].failure, ImportFailure.damaged);

      final books = await db.select(db.books).get();
      expect(books.map((b) => b.title).toSet(),
          {'The Brothers Karamazov', 'no metadata'});
      expect(books.firstWhere((b) => b.originalFileName == 'with_metadata.pdf').author,
          'Fyodor Dostoevsky');
      expect(await db.select(db.bookCovers).get(), hasLength(3));
      expect(Directory('${root.path}/books').listSync(), hasLength(3));
      expect(Directory('${root.path}/staging').listSync(), isEmpty);

      final again = await run([fixture('with_metadata.pdf')]);
      expect(again.single.outcome, ImportOutcome.alreadyInLibrary);
    });
  }, skip: !_pdfium.existsSync());

  testWidgets('imports an encrypted PDF with its password and remembers it', (tester) async {
    await tester.runAsync(() async {
      final results = await run([fixture('encrypted.pdf')], password: 'secret');
      expect(results.single.outcome, ImportOutcome.added);
      final book = (await db.select(db.books).get()).single;
      expect(book.isPasswordProtected, isTrue);
      expect(book.title, 'encrypted'); // metadata is encrypted, so the file name is used
      expect(passwords.saved[book.id], 'secret');
    });
  }, skip: !_pdfium.existsSync());
}
