// Library queries and updates. See contracts/storage-and-import.md and data-model.md.
import 'package:drift/drift.dart' show Value, Variable;
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/db/app_database.dart';
import '../../../core/db/connection.dart';
import '../../../core/secure/password_store.dart';
import '../../../core/storage/book_file_store.dart';
import '../domain/progress.dart' as lib_progress;
import '../domain/text_fold.dart';

/// What the library shows for one book. Carries no image bytes (SC-003).
@immutable
class BookSummary {
  const BookSummary({
    required this.id,
    required this.title,
    required this.author,
    required this.pageCount,
    required this.currentPage,
    required this.hasCover,
  });

  final String id;
  final String title;
  final String? author;
  final int pageCount;

  /// Null if the book has never been opened.
  final int? currentPage;
  final bool hasCover;

  /// "New" or "NN%" (FR-013).
  String get progressLabel => lib_progress.progressLabel(
        currentPage: currentPage,
        pageCount: pageCount,
      );
}

class LibraryRepository {
  LibraryRepository(this._db, {this.files, this.passwords});

  final AppDatabase _db;
  final BookFileStore? files;
  final PasswordStore? passwords;

  /// Removes a book (FR-021): the database row first (its cover and progress go with
  /// it), then Potha's copy of the file, then any remembered password. The reader's
  /// original file is never touched. A file left behind by a failed delete is removed
  /// by the startup cleanup.
  Future<void> remove(String bookId) async {
    await (_db.delete(_db.books)..where((b) => b.id.equals(bookId))).go();
    try {
      await files?.delete(bookId);
    } catch (_) {
      // Orphaned file; cleaned up on next launch.
    }
    await passwords?.delete(bookId);
  }

  /// Sort orders from data-model.md (FR-017).
  static const _orderBy = {
    SortOrder.recentlyOpened:
        'b.last_opened_at IS NULL, b.last_opened_at DESC, b.added_at DESC',
    SortOrder.recentlyAdded: 'b.added_at DESC',
    SortOrder.title: 'b.sort_title ASC, b.added_at DESC',
  };

  /// Books in [sort] order, filtered by title or author when [query] is not blank
  /// (FR-018). Matching ignores case and accents; `instr` keeps % and _ literal.
  Stream<List<BookSummary>> watchBooks({
    SortOrder sort = SortOrder.recentlyOpened,
    String query = '',
  }) {
    final folded = fold(query.trim());
    return _db
        .customSelect(
          'SELECT b.id, b.title, b.author, b.page_count, p.current_page, '
          'EXISTS (SELECT 1 FROM book_covers c WHERE c.book_id = b.id) AS has_cover '
          'FROM books b LEFT JOIN reading_progress p ON p.book_id = b.id '
          '${folded.isEmpty ? '' : 'WHERE instr(b.search_key, ?) > 0 '}'
          'ORDER BY ${_orderBy[sort]}',
          variables: [if (folded.isNotEmpty) Variable.withString(folded)],
          readsFrom: {_db.books, _db.readingProgress, _db.bookCovers},
        )
        .watch()
        .map((rows) => [
              for (final row in rows)
                BookSummary(
                  id: row.read<String>('id'),
                  title: row.read<String>('title'),
                  author: row.readNullable<String>('author'),
                  pageCount: row.read<int>('page_count'),
                  currentPage: row.readNullable<int>('current_page'),
                  hasCover: row.read<bool>('has_cover'),
                ),
            ]);
  }

  Future<Uint8List?> cover(String bookId) async {
    final row = await (_db.select(_db.bookCovers)..where((c) => c.bookId.equals(bookId)))
        .getSingleOrNull();
    return row?.image;
  }

  Future<Book?> findByHash(String contentHash) =>
      (_db.select(_db.books)..where((b) => b.contentHash.equals(contentHash)))
          .getSingleOrNull();

  Future<Book?> findById(String bookId) =>
      (_db.select(_db.books)..where((b) => b.id.equals(bookId))).getSingleOrNull();

  Future<Set<String>> allBookIds() async =>
      (await _db.select(_db.books).map((b) => b.id).get()).toSet();

  Stream<LibraryPreference> watchPreferences() =>
      (_db.select(_db.libraryPreferences)..where((p) => p.id.equals(1))).watchSingle();

  /// Saves the reader's sort order and view mode (FR-019).
  Future<void> updatePreferences({SortOrder? sortOrder, ViewMode? viewMode}) =>
      (_db.update(_db.libraryPreferences)..where((p) => p.id.equals(1))).write(
        LibraryPreferencesCompanion(
          sortOrder: sortOrder == null ? const Value.absent() : Value(sortOrder),
          viewMode: viewMode == null ? const Value.absent() : Value(viewMode),
        ),
      );

  Future<LibraryPreference> _preferences() =>
      (_db.select(_db.libraryPreferences)..where((p) => p.id.equals(1))).getSingle();

  Future<bool> webStorageNoticeShown() async =>
      (await _preferences()).webStorageNoticeShown;

  Future<void> markWebStorageNoticeShown() =>
      (_db.update(_db.libraryPreferences)..where((p) => p.id.equals(1)))
          .write(const LibraryPreferencesCompanion(webStorageNoticeShown: Value(true)));

  Future<void> markOpened(String bookId, {DateTime? at}) =>
      (_db.update(_db.books)..where((b) => b.id.equals(bookId)))
          .write(BooksCompanion(lastOpenedAt: Value((at ?? DateTime.now()).toUtc())));

  /// Saves the page where the reader last stopped (FR-016b).
  Future<void> saveProgress(String bookId, int currentPage) =>
      _db.into(_db.readingProgress).insertOnConflictUpdate(ReadingProgressCompanion.insert(
            bookId: bookId,
            currentPage: currentPage,
            updatedAt: DateTime.now().toUtc(),
          ));

  Future<int?> currentPage(String bookId) async =>
      (await (_db.select(_db.readingProgress)..where((p) => p.bookId.equals(bookId)))
              .getSingleOrNull())
          ?.currentPage;

  /// Inserts a book and its cover in one transaction. [beforeCommit] runs inside the
  /// transaction (e.g. moving the staged file); if it throws, nothing is inserted.
  Future<void> insertBook(
    BooksCompanion book, {
    Uint8List? cover,
    Future<void> Function()? beforeCommit,
  }) =>
      _db.transaction(() async {
        await _db.into(_db.books).insert(book);
        if (cover != null) {
          await _db
              .into(_db.bookCovers)
              .insert(BookCoversCompanion.insert(bookId: book.id.value, image: cover));
        }
        await beforeCommit?.call();
      });
}

final libraryRepositoryProvider = Provider<LibraryRepository>((ref) => LibraryRepository(
      ref.watch(appDatabaseProvider),
      files: ref.watch(bookFileStoreProvider),
      passwords: ref.watch(passwordStoreProvider),
    ));
