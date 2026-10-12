import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:potha/core/db/app_database.dart';
import 'package:potha/core/document/reading_position.dart';
import 'package:potha/features/library/data/library_repository.dart';
import 'package:potha/features/reader/progress_saver.dart';

void main() {
  group('ProgressSaver', () {
    late List<ReadingPosition> writes;
    late ProgressSaver saver;

    ReadingPosition p(int page, [double offset = 0]) => ReadingPosition(page, offset);

    setUp(() {
      writes = [];
      saver = ProgressSaver(pageCount: 10, save: (position) async => writes.add(position));
    });

    testWidgets('writes at most once per second, with the latest position', (tester) async {
      saver.positionChanged(p(2));
      saver.positionChanged(p(3));
      saver.positionChanged(p(4, 0.5));
      expect(writes, isEmpty);

      await tester.pump(const Duration(milliseconds: 999));
      expect(writes, isEmpty);
      await tester.pump(const Duration(milliseconds: 1));
      expect(writes, [p(4, 0.5)]);

      saver.positionChanged(p(5));
      await tester.pump(const Duration(milliseconds: 500));
      saver.positionChanged(p(6));
      await tester.pump(const Duration(milliseconds: 500));
      expect(writes, [p(4, 0.5), p(6)]);
      await saver.dispose();
    });

    testWidgets('dispose flushes the last position', (tester) async {
      saver.positionChanged(p(7, 0.2));
      await saver.dispose();
      expect(writes, [p(7, 0.2)]);
      await tester.pump(const Duration(seconds: 2));
      expect(writes, [p(7, 0.2)]);
    });

    testWidgets('flush writes at once and cancels the pending timer', (tester) async {
      saver.positionChanged(p(3, 0.4));
      await saver.flush();
      expect(writes, [p(3, 0.4)]);
      await tester.pump(const Duration(seconds: 2));
      expect(writes, [p(3, 0.4)]);
      await saver.dispose();
    });

    testWidgets('does not write an unchanged position again', (tester) async {
      saver.positionChanged(p(3, 0.25));
      await tester.pump(const Duration(seconds: 1));
      saver.positionChanged(p(3, 0.25));
      await saver.dispose();
      expect(writes, [p(3, 0.25)]);
    });

    testWidgets('skips a write when only the offset moved by under 1% of a page',
        (tester) async {
      saver.positionChanged(p(3, 0.500));
      await tester.pump(const Duration(seconds: 1));
      saver.positionChanged(p(3, 0.505));
      await tester.pump(const Duration(seconds: 1));
      saver.positionChanged(p(3, 0.52));
      await saver.dispose();
      expect(writes, [p(3, 0.5), p(3, 0.52)]);
    });

    testWidgets('clamps pages to 1..pageCount and offsets to 0..1', (tester) async {
      saver.positionChanged(p(0, -1));
      await tester.pump(const Duration(seconds: 1));
      saver.positionChanged(p(99, 2));
      await saver.dispose();
      expect(writes, [p(1), p(10, 1)]);
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
