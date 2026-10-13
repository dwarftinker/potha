// The dictionary file through Lexicon (003 T013), over the sample built from real
// wiktextract lines: python3 tool/build_dictionary.py --sample
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:potha/core/dictionary/dictionary_database.dart';
import 'package:potha/core/dictionary/lexicon.dart';

final _sample = File('build/fixtures/dict_sample.sqlite');
final _skip = _sample.existsSync()
    ? null
    : 'Sample dictionary missing; build it with '
          '`build/dictionary/venv/bin/python tool/build_dictionary.py --sample` '
          '(see the script header for the venv)';

void main() {
  late DictionaryDatabase db;

  setUpAll(() async {
    if (_skip != null) return;
    db = await DictionaryDatabase.open(
      NativeDatabase(_sample, setup: (db) => db.execute(DictionaryDatabase.readOnlyPragma)),
    );
  });

  tearDownAll(() async {
    if (_skip == null) await db.close();
  });

  test('melancholy has a noun and an adjective with glosses and an IPA', () async {
    final entries = await db.entries('melancholy');
    expect(entries.map((e) => e.pos), containsAll(['noun', 'adj']));
    final adj = entries.firstWhere((e) => e.pos == 'adj');
    expect(adj.headword, 'melancholy');
    expect(adj.ipa, isNotNull);
    expect(adj.senses.first.gloss, contains('sadness'));
    expect(adj.senses.first.examples, isNotEmpty);
    expect(adj.senses.first.tags, contains('literary'));
  }, skip: _skip);

  test('mice is the plural of mouse', () async {
    expect(await db.formsOf('mice'), [const WordFormLink('mice', 'mouse', FormRelation.plural)]);
  }, skip: _skip);

  test('better includes good, comparative', () async {
    expect(
      await db.formsOf('better'),
      contains(const WordFormLink('better', 'good', FormRelation.comparative)),
    );
  }, skip: _skip);

  test('phrases have entries', () async {
    expect(await db.entries('give up'), isNotEmpty);
    expect(await db.hasEntry('in spite of'), isTrue);
  }, skip: _skip);

  test('proper nouns share the lowercase key', () async {
    final entries = await db.entries('turkey');
    expect(entries.where((e) => e.isProperNoun).single.headword, 'Turkey');
  }, skip: _skip);

  test('info reads the meta table', () async {
    expect(db.language, 'en');
    expect(db.info.licence, 'CC BY-SA 4.0');
    expect(db.info.dumpDate, '2026-09-02');
    expect(db.info.source, contains('Wiktionary'));
    expect(db.info.version, isNotEmpty);
  }, skip: _skip);

  test('an unknown key gives nothing', () async {
    expect(await db.entries('zorblax'), isEmpty);
    expect(await db.formsOf('zorblax'), isEmpty);
    expect(await db.hasEntry('zorblax'), isFalse);
  }, skip: _skip);

  test('the file is opened read-only', () async {
    expect(db.customStatement('DELETE FROM entries'), throwsA(anything));
  }, skip: _skip);
}
