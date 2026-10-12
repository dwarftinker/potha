import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:potha/core/db/app_database.dart';

BooksCompanion book(String id, {String hash = 'h1'}) => BooksCompanion.insert(
      id: id,
      format: 'pdf',
      title: 'Title $id',
      sortTitle: 'title $id',
      searchKey: 'title $id',
      originalFileName: '$id.pdf',
      contentHash: hash,
      sizeBytes: 100,
      pageCount: 3,
      isPasswordProtected: false,
      addedAt: DateTime.utc(2026, 10, 1),
    );

void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  test('preferences row exists with defaults after creation', () async {
    final prefs = await db.select(db.libraryPreferences).getSingle();
    expect(prefs.id, 1);
    expect(prefs.sortOrder, SortOrder.recentlyOpened);
    expect(prefs.viewMode, ViewMode.grid);
    expect(prefs.webStorageNoticeShown, isFalse);
  });

  test('contentHash must be unique', () async {
    await db.into(db.books).insert(book('a', hash: 'same'));
    expect(
      () => db.into(db.books).insert(book('b', hash: 'same')),
      throwsA(isA<SqliteException>()),
    );
  });

  test('deleting a book cascades to its cover and progress', () async {
    await db.into(db.books).insert(book('a'));
    await db.into(db.bookCovers).insert(
        BookCoversCompanion.insert(bookId: 'a', image: Uint8List.fromList([1, 2])));
    await db.into(db.readingProgress).insert(ReadingProgressCompanion.insert(
        bookId: 'a', currentPage: 2, updatedAt: DateTime.utc(2026, 10, 2)));

    await (db.delete(db.books)..where((b) => b.id.equals('a'))).go();

    expect(await db.select(db.bookCovers).get(), isEmpty);
    expect(await db.select(db.readingProgress).get(), isEmpty);
  });

  test('pageCount must be greater than zero', () async {
    expect(
      () => db.into(db.books).insert(book('a').copyWith(pageCount: const Value(0))),
      throwsA(isA<SqliteException>()),
    );
  });
}
