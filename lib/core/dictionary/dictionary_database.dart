// The read-only dictionary file built by tool/build_dictionary.py (003 research R3,
// data-model.md "Dictionary database"). At most three indexed queries per lookup.
import 'dart:convert';

import 'package:drift/drift.dart';

import 'lexicon.dart';

class DictionaryDatabase extends GeneratedDatabase implements Lexicon {
  DictionaryDatabase._(super.executor);

  /// Opens the file behind [executor] and reads its `meta` table.
  static Future<DictionaryDatabase> open(QueryExecutor executor) async {
    final db = DictionaryDatabase._(executor);
    try {
      final rows = await db.customSelect('SELECT key, value FROM meta').get();
      db._meta = {for (final r in rows) r.read<String>('key'): r.read<String>('value')};
    } catch (_) {
      await db.close();
      rethrow;
    }
    return db;
  }

  /// Run when the file is opened (native `setup`): the app never writes to it.
  static const readOnlyPragma = 'PRAGMA query_only = ON';

  late final Map<String, String> _meta;

  @override
  late final DictionaryInfo info = DictionaryInfo(
    source: _meta['source'] ?? 'Wiktionary',
    licence: _meta['licence'] ?? 'CC BY-SA 4.0',
    licenceUrl: _meta['licence_url'] ?? 'https://creativecommons.org/licenses/by-sa/4.0/',
    sourceUrl: _meta['source_url'] ?? 'https://en.wiktionary.org/',
    dumpDate: _meta['dump_date'] ?? '',
    version: _meta['version'] ?? '',
  );

  @override
  String get language => _meta['language'] ?? 'en';

  @override
  Future<List<DictionaryEntry>> entries(String key) async {
    final rows = await customSelect(
      'SELECT headword, pos, ipa, senses FROM entries WHERE key = ? ORDER BY id',
      variables: [Variable.withString(key)],
    ).get();
    return [
      for (final r in rows)
        DictionaryEntry(
          headword: r.read<String>('headword'),
          pos: r.read<String>('pos'),
          ipa: r.readNullable<String>('ipa'),
          senses: _senses(r.read<String>('senses')),
        ),
    ];
  }

  @override
  Future<List<WordFormLink>> formsOf(String key) async {
    final rows = await customSelect(
      // The most common base first ("went": go before Scots "gan").
      'SELECT base_key, relation FROM forms WHERE form_key = ? '
      'ORDER BY (SELECT MIN(rank) FROM entries WHERE key = base_key), base_key',
      variables: [Variable.withString(key)],
    ).get();
    return [
      for (final r in rows)
        WordFormLink(
          key,
          r.read<String>('base_key'),
          FormRelation.parse(r.read<String>('relation')),
        ),
    ];
  }

  @override
  Future<bool> hasEntry(String key) async {
    final row = await customSelect(
      'SELECT EXISTS (SELECT 1 FROM entries WHERE key = ?) AS found',
      variables: [Variable.withString(key)],
    ).getSingle();
    return row.read<bool>('found');
  }

  /// `[{"g": gloss, "t": [tags], "x": [examples]}]`.
  static List<Sense> _senses(String json) => [
    for (final s in jsonDecode(json) as List)
      Sense(
        s['g'] as String,
        tags: [...?(s['t'] as List?)?.cast<String>()],
        examples: [...?(s['x'] as List?)?.cast<String>()],
      ),
  ];

  @override
  Iterable<TableInfo<Table, Object?>> get allTables => const [];

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (_) async => throw StateError('The dictionary file is missing or empty'),
    onUpgrade: (_, from, to) async =>
        throw StateError('Unexpected dictionary schema $from (expected $to)'),
  );
}
