// SC-004: at least 95% of words split at a line end are looked up correctly: ordinary
// words joined ("exam-/ple" -> example), and no genuine compound lost to joining
// ("run-/down" shows run-down, after rundown if that exists too; or its parts when the
// dictionary has no entry). Full dictionary; skipped when it is missing.
import 'dart:io';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:potha/core/document/document_format.dart';
import 'package:potha/features/reader/domain/lookup_resolver.dart';
import 'package:potha/features/reader/domain/word_extractor.dart';

import 'eval_dictionary.dart';

void main() {
  test('line-break hyphens are joined only when they should be (SC-004)', () async {
    final db = await openFullDictionary();
    addTearDown(db.close);
    final resolver = LookupResolver(db);
    const extractor = WordExtractor();
    final rows = File('test/fixtures/dictionary/hyphenation.tsv')
        .readAsLinesSync()
        .where((l) => l.isNotEmpty && !l.startsWith('#'))
        .map((l) => l.split('\t'))
        .toList();
    expect(rows.length, greaterThanOrEqualTo(100));
    var good = 0;
    final misses = <String>[];
    final wronglyJoined = <String>[];
    for (final [kind, split, expected] in rows) {
      // As PDFium gives it: the line-end hyphen becomes U+0002 (research R4).
      final page = 'see the ${split.replaceAll('|', '\u0002')} here';
      final text = PageText(page, [
        for (var i = 0; i < page.length; i++) Rect.fromLTWH(i * 0.01, 0, 0.01, 0.03),
      ]);
      final selection = extractor.wordAt(text, page.indexOf(split.substring(0, 1), 8))!;
      final result = await resolver.resolve(extractor.queryFor(text, selection));
      final joined = expected.replaceAll('-', '');
      final shown = result.sections.map((s) => s.entry.headword.toLowerCase()).toSet();
      // A compound is right when its hyphenated entry is shown, or (if the dictionary has
      // none) its parts; it is wrongly joined when only a joined spelling is shown.
      // Wiktionary sometimes lists the hyphenated spelling as a form of the joined one
      // ("kind-hearted" -> kindhearted): then the joined entry is the right one.
      final hyphenatedEntry = (await db.entries(expected)).isNotEmpty;
      final formOfJoined = (await db.formsOf(expected)).any((l) => l.base == joined);
      final ok = kind == 'ordinary'
          ? shown.contains(expected)
          : formOfJoined
          ? shown.contains(joined)
          : hyphenatedEntry
          ? shown.contains(expected)
          : result.found && !shown.contains(joined);
      if (kind == 'compound' && !ok && shown.contains(joined)) wronglyJoined.add(expected);
      if (ok) {
        good++;
      } else {
        misses.add('$split→${shown.take(2).join('/')}');
      }
    }
    expect(report('SC-004 hyphenation', good, rows.length, misses), greaterThanOrEqualTo(0.95));
    expect(wronglyJoined, isEmpty, reason: 'genuine compounds joined');
  }, skip: skipWithoutDictionary);
}
