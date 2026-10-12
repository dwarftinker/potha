import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:potha/core/db/app_database.dart';
import 'package:potha/features/library/data/library_repository.dart';
import 'package:potha/features/library/domain/text_fold.dart';

void main() {
  late AppDatabase db;
  late LibraryRepository repo;

  Future<void> add(String id, String title,
      {String? author, required int addedDay, int? openedDay}) async {
    await db.into(db.books).insert(BooksCompanion.insert(
          id: id,
          format: 'pdf',
          title: title,
          author: Value(author),
          sortTitle: sortTitle(title),
          searchKey: searchKey(title, author),
          originalFileName: '$id.pdf',
          contentHash: 'hash-$id',
          sizeBytes: 1,
          pageCount: 10,
          isPasswordProtected: false,
          addedAt: DateTime.utc(2026, 10, addedDay),
          lastOpenedAt: Value(openedDay == null ? null : DateTime.utc(2026, 10, openedDay)),
        ));
  }

  Future<List<String>> ids({SortOrder sort = SortOrder.recentlyOpened, String query = ''}) async =>
      (await repo.watchBooks(sort: sort, query: query).first).map((b) => b.id).toList();

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    repo = LibraryRepository(db);
    await add('idiot', 'The Idiot', author: 'Fyodor Dostoevsky', addedDay: 1, openedDay: 5);
    await add('anna', 'Anna Karenina', author: 'Lev TOLSTÓY', addedDay: 2);
    await add('war', 'War and Peace', author: 'Leo Tolstoy', addedDay: 3, openedDay: 8);
    await add('emma', 'Emma', addedDay: 4);
  });
  tearDown(() => db.close());

  test('recently opened: opened books newest first, then never-opened by date added', () async {
    expect(await ids(), ['war', 'idiot', 'emma', 'anna']);
  });

  test('recently added: newest first', () async {
    expect(await ids(sort: SortOrder.recentlyAdded), ['emma', 'war', 'anna', 'idiot']);
  });

  test('title: A–Z ignoring a leading article', () async {
    expect(await ids(sort: SortOrder.title), ['anna', 'emma', 'idiot', 'war']);
  });

  test('search matches title or author, ignoring case and accents', () async {
    expect((await ids(query: 'tolst')).toSet(), {'anna', 'war'});
    expect(await ids(query: 'TOLSTÓY', sort: SortOrder.title), ['anna', 'war']);
    expect(await ids(query: 'idio'), ['idiot']);
    expect(await ids(query: '  emma '), ['emma']);
  });

  test('an empty query returns everything; % and _ are literal', () async {
    expect(await ids(query: ''), hasLength(4));
    expect(await ids(query: '%'), isEmpty);
    expect(await ids(query: '_'), isEmpty);
  });

  test('sort order and view mode are saved in preferences', () async {
    expect((await repo.watchPreferences().first).sortOrder, SortOrder.recentlyOpened);
    await repo.updatePreferences(sortOrder: SortOrder.title);
    await repo.updatePreferences(viewMode: ViewMode.list);
    final prefs = await repo.watchPreferences().first;
    expect(prefs.sortOrder, SortOrder.title);
    expect(prefs.viewMode, ViewMode.list);
  });
}
