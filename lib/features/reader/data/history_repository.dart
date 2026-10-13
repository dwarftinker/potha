// Lookup history (003 US8, data-model.md "lookup_history"): one line per word per book,
// kept on the device (FR-032), removed with the book (FR-027).
import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/db/app_database.dart';
import '../../../core/db/connection.dart';

@immutable
class HistoryLine {
  const HistoryLine({
    required this.bookId,
    required this.wordKey,
    required this.word,
    required this.headword,
    required this.source,
    required this.page,
    required this.lookedUpAt,
    required this.count,
    this.bookTitle,
  });

  final String bookId;
  final String wordKey;
  final String word;
  final String? headword;
  final LookupSource source;
  final int page;
  final DateTime lookedUpAt;
  final int count;

  /// Only in "All books".
  final String? bookTitle;
}

class HistoryRepository {
  HistoryRepository(this._db, {DateTime Function()? clock}) : _clock = clock ?? DateTime.now;

  final AppDatabase _db;
  final DateTime Function() _clock;

  /// Records a lookup: a new line, or the line for this word in this book updated with
  /// the latest word, entry, page and time, its count raised by one. With [newLookup]
  /// false (an online result for the same lookup), the count stays.
  Future<void> record({
    required String bookId,
    required String wordKey,
    required String word,
    required String? headword,
    required LookupSource source,
    required int page,
    bool newLookup = true,
  }) {
    final now = _clock().toUtc();
    final t = _db.lookupHistory;
    return _db
        .into(t)
        .insert(
          LookupHistoryCompanion.insert(
            bookId: bookId,
            wordKey: wordKey,
            word: word,
            headword: Value(headword),
            source: source,
            page: page,
            lookedUpAt: now,
          ),
          onConflict: DoUpdate(
            (old) => LookupHistoryCompanion.custom(
              word: Variable(word),
              headword: Variable(headword),
              source: Variable(source.name),
              page: Variable(page),
              lookedUpAt: Variable(now),
              count: newLookup ? old.count + const Constant(1) : old.count,
            ),
          ),
        );
  }

  /// This book's words, newest first.
  Stream<List<HistoryLine>> watchBook(String bookId) {
    final t = _db.lookupHistory;
    return (_db.select(t)
          ..where((h) => h.bookId.equals(bookId))
          ..orderBy([(h) => OrderingTerm.desc(h.lookedUpAt)]))
        .watch()
        .map((rows) => [for (final r in rows) _line(r)]);
  }

  /// Every book's words with the book's title, newest first.
  Stream<List<HistoryLine>> watchAll() {
    final t = _db.lookupHistory;
    final query = _db.select(t).join([innerJoin(_db.books, _db.books.id.equalsExp(t.bookId))])
      ..orderBy([OrderingTerm.desc(t.lookedUpAt)]);
    return query.watch().map(
      (rows) => [for (final r in rows) _line(r.readTable(t), title: r.readTable(_db.books).title)],
    );
  }

  Future<void> clearBook(String bookId) =>
      (_db.delete(_db.lookupHistory)..where((h) => h.bookId.equals(bookId))).go();

  Future<void> clearAll() => _db.delete(_db.lookupHistory).go();

  static HistoryLine _line(LookupHistoryData r, {String? title}) => HistoryLine(
    bookId: r.bookId,
    wordKey: r.wordKey,
    word: r.word,
    headword: r.headword,
    source: r.source,
    page: r.page,
    lookedUpAt: r.lookedUpAt.toUtc(),
    count: r.count,
    bookTitle: title,
  );
}

final historyRepositoryProvider = Provider<HistoryRepository>(
  (ref) => HistoryRepository(ref.watch(appDatabaseProvider)),
);
