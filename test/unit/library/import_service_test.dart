import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:potha/core/db/app_database.dart';
import 'package:potha/core/document/document_format.dart';
import 'package:potha/core/secure/password_store.dart';
import 'package:potha/core/storage/book_file_store.dart';
import 'package:potha/features/library/data/library_repository.dart';
import 'package:potha/features/library/import/import_service.dart';
import 'package:potha/features/library/import/import_source.dart';

// --- Fakes -----------------------------------------------------------------
//
// File content drives FakeFormat:
//   "%PDF-ok:<title>"           valid, metadata title <title>
//   "%PDF-damaged"              open throws damaged
//   "%PDF-locked:<password>"    needs <password>
//   anything not starting %PDF- fails sniff

class FakeDoc extends Fake implements ReaderDocument {
  FakeDoc(this.title, this.usedPassword);
  final String? title;
  @override
  final String? usedPassword;
  bool closed = false;
  @override
  int get pageCount => 12;
  @override
  Future<DocumentMetadata> readMetadata() async => DocumentMetadata(title: title);
  @override
  Future<Uint8List?> renderPagePng(int pageNumber, {required int width}) async =>
      Uint8List.fromList([137, 80, 78, 71]);
  @override
  Future<void> close() async => closed = true;
}

class FakeFormat implements DocumentFormat {
  @override
  String get id => 'pdf';

  @override
  bool sniff(Uint8List header) => latin1.decode(header, allowInvalid: true).contains('%PDF-');

  @override
  Future<ReaderDocument> open(BookFileRef file,
      {String? knownPassword, AskPassword? askPassword}) async {
    final text = latin1.decode(await file.readAll());
    if (text.startsWith('%PDF-damaged')) {
      throw const DocumentOpenException(DocumentOpenFailure.damaged);
    }
    if (text.startsWith('%PDF-locked:')) {
      final expected = text.substring('%PDF-locked:'.length).trim();
      var retry = false;
      while (true) {
        final given = await askPassword?.call(retry: retry);
        if (given == null) throw const DocumentOpenException(DocumentOpenFailure.passwordCancelled);
        if (given == expected) return FakeDoc(null, given);
        retry = true;
      }
    }
    final title = text.startsWith('%PDF-ok:') ? text.substring(8).trim() : null;
    return FakeDoc(title, null);
  }
}

class FakeStore implements BookFileStore {
  final staging = <String, Uint8List>{};
  final books = <String, Uint8List>{};
  bool failWithStorageFull = false;
  bool failCommit = false;
  var _next = 0;

  BookFileRef _ref(Uint8List data) =>
      BookFileRef(readAll: () async => data, sizeBytes: data.length);

  @override
  Future<StagedFile> stage(Stream<List<int>> source,
      {int? totalBytes, void Function(int written)? onProgress, Future<void>? cancel}) async {
    final id = 's${_next++}';
    var cancelled = false;
    cancel?.then((_) => cancelled = true);
    final out = BytesBuilder();
    try {
      await for (final chunk in source) {
        if (cancelled) throw const StagingCancelledException();
        if (failWithStorageFull) throw const StorageFullException();
        out.add(chunk);
        staging[id] = out.toBytes();
        onProgress?.call(out.length);
      }
    } catch (_) {
      staging.remove(id);
      rethrow;
    }
    staging[id] = out.toBytes();
    return StagedFile(id: id, ref: _ref(staging[id]!));
  }

  @override
  Future<BookFileRef> commit(StagedFile staged, String bookId) async {
    if (failCommit) throw StateError('disk error');
    books[bookId] = staging.remove(staged.id)!;
    return _ref(books[bookId]!);
  }

  @override
  Future<void> discard(StagedFile staged) async => staging.remove(staged.id);
  @override
  Future<BookFileRef?> find(String bookId) async =>
      books[bookId] == null ? null : _ref(books[bookId]!);
  @override
  Future<void> delete(String bookId) async => books.remove(bookId);
  @override
  Future<void> cleanUp(Set<String> knownBookIds) async {}
  @override
  Future<void> requestPersistence() async {}
}

class FakePasswords implements PasswordStore {
  final saved = <String, String>{};
  @override
  Future<String?> read(String bookId) async => saved[bookId];
  @override
  Future<void> write(String bookId, String password) async => saved[bookId] = password;
  @override
  Future<void> delete(String bookId) async => saved.remove(bookId);
}

