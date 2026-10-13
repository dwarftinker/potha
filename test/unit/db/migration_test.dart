// Guards data across app updates (001 FR-024, SC-006).
//
// After changing a table: bump AppDatabase.schemaVersion, then run
//   dart run drift_dev make-migrations
//   dart run drift_dev schema generate drift_schemas/app_database/ test/unit/db/generated/
// write the step in AppDatabase.migration (stepByStep, from app_database.steps.dart), delete
// the test/unit/db/migrations/ folder make-migrations creates (this file replaces it), and add
// a test below that migrates from the previous version and checks the data.
import 'package:drift/drift.dart';
import 'package:drift_dev/api/migrations_native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:potha/core/db/app_database.dart';

import 'generated/schema.dart';

void main() {
  late SchemaVerifier verifier;

  setUpAll(() => verifier = SchemaVerifier(GeneratedHelper()));

  test('a fresh v2 database matches the saved v2 snapshot', () async {
    final connection = await verifier.startAt(2);
    final db = AppDatabase(connection);
    await verifier.migrateAndValidate(db, 2);
    await db.close();
  });

  group('v1 to v2 (002 reader)', () {
    late AppDatabase db;

    setUp(() async {
      final schema = await verifier.schemaAt(1);
      final raw = schema.rawDatabase;
      for (final (id, page) in [('a', 5), ('b', 57)]) {
        raw.execute(
          "INSERT INTO books (id, format, title, sort_title, search_key, original_file_name, "
          "content_hash, size_bytes, page_count, is_password_protected, added_at) "
          "VALUES ('$id', 'pdf', 'Book $id', 'book $id', 'book $id', '$id.pdf', 'hash-$id', "
          "100, 100, 0, 0)",
        );
        raw.execute(
          "INSERT INTO reading_progress (book_id, current_page, updated_at) VALUES ('$id', $page, 0)",
        );
      }
      db = AppDatabase(schema.newConnection());
      await verifier.migrateAndValidate(db, 2);
    });

    tearDown(() => db.close());

    test('progress rows keep their page and get offset 0 and no page mode (FR-014)', () async {
      final rows = await (db.select(db.readingProgress)
            ..orderBy([(t) => OrderingTerm(expression: t.bookId)]))
          .get();
      expect(rows.map((r) => (r.bookId, r.currentPage, r.pageOffset, r.pageMode)), [
        ('a', 5, 0.0, null),
        ('b', 57, 0.0, null),
      ]);
    });

    test('reader preferences row 1 exists with light theme and fit width', () async {
      final prefs = await db.select(db.readerPreferences).getSingle();
      expect((prefs.id, prefs.theme, prefs.fit), (1, ReadingTheme.light, PageFit.fitWidth));
    });

    test('page offset outside 0..1 is rejected', () async {
      final update = db.update(db.readingProgress)..where((t) => t.bookId.equals('a'));
      expect(
        () => update.write(const ReadingProgressCompanion(pageOffset: Value(1.5))),
        throwsA(isA<Exception>()),
      );
      expect(
        () => update.write(const ReadingProgressCompanion(pageOffset: Value(-0.1))),
        throwsA(isA<Exception>()),
      );
      await update.write(const ReadingProgressCompanion(
          pageOffset: Value(1.0), pageMode: Value(PageMode.continuous)));
    });
  });
}
