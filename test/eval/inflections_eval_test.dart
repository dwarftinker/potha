// SC-003: at least 95% of 200 common inflected forms resolve to the right base word.
// Runs against the full dictionary; skipped when it is missing.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:potha/features/reader/domain/lookup_resolver.dart';
import 'package:potha/features/reader/domain/word_extractor.dart';

import 'eval_dictionary.dart';

void main() {
  test('inflected forms resolve to their base (SC-003)', () async {
    final db = await openFullDictionary();
    addTearDown(db.close);
    final resolver = LookupResolver(db);
    final rows = File('test/fixtures/dictionary/inflections_200.tsv')
        .readAsLinesSync()
        .where((l) => l.isNotEmpty && !l.startsWith('#'))
        .map((l) => l.split('\t'))
        .toList();
    expect(rows, hasLength(200));
    var good = 0;
    final misses = <String>[];
    for (final [form, expected] in rows) {
      final result = await resolver.resolve(LookupQuery(candidates: [form], display: form));
      // The first base shown: the first section reached through a note.
      final base = result.sections.where((s) => s.note != null).firstOrNull?.entry.headword;
      if (base != null && expected.split('|').contains(base.toLowerCase())) {
        good++;
      } else {
        misses.add('$form→${base ?? '-'}');
      }
    }
    expect(report('SC-003 inflections', good, rows.length, misses), greaterThanOrEqualTo(0.95));
  }, skip: skipWithoutDictionary);
}
