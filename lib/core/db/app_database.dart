import 'package:drift/drift.dart';

import '../document/document_format.dart' show PageFit, PageMode;
import 'app_database.steps.dart';

export '../document/document_format.dart' show PageFit, PageMode;

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
  TextColumn get bookId => text().references(Books, #id, onDelete: KeyAction.cascade)();

  /// PNG, 360 px wide, page 1.
  BlobColumn get image => blob()();

  @override
  Set<Column> get primaryKey => {bookId};
}

/// Where the reader last stopped in a book. No row means "New".
class ReadingProgress extends Table {
  TextColumn get bookId => text().references(Books, #id, onDelete: KeyAction.cascade)();

  /// 1-based; 1 ≤ currentPage ≤ pageCount (enforced by the repository).
  IntColumn get currentPage =>
      // ignore: recursive_getters
      integer().check(currentPage.isBiggerOrEqualValue(1))();
  DateTimeColumn get updatedAt => dateTime()();

  /// Fraction of the page height at the top of the view, 0–1 (002 research R4).
  RealColumn get pageOffset => real()
      .withDefault(const Constant(0.0))
      // ignore: recursive_getters
      .check(pageOffset.isBetweenValues(0.0, 1.0))();

  /// Null means the default, paged (002 FR-009).
  TextColumn get pageMode => textEnum<PageMode>().nullable()();

  @override
  Set<Column> get primaryKey => {bookId};
}

enum SortOrder { recentlyOpened, recentlyAdded, title }

enum ViewMode { grid, list }

/// A single row (id = 1) with the reader's library choices.
class LibraryPreferences extends Table {
  IntColumn get id => integer()();
  TextColumn get sortOrder => textEnum<SortOrder>().withDefault(const Constant('recentlyOpened'))();
  TextColumn get viewMode => textEnum<ViewMode>().withDefault(const Constant('grid'))();
  BoolColumn get webStorageNoticeShown => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}

enum ReadingTheme { light, dark, sepia }

/// A single row (id = 1) with the reader's choices for all books (002).
class ReaderPreferences extends Table {
  IntColumn get id => integer()();
  TextColumn get theme => textEnum<ReadingTheme>().withDefault(const Constant('light'))();
  TextColumn get fit => textEnum<PageFit>().withDefault(const Constant('fitWidth'))();

  /// 003 FR-015: a single tap on a word looks it up. Off by default (clarification Q2).
  BoolColumn get tapToDefine => boolean().withDefault(const Constant(false))();

  /// 003 FR-006: set when the one-time lookup hint is dismissed or a lookup is made.
  BoolColumn get lookupHintShown => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}

/// Where the entry shown for a lookup came from; `none` when nothing was found.
enum LookupSource { offline, online, none }

/// One line per word per book (003 data-model.md, clarification Q5).
@TableIndex(name: 'lookup_history_looked_up_at', columns: {#lookedUpAt})
class LookupHistory extends Table {
  TextColumn get bookId => text().references(Books, #id, onDelete: KeyAction.cascade)();

  /// The normalised lookup key (research R5).
  TextColumn get wordKey => text()();

  /// As the reader saw it, from the latest lookup ("Running").
  TextColumn get word => text()();

  /// The first entry shown ("run"); null if not found.
  TextColumn get headword => text().nullable()();
  TextColumn get source => textEnum<LookupSource>()();

  // ignore: recursive_getters
  IntColumn get page => integer().check(page.isBiggerOrEqualValue(1))();

  /// UTC; history is ordered by this, newest first.
  DateTimeColumn get lookedUpAt => dateTime()();

  IntColumn get count =>
      // ignore: recursive_getters
      integer().withDefault(const Constant(1)).check(count.isBiggerOrEqualValue(1))();

  @override
  Set<Column> get primaryKey => {bookId, wordKey};
}

@DriftDatabase(
  tables: [
    Books,
    BookCovers,
    ReadingProgress,
    LibraryPreferences,
    ReaderPreferences,
    LookupHistory,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.executor);

  @override
  int get schemaVersion => 3;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) async {
      await m.createAll();
      await into(libraryPreferences).insert(LibraryPreferencesCompanion.insert(id: const Value(1)));
      await into(readerPreferences).insert(ReaderPreferencesCompanion.insert(id: const Value(1)));
    },
    onUpgrade: stepByStep(
      from1To2: (m, schema) async {
        // 002 reader: position within the page, page mode, reader preferences.
        await m.addColumn(schema.readingProgress, schema.readingProgress.pageOffset);
        await m.addColumn(schema.readingProgress, schema.readingProgress.pageMode);
        await m.createTable(schema.readerPreferences);
        await customStatement('INSERT INTO reader_preferences (id) VALUES (1)');
      },
      from2To3: (m, schema) async {
        // 003 lookup: history, tap-to-define and the one-time hint.
        await m.createTable(schema.lookupHistory);
        await m.createIndex(schema.lookupHistoryLookedUpAt);
        await m.addColumn(schema.readerPreferences, schema.readerPreferences.tapToDefine);
        await m.addColumn(schema.readerPreferences, schema.readerPreferences.lookupHintShown);
      },
    ),
    beforeOpen: (details) async {
      await customStatement('PRAGMA foreign_keys = ON');
    },
  );
}
