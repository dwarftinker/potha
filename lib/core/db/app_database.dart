import 'package:drift/drift.dart';

part 'app_database.g.dart';

/// A book the reader has imported. See specs/001-library-and-import/data-model.md.
@TableIndex(name: 'books_last_opened_at', columns: {#lastOpenedAt})
@TableIndex(name: 'books_added_at', columns: {#addedAt})
@TableIndex(name: 'books_sort_title', columns: {#sortTitle})
class Books extends Table {
  /// Random UUID v4, created at import.
  TextColumn get id => text()();

  /// `pdf` for now; later formats share the table.
  TextColumn get format => text()();

  /// Never blank (FR-010).
  TextColumn get title => text()();
  TextColumn get author => text().nullable()();
  TextColumn get sortTitle => text()();
  TextColumn get searchKey => text()();
  TextColumn get originalFileName => text()();

  /// SHA-256 of the file, lower-case hex (FR-007).
  TextColumn get contentHash => text().unique()();
  IntColumn get sizeBytes => integer()();
  // ignore: recursive_getters (drift's pattern for column checks)
  IntColumn get pageCount => integer().check(pageCount.isBiggerThanValue(0))();
  BoolColumn get isPasswordProtected => boolean()();

  /// UTC.
  DateTimeColumn get addedAt => dateTime()();

  /// UTC; null until first opened.
  DateTimeColumn get lastOpenedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Cover images, kept apart so list queries don't load image bytes.
class BookCovers extends Table {
  TextColumn get bookId =>
      text().references(Books, #id, onDelete: KeyAction.cascade)();

  /// PNG, 360 px wide, page 1.
  BlobColumn get image => blob()();

  @override
  Set<Column> get primaryKey => {bookId};
}

/// Where the reader last stopped in a book. No row means "New".
class ReadingProgress extends Table {
  TextColumn get bookId =>
      text().references(Books, #id, onDelete: KeyAction.cascade)();

  /// 1-based; 1 ≤ currentPage ≤ pageCount (enforced by the repository).
  IntColumn get currentPage =>
      // ignore: recursive_getters
      integer().check(currentPage.isBiggerOrEqualValue(1))();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {bookId};
}

enum SortOrder { recentlyOpened, recentlyAdded, title }

enum ViewMode { grid, list }

/// A single row (id = 1) with the reader's library choices.
class LibraryPreferences extends Table {
  IntColumn get id => integer()();
  TextColumn get sortOrder => textEnum<SortOrder>()
      .withDefault(Constant(SortOrder.recentlyOpened.name))();
  TextColumn get viewMode =>
      textEnum<ViewMode>().withDefault(Constant(ViewMode.grid.name))();
  BoolColumn get webStorageNoticeShown =>
      boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}

@DriftDatabase(tables: [Books, BookCovers, ReadingProgress, LibraryPreferences])
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.executor);

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) async {
          await m.createAll();
          await into(libraryPreferences)
              .insert(LibraryPreferencesCompanion.insert(id: const Value(1)));
        },
        beforeOpen: (details) async {
          await customStatement('PRAGMA foreign_keys = ON');
        },
      );
}
