// Reading position, page mode and reader preferences (002 data-model.md).
import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/db/app_database.dart';
import '../../../core/db/connection.dart';
import '../../../core/document/reading_position.dart';

class ReaderRepository {
  ReaderRepository(this._db, {DateTime Function()? clock}) : _clock = clock ?? DateTime.now;

  final AppDatabase _db;
  final DateTime Function() _clock;

  SimpleSelectStatement<$ReadingProgressTable, ReadingProgressData> _progress(String bookId) =>
      _db.select(_db.readingProgress)..where((p) => p.bookId.equals(bookId));

  /// The saved position, or null if the book has never been opened.
  Future<ReadingPosition?> loadPosition(String bookId) async {
    final row = await _progress(bookId).getSingleOrNull();
    return row == null ? null : ReadingPosition(row.currentPage, row.pageOffset);
  }

  /// Saves the position (FR-011). The library's progress follows `current_page`.
  Future<void> savePosition(String bookId, ReadingPosition position) => _db
      .into(_db.readingProgress)
      .insert(
        ReadingProgressCompanion.insert(
          bookId: bookId,
          currentPage: position.page,
          pageOffset: Value(position.offsetY),
          updatedAt: _clock().toUtc(),
        ),
        onConflict: DoUpdate(
          (_) => ReadingProgressCompanion(
            currentPage: Value(position.page),
            pageOffset: Value(position.offsetY),
            updatedAt: Value(_clock().toUtc()),
          ),
        ),
      );

  /// The book's page mode; paged until the reader chooses otherwise (FR-009).
  Future<PageMode> pageMode(String bookId) async =>
      (await _progress(bookId).getSingleOrNull())?.pageMode ?? PageMode.paged;

  Future<void> setPageMode(String bookId, PageMode mode) => _db
      .into(_db.readingProgress)
      .insert(
        ReadingProgressCompanion.insert(
          bookId: bookId,
          currentPage: 1,
          pageMode: Value(mode),
          updatedAt: _clock().toUtc(),
        ),
        onConflict: DoUpdate((_) => ReadingProgressCompanion(pageMode: Value(mode))),
      );

  Stream<ReaderPreference> watchPreferences() =>
      (_db.select(_db.readerPreferences)..where((p) => p.id.equals(1))).watchSingle();

  Future<void> setTheme(ReadingTheme theme) => (_db.update(
    _db.readerPreferences,
  )..where((p) => p.id.equals(1))).write(ReaderPreferencesCompanion(theme: Value(theme)));

  Future<void> setFit(PageFit fit) => (_db.update(
    _db.readerPreferences,
  )..where((p) => p.id.equals(1))).write(ReaderPreferencesCompanion(fit: Value(fit)));

  /// 003 FR-015.
  Future<void> setTapToDefine(bool on) => (_db.update(
    _db.readerPreferences,
  )..where((p) => p.id.equals(1))).write(ReaderPreferencesCompanion(tapToDefine: Value(on)));

  /// The one-time lookup hint has been seen (003 FR-006).
  Future<void> markLookupHintShown() =>
      (_db.update(_db.readerPreferences)..where((p) => p.id.equals(1))).write(
        const ReaderPreferencesCompanion(lookupHintShown: Value(true)),
      );
}

final readerRepositoryProvider = Provider<ReaderRepository>(
  (ref) => ReaderRepository(ref.watch(appDatabaseProvider)),
);
