// Shared harness for widget tests: the real app shell with in-memory storage and fakes.
import 'dart:async';
import 'dart:typed_data';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:potha/core/dictionary/dictionary_store.dart';
import 'package:potha/core/dictionary/online_dictionary.dart';
import 'package:potha/core/platform/network_status.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:potha/app.dart';
import 'package:potha/core/db/app_database.dart';
import 'package:potha/core/db/connection.dart';
import 'package:potha/core/platform/keep_awake.dart';
import 'package:potha/core/secure/password_store.dart';
import 'package:potha/core/storage/book_file_store.dart';
import 'package:potha/features/library/import/import_controller.dart';
import 'package:potha/features/library/import/import_service.dart';
import 'package:potha/features/library/import/import_source.dart';
import 'package:potha/features/library/domain/text_fold.dart';
import 'package:potha/features/library/ui/library_screen.dart';

import 'reader_test_app.dart' show FakeDictionaryStore, FakeLexicon, FakeNetworkStatus, FakeOnlineDictionary;

/// An ImportService whose behaviour each test scripts through [script].
class FakeImportService extends Fake implements ImportService {
  FakeImportService(this.script);

  /// Receives the event sink and the password callback; must add ImportFinished last.
  final Future<void> Function(
    void Function(ImportEvent) emit,
    AskImportPassword askPassword,
    Completer<void> cancelled,
  ) script;

  var cancelCalls = 0;
  Completer<void> _cancelled = Completer<void>();

  @override
  Stream<ImportEvent> importFiles(List<ImportSource> files,
      {required AskImportPassword askPassword}) {
    _cancelled = Completer<void>();
    final controller = StreamController<ImportEvent>();
    script(controller.add, askPassword, _cancelled).whenComplete(controller.close);
    return controller.stream;
  }

  @override
  void cancel() {
    cancelCalls++;
    if (!_cancelled.isCompleted) _cancelled.complete();
  }
}

ImportSource fakeSource(String name) =>
    ImportSource(name: name, size: 10, openRead: () => const Stream.empty());

ImportResult added(String name, String title, {String id = 'b1'}) => ImportResult(
    fileName: name, outcome: ImportOutcome.added, bookId: id, title: title);

/// In-memory book files: every book "has" a small file.
class MemoryFileStore extends Fake implements BookFileStore {
  final deleted = <String>[];
  @override
  Future<BookFileRef?> find(String bookId) async => deleted.contains(bookId)
      ? null
      : BookFileRef(readAll: () async => Uint8List(0), sizeBytes: 0);
  @override
  Future<void> delete(String bookId) async => deleted.add(bookId);
  @override
  Future<void> cleanUp(Set<String> knownBookIds) async {}
  @override
  Future<void> requestPersistence() async {}
}

class MemoryPasswordStore implements PasswordStore {
  MemoryPasswordStore([Map<String, String>? saved]) : saved = saved ?? {};
  final Map<String, String> saved;
  @override
  Future<String?> read(String bookId) async => saved[bookId];
  @override
  Future<void> write(String bookId, String password) async => saved[bookId] = password;
  @override
  Future<void> delete(String bookId) async => saved.remove(bookId);
}

/// Records keep-awake calls instead of touching the platform.
class FakeKeepAwake implements KeepAwake {
  final calls = <String>[];
  bool get isOn => calls.isNotEmpty && calls.last == 'enable';
  @override
  Future<void> enable() async => calls.add('enable');
  @override
  Future<void> disable() async => calls.add('disable');
}

