// SC-001: at least 95% of word tokens in ordinary English prose get a definition offline,
// through the same word rules and resolver as a long-press. Full dictionary; skipped
// when it is missing.
import 'dart:io';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:potha/core/document/document_format.dart';
import 'package:potha/features/reader/domain/lookup_resolver.dart';
import 'package:potha/features/reader/domain/word_extractor.dart';

import 'eval_dictionary.dart';

void main() {
  test('prose tokens get a definition (SC-001)', () async {
    final db = await openFullDictionary();
    addTearDown(db.close);
    final resolver = LookupResolver(db);
    const extractor = WordExtractor();
    final tokens = File('test/fixtures/dictionary/prose_1000.txt')
        .readAsLinesSync()
        .where((l) => !l.startsWith('#'))
        .expand((l) => l.split(' '))
        .where((t) => t.isNotEmpty)
        .toList();
    expect(tokens, hasLength(1000));
    var good = 0;
    final misses = <String>[];
    for (final token in tokens) {
      // The token alone on a line, pressed on its first letter.
      final text = PageText(token, [
        for (var i = 0; i < token.length; i++) Rect.fromLTWH(i * 0.02, 0, 0.02, 0.03),
      ]);
      final index = token.indexOf(RegExp(r'[A-Za-z]'));
      final selection = index < 0 ? null : extractor.wordAt(text, index);
      final result = selection == null
          ? null
          : await resolver.resolve(extractor.queryFor(text, selection));
      if (result?.found ?? false) {
        good++;
      } else {
        misses.add(token);
      }
    }
    expect(
      report('SC-001 prose coverage', good, tokens.length, misses),
      greaterThanOrEqualTo(0.95),
    );
  }, skip: skipWithoutDictionary);
}
