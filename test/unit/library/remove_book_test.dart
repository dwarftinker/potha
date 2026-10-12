import 'dart:io';
import 'dart:typed_data';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:potha/core/db/app_database.dart';
import 'package:potha/core/secure/password_store.dart';
import 'package:potha/core/storage/book_file_store_io.dart';
import 'package:potha/features/library/data/library_repository.dart';

class RecordingPasswords implements PasswordStore {
  final saved = <String, String>{};
  final calls = <String>[];
  @override
  Future<String?> read(String bookId) async => saved[bookId];
  @override
  Future<void> write(String bookId, String password) async => saved[bookId] = password;
  @override
  Future<void> delete(String bookId) async {
    calls.add('password');
    saved.remove(bookId);
  }
}

/// IO store whose delete can be made to fail.
class FlakyStore extends IoBookFileStore {
  FlakyStore(Directory root) : super(root: () async => root);
  bool failDelete = false;
  final calls = <String>[];
  @override
  Future<void> delete(String bookId) async {
    calls.add('file');
    if (failDelete) throw const FileSystemException('busy');
    await super.delete(bookId);
  }
}

void main() {
  late Directory root;
  late AppDatabase db;
  late FlakyStore store;
  late RecordingPasswords passwords;
  late LibraryRepository repo;
  late File original;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('potha_remove');
    db = AppDatabase(NativeDatabase.memory());
    store = FlakyStore(root);
    passwords = RecordingPasswords()..saved['a'] = 'secret';
    repo = LibraryRepository(db, files: store, passwords: passwords);

    // The reader's original file, outside the app's storage.
    original = File('${root.path}/original.pdf')..writeAsBytesSync([1, 2, 3]);
    await store.commit(await store.stage(original.openRead()), 'a');
    await db.into(db.books).insert(BooksCompanion.insert(
          id: 'a',
          format: 'pdf',
          title: 'A',
          sortTitle: 'a',
          searchKey: 'a',
          originalFileName: 'original.pdf',
          contentHash: 'h',
          sizeBytes: 3,
          pageCount: 3,
          isPasswordProtected: true,
          addedAt: DateTime.utc(2026),
          lastOpenedAt: const Value(null),
        ));
    await db.into(db.bookCovers).insert(BookCoversCompanion.insert(bookId: 'a', image: Uint8List(1)));
    await repo.saveProgress('a', 2);
  });

  tearDown(() async {
    await db.close();
    await root.delete(recursive: true);
  });

  test('removes the row, cover, progress, file and password (FR-021)', () async {
    await repo.remove('a');

    expect(await db.select(db.books).get(), isEmpty);
    expect(await db.select(db.bookCovers).get(), isEmpty);
    expect(await db.select(db.readingProgress).get(), isEmpty);
    expect(await store.find('a'), isNull);
    expect(passwords.saved, isEmpty);
    expect(store.calls, ['file']);
    expect(passwords.calls, ['password']);
  });

  test('never touches the original file (SC-008)', () async {
    await repo.remove('a');
    expect(original.readAsBytesSync(), [1, 2, 3]);
  });

  test('if the file delete fails, the row is still gone and cleanUp removes the orphan',
      () async {
    store.failDelete = true;
    await repo.remove('a');
    expect(await db.select(db.books).get(), isEmpty);
    expect(passwords.saved, isEmpty);
    expect(await store.find('a'), isNotNull);

    await store.cleanUp(await repo.allBookIds());
    expect(await store.find('a'), isNull);
  });
}
