import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:potha/core/db/app_database.dart';
import 'package:potha/core/document/reading_position.dart';
import 'package:potha/features/library/data/library_repository.dart';
import 'package:potha/features/reader/data/reader_repository.dart';

void main() {
  late AppDatabase db;
  late ReaderRepository repo;

  Future<void> addBook(String id) => db.into(db.books).insert(BooksCompanion.insert(
        id: id,
        format: 'pdf',
        title: id,
        sortTitle: id,
        searchKey: id,
        originalFileName: '$id.pdf',
        contentHash: 'hash-$id',
        sizeBytes: 1,
        pageCount: 100,
        isPasswordProtected: false,
        addedAt: DateTime.utc(2026),
        lastOpenedAt: const Value(null),
      ));

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    repo = ReaderRepository(db, clock: () => DateTime.utc(2026, 10, 12, 9));
    await addBook('a');
    await addBook('b');
  });
  tearDown(() => db.close());

  test('a new book has no saved position', () async {
    expect(await repo.loadPosition('a'), isNull);
  });

  test('savePosition stores page and offset, and the library follows the page (FR-013)',
      () async {
    await repo.savePosition('a', const ReadingPosition(57, 0.5));
    expect(await repo.loadPosition('a'), const ReadingPosition(57, 0.5));
    expect(await LibraryRepository(db).currentPage('a'), 57);
    final row = await db.select(db.readingProgress).getSingle();
    expect(row.updatedAt.toUtc(), DateTime.utc(2026, 10, 12, 9));

    await repo.savePosition('a', const ReadingPosition(58, 0.1));
    expect(await repo.loadPosition('a'), const ReadingPosition(58, 0.1));
  });

  test('a position saved by 001 (page only) loads at the top of that page (FR-014)', () async {
    await LibraryRepository(db).saveProgress('a', 12);
    expect(await repo.loadPosition('a'), const ReadingPosition(12, 0));
  });

  test('the page mode is paged by default and kept per book (FR-009)', () async {
    expect(await repo.pageMode('a'), PageMode.paged);
    await repo.setPageMode('a', PageMode.continuous);
    expect(await repo.pageMode('a'), PageMode.continuous);
    expect(await repo.pageMode('b'), PageMode.paged);
  });

  test('saving a position keeps the page mode, and setting a mode keeps the position',
      () async {
    await repo.savePosition('a', const ReadingPosition(9, 0.3));
    await repo.setPageMode('a', PageMode.continuous);
    expect(await repo.loadPosition('a'), const ReadingPosition(9, 0.3));
    await repo.savePosition('a', const ReadingPosition(10, 0));
    expect(await repo.pageMode('a'), PageMode.continuous);
  });

  test('watchPreferences emits the defaults, then changes', () async {
    final seen = <(ReadingTheme, PageFit)>[];
    final sub = repo.watchPreferences().listen((p) => seen.add((p.theme, p.fit)));
    await pumpEventQueue();
    await repo.setTheme(ReadingTheme.dark);
    await pumpEventQueue();
    await repo.setFit(PageFit.fitPage);
    await pumpEventQueue();
    await sub.cancel();
    expect(seen.first, (ReadingTheme.light, PageFit.fitWidth));
    expect(seen.last, (ReadingTheme.dark, PageFit.fitPage));
  });

  test('tap-to-define and the lookup hint start off, and can be set (003 FR-006, FR-015)',
      () async {
    final seen = <(bool, bool)>[];
    final sub = repo.watchPreferences().listen((p) => seen.add((p.tapToDefine, p.lookupHintShown)));
    await pumpEventQueue();
    await repo.setTapToDefine(true);
    await pumpEventQueue();
    await repo.markLookupHintShown();
    await pumpEventQueue();
    await sub.cancel();
    expect(seen.first, (false, false));
    expect(seen.last, (true, true));
    await repo.setTapToDefine(false);
    expect((await repo.watchPreferences().first).tapToDefine, isFalse);
  });
}