class TestApp {
  TestApp({
    ImportService? importService,
    bool isWeb = false,
    List<ImportSource> Function()? picked,
    BookFileStore? fileStore,
    PasswordStore? passwordStore,
    FakeKeepAwake? keepAwake,
    DictionaryStore? dictionaryStore,
    NetworkStatus? network,
    OnlineDictionary? online,
    List<Override> overrides = const [],
  })  : db = AppDatabase(NativeDatabase.memory()),
        keepAwake = keepAwake ?? FakeKeepAwake(),
        fileStore = fileStore ?? MemoryFileStore(),
        passwordStore = passwordStore ?? MemoryPasswordStore() {
    widget = ProviderScope(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        isWebProvider.overrideWithValue(isWeb),
        incomingFilesEnabledProvider.overrideWithValue(false),
        bookFileStoreProvider.overrideWithValue(this.fileStore),
        passwordStoreProvider.overrideWithValue(this.passwordStore),
        keepAwakeProvider.overrideWithValue(this.keepAwake),
        pickFilesProvider.overrideWithValue(
            () async => picked?.call() ?? [fakeSource('book.pdf')]),
        if (importService != null) importServiceProvider.overrideWithValue(importService),
        // 003: an empty dictionary, a network that says "online", and never the real
        // Wikimedia client or connectivity plugin.
        dictionaryStoreProvider
            .overrideWithValue(dictionaryStore ?? FakeDictionaryStore(FakeLexicon())),
        networkStatusProvider.overrideWithValue(network ?? FakeNetworkStatus()),
        onlineDictionaryProvider.overrideWithValue(online ?? FakeOnlineDictionary()),
        ...overrides,
      ],
      child: const PothaApp(),
    );
  }

  final AppDatabase db;
  final BookFileStore fileStore;
  final PasswordStore passwordStore;
  final FakeKeepAwake keepAwake;
  late final Widget widget;

  Future<void> pump(WidgetTester tester) async {
    await tester.pumpWidget(widget);
    await settleReal(tester);
  }

  /// Unmounts the app and closes the database so no drift timers stay pending.
  Future<void> dispose(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
    // Closing needs real async; it hangs inside the test's fake-async zone.
    await tester.runAsync(db.close);
  }
}

/// A 1×1 PNG, enough to stand in for a cover.
final onePixelPng = Uint8List.fromList(const [
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D, 0x49, 0x48, 0x44,
  0x52, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01, 0x08, 0x06, 0x00, 0x00, 0x00, 0x1F,
  0x15, 0xC4, 0x89, 0x00, 0x00, 0x00, 0x0D, 0x49, 0x44, 0x41, 0x54, 0x78, 0x9C, 0x63, 0x60,
  0x60, 0x60, 0xF8, 0x0F, 0x00, 0x01, 0x04, 0x01, 0x00, 0x5F, 0xE5, 0xC3, 0x4B, 0x00, 0x00,
  0x00, 0x00, 0x49, 0x45, 0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82,
]);

/// Inserts a book straight into the database (outside fake async).
Future<void> seedBook(
  WidgetTester tester,
  AppDatabase db, {
  required String id,
  required String title,
  String? author,
  int pageCount = 300,
  int? currentPage,
  bool cover = false,
  DateTime? addedAt,
  DateTime? lastOpenedAt,
}) async {
  // One batch: a second statement would wait on drift's lock, held by the library's
  // watch query in the fake-async zone.
  await tester.runAsync(() => db.batch((b) {
        b.insert(
            db.books,
            BooksCompanion.insert(
              id: id,
              format: 'pdf',
              title: title,
              author: Value(author),
              sortTitle: sortTitle(title),
              searchKey: searchKey(title, author),
              originalFileName: '$id.pdf',
              contentHash: 'hash-$id',
              sizeBytes: 1000,
              pageCount: pageCount,
              isPasswordProtected: false,
              addedAt: addedAt ?? DateTime.utc(2026, 10, 1),
              lastOpenedAt: Value(lastOpenedAt),
            ));
        if (cover) {
          b.insert(db.bookCovers, BookCoversCompanion.insert(bookId: id, image: onePixelPng));
        }
        if (currentPage != null) {
          b.insert(
              db.readingProgress,
              ReadingProgressCompanion.insert(
                  bookId: id, currentPage: currentPage, updatedAt: DateTime.utc(2026, 10, 2)));
        }
      }));
  await settleReal(tester);
}

/// Lets real async work (drift queries, image decoding) finish, then rebuilds.
Future<void> settleReal(WidgetTester tester) async {
  for (var i = 0; i < 3; i++) {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
    await tester.pump();
  }
}

/// Taps the "Add book" app-bar action.
Future<void> tapAddBook(WidgetTester tester) async {
  await tester.tap(find.byTooltip('Add book'));
  await tester.pump();
}