ImportSource source(String name, String content, {int? size, int chunks = 1}) {
  final bytes = latin1.encode(content);
  return ImportSource(
    name: name,
    size: size ?? bytes.length,
    openRead: () async* {
      final step = (bytes.length / chunks).ceil();
      for (var i = 0; i < bytes.length; i += step) {
        yield bytes.sublist(i, i + step > bytes.length ? bytes.length : i + step);
        await Future<void>.delayed(const Duration(milliseconds: 1));
      }
    },
  );
}

// --- Tests -----------------------------------------------------------------

void main() {
  late AppDatabase db;
  late FakeStore store;
  late FakePasswords passwords;
  late LibraryRepository repo;
  late ImportService service;
  var ids = 0;

  ImportService make({bool isWeb = false}) => ImportService(
        formats: [FakeFormat()],
        store: store,
        passwords: passwords,
        repository: repo,
        isWeb: isWeb,
        clock: () => DateTime.utc(2026, 10, 12, 9),
        newId: () => 'book-${ids++}',
      );

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    store = FakeStore();
    passwords = FakePasswords();
    repo = LibraryRepository(db);
    ids = 0;
    service = make();
  });
  tearDown(() => db.close());

  Future<List<ImportResult>> run(List<ImportSource> files,
      {List<String?> answers = const [], ImportService? using}) async {
    final queue = [...answers];
    final events = await (using ?? service)
        .importFiles(files, askPassword: (name, {required retry}) async =>
            queue.isEmpty ? null : queue.removeAt(0))
        .toList();
    return (events.last as ImportFinished).results;
  }

  Future<List<Book>> books() => db.select(db.books).get();

  test('a valid file is added with its cover and resolved title', () async {
    final results = await run([source('karamazov.pdf', '%PDF-ok:The Brothers Karamazov')]);

    expect(results.single.outcome, ImportOutcome.added);
    expect(results.single.bookId, 'book-0');
    final book = (await books()).single;
    expect(book.title, 'The Brothers Karamazov');
    expect(book.sortTitle, 'brothers karamazov');
    expect(book.pageCount, 12);
    expect(book.originalFileName, 'karamazov.pdf');
    expect(book.contentHash, hasLength(64));
    expect(book.isPasswordProtected, isFalse);
    expect(book.addedAt.toUtc(), DateTime.utc(2026, 10, 12, 9));
    expect(await repo.cover('book-0'), isNotNull);
    expect(store.books.keys, ['book-0']);
    expect(store.staging, isEmpty);
  });

  test('the same bytes under another name are reported as already in the library', () async {
    await run([source('a.pdf', '%PDF-ok:Same')]);
    final results = await run([source('copy of a.pdf', '%PDF-ok:Same')]);

    expect(results.single.outcome, ImportOutcome.alreadyInLibrary);
    expect(results.single.bookId, 'book-0');
    expect(await books(), hasLength(1));
    expect(store.staging, isEmpty);
  });

  test('a file that is not a PDF is rejected and nothing is stored', () async {
    final results = await run([source('notes.pdf', 'just some text')]);
    expect(results.single.failure, ImportFailure.notAPdf);
    expect(await books(), isEmpty);
    expect(store.staging, isEmpty);
    expect(store.books, isEmpty);
  });

  test('a damaged PDF is rejected', () async {
    final results = await run([source('broken.pdf', '%PDF-damaged')]);
    expect(results.single.failure, ImportFailure.damaged);
    expect(store.staging, isEmpty);
  });

  test('cancelling the password adds nothing', () async {
    final results = await run([source('locked.pdf', '%PDF-locked:secret')], answers: [null]);
    expect(results.single.failure, ImportFailure.passwordCancelled);
    expect(await books(), isEmpty);
    expect(store.staging, isEmpty);
  });

  test('a wrong then right password adds the book and remembers the password', () async {
    final asked = <bool>[];
    final events = await service
        .importFiles([source('locked.pdf', '%PDF-locked:secret')],
            askPassword: (name, {required retry}) async {
              asked.add(retry);
              return retry ? 'secret' : 'wrong';
            })
        .toList();
    final result = (events.last as ImportFinished).results.single;

    expect(asked, [false, true]);
    expect(result.outcome, ImportOutcome.added);
    expect((await books()).single.isPasswordProtected, isTrue);
    expect(passwords.saved['book-0'], 'secret');
  });

  test('on the web, files over 100 MB are rejected before staging', () async {
    var opened = false;
    final big = ImportSource(
      name: 'huge.pdf',
      size: ImportService.webSizeLimit + 1,
      openRead: () {
        opened = true;
        return const Stream.empty();
      },
    );
    final results = await run([big], using: make(isWeb: true));

    expect(results.single.failure, ImportFailure.tooLargeForWeb);
    expect(opened, isFalse);
  });

  test('on the web, an unknown-size file is stopped once it passes 100 MB', () async {
    final web = make(isWeb: true);
    final chunk = List<int>.filled(1 << 20, 32);
    final unknown = ImportSource(
      name: 'mystery.pdf',
      size: null,
      openRead: () async* {
        yield latin1.encode('%PDF-ok:x');
        for (var i = 0; i < 101; i++) {
          yield chunk;
        }
      },
    );
    final results = await run([unknown], using: web);
    expect(results.single.failure, ImportFailure.tooLargeForWeb);
    expect(store.staging, isEmpty);
  });

  test('running out of storage reports storageFull and leaves nothing', () async {
    store.failWithStorageFull = true;
    final results = await run([source('a.pdf', '%PDF-ok:A')]);
    expect(results.single.failure, ImportFailure.storageFull);
    expect(store.staging, isEmpty);
    expect(await books(), isEmpty);
  });

  test('cancel stops the current file and skips the rest of the batch', () async {
    final events = <ImportEvent>[];
    final done = Completer<void>();
    service
        .importFiles([
          source('slow.pdf', '%PDF-ok:${'x' * 5000}', chunks: 100),
          source('next.pdf', '%PDF-ok:Next'),
        ], askPassword: (_, {required retry}) async => null)
        .listen((e) {
          events.add(e);
          if (e is ImportProgress && e.written > 500) service.cancel();
          if (e is ImportFinished) done.complete();
        });
    await done.future;

    final results = (events.last as ImportFinished).results;
    expect(results.map((r) => r.failure), [ImportFailure.cancelled, ImportFailure.cancelled]);
    expect(await books(), isEmpty);
    expect(store.staging, isEmpty);
  });

  test('a mixed batch reports one result per file, in order', () async {
    await run([source('existing.pdf', '%PDF-ok:Existing')]);
    final results = await run([
      source('one.pdf', '%PDF-ok:One'),
      source('dup.pdf', '%PDF-ok:Existing'),
      source('text.pdf', 'hello'),
      source('two.pdf', '%PDF-ok:Two'),
      source('broken.pdf', '%PDF-damaged'),
    ]);

    expect(results.map((r) => r.fileName),
        ['one.pdf', 'dup.pdf', 'text.pdf', 'two.pdf', 'broken.pdf']);
    expect(results.map((r) => r.outcome), [
      ImportOutcome.added,
      ImportOutcome.alreadyInLibrary,
      ImportOutcome.failed,
      ImportOutcome.added,
      ImportOutcome.failed,
    ]);
    expect(await books(), hasLength(3));
  });

  test('if moving the file fails after the insert, the transaction is rolled back', () async {
    store.failCommit = true;
    final results = await run([source('a.pdf', '%PDF-ok:A')]);

    expect(results.single.failure, ImportFailure.unknown);
    expect(await books(), isEmpty);
    expect(await db.select(db.bookCovers).get(), isEmpty);
    expect(store.staging, isEmpty);
  });

  test('progress and start events are emitted', () async {
    final events = await service
        .importFiles([source('a.pdf', '%PDF-ok:A', chunks: 3)],
            askPassword: (_, {required retry}) async => null)
        .toList();
    expect(events.first, isA<ImportStarted>());
    expect(events.whereType<ImportProgress>(), isNotEmpty);
    expect(events.last, isA<ImportFinished>());
  });

  test('a source that streams Uint8List chunks is imported (Android file picker)',
      () async {
    final bytes = Uint8List.fromList(latin1.encode('%PDF-ok:Picked'));
    // XFile.openRead returns a Stream<Uint8List>; Stream<List<int>> accepts it
    // statically, but transforming it must still work at runtime.
    final picked = ImportSource(
      name: 'picked.pdf',
      size: bytes.length,
      openRead: () => Stream<Uint8List>.value(bytes),
    );
    final results = await run([picked]);
    expect(results.single.outcome, ImportOutcome.added);
  });

  test('an unexpected error fails that file and the batch still finishes', () async {
    final broken = ImportSource(
      name: 'broken.pdf',
      size: 10,
      openRead: () => throw StateError('cannot read'),
    );
    final results = await run([broken, source('a.pdf', '%PDF-ok:A')]);
    expect(results.map((r) => r.failure), [ImportFailure.unknown, null]);
    expect(results.last.outcome, ImportOutcome.added);
    expect(store.staging, isEmpty);
  });
}
