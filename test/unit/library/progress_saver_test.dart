import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:potha/core/db/app_database.dart';
import 'package:potha/features/library/data/library_repository.dart';
import 'package:potha/features/reader/progress_saver.dart';

void main() {
  group('ProgressSaver', () {
    late List<int> writes;
    late ProgressSaver saver;

    setUp(() {
      writes = [];
      saver = ProgressSaver(pageCount: 10, save: (page) async => writes.add(page));
    });

    testWidgets('writes at most once per second, with the latest page', (tester) async {
      saver.pageChanged(2);
      saver.pageChanged(3);
      saver.pageChanged(4);
      expect(writes, isEmpty);

      await tester.pump(const Duration(milliseconds: 999));
      expect(writes, isEmpty);
      await tester.pump(const Duration(milliseconds: 1));
      expect(writes, [4]);

      saver.pageChanged(5);
      await tester.pump(const Duration(milliseconds: 500));
      saver.pageChanged(6);
      await tester.pump(const Duration(milliseconds: 500));
      expect(writes, [4, 6]);
      await saver.dispose();
    });

    testWidgets('dispose flushes the last page', (tester) async {
      saver.pageChanged(7);
      await saver.dispose();
      expect(writes, [7]);
      await tester.pump(const Duration(seconds: 2));
      expect(writes, [7]);
    });

    testWidgets('does not write an unchanged page again', (tester) async {
      saver.pageChanged(3);
      await tester.pump(const Duration(seconds: 1));
      saver.pageChanged(3);
      await saver.dispose();
      expect(writes, [3]);
    });

    testWidgets('clamps pages to 1..pageCount', (tester) async {
      saver.pageChanged(0);
      await tester.pump(const Duration(seconds: 1));
      saver.pageChanged(99);
      await saver.dispose();
      expect(writes, [1, 10]);
    });
  });

  group('LibraryRepository progress', () {
    late AppDatabase db;
    late LibraryRepository repo;

    setUp(() async {
      db = AppDatabase(NativeDatabase.memory());
      repo = LibraryRepository(db);
      await db.into(db.books).insert(BooksCompanion.insert(
            id: 'a',
            format: 'pdf',
            title: 'A',
            sortTitle: 'a',
            searchKey: 'a',
            originalFileName: 'a.pdf',
            contentHash: 'h',
            sizeBytes: 1,
            pageCount: 10,
            isPasswordProtected: false,
            addedAt: DateTime.utc(2026),
            lastOpenedAt: const Value(null),
          ));
    });
    tearDown(() => db.close());

    test('markOpened sets lastOpenedAt', () async {
      await repo.markOpened('a', at: DateTime.utc(2026, 10, 12, 8));
      expect((await repo.findById('a'))!.lastOpenedAt!.toUtc(), DateTime.utc(2026, 10, 12, 8));
    });

    test('saveProgress upserts the current page', () async {
      expect(await repo.currentPage('a'), isNull);
      await repo.saveProgress('a', 4);
      await repo.saveProgress('a', 2);
      expect(await repo.currentPage('a'), 2);
      expect(await db.select(db.readingProgress).get(), hasLength(1));
    });
  });
}
