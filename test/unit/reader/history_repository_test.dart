// Lookup history: one line per word per book (003 US8, FR-025 to FR-027, clarification Q5).
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:potha/core/db/app_database.dart';
import 'package:potha/features/library/data/library_repository.dart';
import 'package:potha/features/reader/data/history_repository.dart';

void main() {
  late AppDatabase db;
  late HistoryRepository repo;
  var now = DateTime.utc(2026, 10, 13, 9);

  Future<void> addBook(String id, String title) => db
      .into(db.books)
      .insert(
        BooksCompanion.insert(
          id: id,
          format: 'pdf',
          title: title,
          sortTitle: title.toLowerCase(),
          searchKey: title.toLowerCase(),
          originalFileName: '$id.pdf',
          contentHash: 'hash-$id',
          sizeBytes: 1,
          pageCount: 100,
          isPasswordProtected: false,
          addedAt: DateTime.utc(2026),
          lastOpenedAt: const Value(null),
        ),
      );

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    now = DateTime.utc(2026, 10, 13, 9);
    repo = HistoryRepository(db, clock: () => now);
    await addBook('a', 'Moby-Dick');
    await addBook('b', 'Emma');
  });
  tearDown(() => db.close());

  Future<void> look(String book, String word, {String? headword, int page = 1}) => repo.record(
    bookId: book,
    wordKey: word.toLowerCase(),
    word: word,
    headword: headword,
    source: headword == null ? LookupSource.none : LookupSource.offline,
    page: page,
  );

  test('the first lookup makes a line; the same word again updates it and counts', () async {
    await look('a', 'Running', headword: 'run', page: 3);
    now = now.add(const Duration(hours: 1));
    await look('a', 'running', headword: 'run', page: 7);
    final lines = await repo.watchBook('a').first;
    expect(lines, hasLength(1));
    final l = lines.single;
    expect((l.word, l.headword, l.page, l.count, l.lookedUpAt), ('running', 'run', 7, 2, now));
  });

  test('the same word in another book is a separate line', () async {
    await look('a', 'whale', headword: 'whale');
    await look('b', 'whale', headword: 'whale');
    expect(await repo.watchBook('a').first, hasLength(1));
    expect(await repo.watchAll().first, hasLength(2));
  });

  test('lists are newest first; All books has the titles', () async {
    await look('a', 'one', headword: 'one');
    now = now.add(const Duration(minutes: 1));
    await look('b', 'two', headword: 'two');
    now = now.add(const Duration(minutes: 1));
    await look('a', 'three');
    expect((await repo.watchBook('a').first).map((l) => l.word), ['three', 'one']);
    final all = await repo.watchAll().first;
    expect(all.map((l) => (l.word, l.bookTitle)), [
      ('three', 'Moby-Dick'),
      ('two', 'Emma'),
      ('one', 'Moby-Dick'),
    ]);
    expect(all.first.headword, isNull, reason: 'not found');
  });

  test('an online result updates the line without counting again', () async {
    await look('a', 'serendipity');
    await repo.record(
      bookId: 'a',
      wordKey: 'serendipity',
      word: 'serendipity',
      headword: 'serendipity',
      source: LookupSource.online,
      page: 1,
      newLookup: false,
    );
    final l = (await repo.watchBook('a').first).single;
    expect((l.count, l.source, l.headword), (1, LookupSource.online, 'serendipity'));
  });

  test('clearBook and clearAll', () async {
    await look('a', 'one');
    await look('b', 'two');
    await repo.clearBook('a');
    expect(await repo.watchBook('a').first, isEmpty);
    expect(await repo.watchBook('b').first, hasLength(1));
    await repo.clearAll();
    expect(await repo.watchAll().first, isEmpty);
  });

  test('removing a book removes its lines (FR-027)', () async {
    await look('a', 'one');
    await look('b', 'two');
    await LibraryRepository(db).remove('a');
    expect((await repo.watchAll().first).map((l) => l.bookId), ['b']);
  });

  test('watchBook emits again after a lookup', () async {
    final seen = <int>[];
    final sub = repo.watchBook('a').listen((l) => seen.add(l.length));
    await pumpEventQueue();
    await look('a', 'one');
    await pumpEventQueue();
    await sub.cancel();
    expect(seen, [0, 1]);
  });
}
