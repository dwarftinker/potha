// FR-023 / FR-026 / constitution II and VI: importing and opening a book never touches
// the network. Uses real PDFium (tool/fetch_test_pdfium.sh); skipped without it.
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pdfrx/pdfrx.dart';
import 'package:potha/core/db/app_database.dart';
import 'package:potha/core/document/document_format.dart';
import 'package:potha/core/document/pdf/pdf_document_format.dart';
import 'package:potha/core/secure/password_store.dart';
import 'package:potha/core/storage/book_file_store_io.dart';
import 'package:potha/features/library/data/library_repository.dart';
import 'package:potha/features/library/import/import_service.dart';
import 'package:potha/features/library/import/import_source.dart';
import 'package:potha/core/dictionary/dictionary_database.dart';
import 'package:potha/core/dictionary/dictionary_store_io.dart';
import 'package:potha/features/reader/data/page_text_cache.dart';
import 'package:potha/features/reader/data/reader_repository.dart';
import 'package:potha/features/reader/data/thumbnail_cache.dart';
import 'package:potha/features/reader/lookup_controller.dart';
import 'package:potha/features/reader/domain/text_search.dart';

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

  // 002 FR-039, FR-041: the reader's own work (contents, links, page text, search,
  // thumbnails) stays on the device. The only way out is a web link the reader
  // confirms, through LinkOpener (test/widget/reader_jump_test.dart).
  testWidgets('reading, contents, links, search and thumbnails with no network',
      (tester) async {
    final overrides = _NoNetwork();
    await tester.runAsync(() => HttpOverrides.runWithHttpOverrides(() async {
          final file = File('test/fixtures/outline_links.pdf');
          final doc = await const PdfDocumentFormat().open(BookFileRef(
              path: file.absolute.path, readAll: file.readAsBytes, sizeBytes: file.lengthSync()));
          expect(await doc.loadOutline(), isNotEmpty);
          expect((await doc.loadLinks(2)).whereType<WebLink>(), isNotEmpty);
          expect((await doc.loadPageText(1))!.hasText, isTrue);
          final run = TextSearch(doc).start('chapter', fromPage: 1);
          await run.done;
          expect(run.results, isNotEmpty);
          final thumbs = ThumbnailCache(doc, width: 60);
          (await thumbs.load(3))!.dispose();
          thumbs.dispose();
          await doc.close();
        }, overrides));
    expect(overrides.attempts, isEmpty);
  }, skip: !_pdfium.existsSync());

  // 003 FR-032: lookups, the dictionary store and tap-to-define stay on the device. The
  // only request is the reader's "Search online" (test/unit/dictionary).
  testWidgets('dictionary lookups with no network', (tester) async {
    final overrides = _NoNetwork();
    await tester.runAsync(() => HttpOverrides.runWithHttpOverrides(() async {
          final root = await Directory.systemTemp.createTemp('potha_dict_offline');
          final dictionary = IoDictionaryStore(
            supportDirectory: () async => root,
            loadAsset: () async =>
                File('test/fixtures/dictionary/dict_sample.sqlite.gz').readAsBytes(),
            loadVersion: () async => 'sample',
            openExecutor: (file) => NativeDatabase(file,
                setup: (db) => db.execute(DictionaryDatabase.readOnlyPragma)),
          );
          final file = File('test/fixtures/lookup_prose.pdf');
          final doc = await const PdfDocumentFormat().open(BookFileRef(
              path: file.absolute.path, readAll: file.readAsBytes, sizeBytes: file.lengthSync()));
          final lookup = LookupController(
              store: dictionary, pageText: PageTextCache(doc.loadPageText));
          final text = (await doc.loadPageText(1))!;
          PagePoint on(String word) =>
              PagePoint(1, text.charRects[text.text.indexOf(word) + 1].center);

          dictionary.ensureStarted();
          await lookup.lookUpAt(on('melancholy'));
          expect(lookup.state, isA<LookupShown>());
          await lookup.lookUpAt(on('mice'));
          expect((lookup.state as LookupShown).result.sections.map((s) => s.note),
              contains('mice – plural of mouse'));
          await lookup.lookUpAt(on('Call'));
          expect(lookup.state, isA<LookupNotFound>());

          final db = AppDatabase(NativeDatabase.memory());
          final repo = ReaderRepository(db);
          await repo.setTapToDefine(true);
          await repo.setTapToDefine(false);

          lookup.dispose();
          await dictionary.close();
          await doc.close();
          await db.close();
          await root.delete(recursive: true);
        }, overrides));
    expect(overrides.attempts, isEmpty);
  }, skip: !_pdfium.existsSync());
}
