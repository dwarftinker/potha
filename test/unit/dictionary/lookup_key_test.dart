// Lookup keys match the build script's (003 research R5): both run the same vectors.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:potha/core/dictionary/lookup_key.dart';

String _unescape(String field) => field
    .replaceAll(r'\t', '\t')
    .replaceAll(r'\s', ' ')
    .replaceAllMapped(
      RegExp(r'\\u([0-9A-Fa-f]{4})'),
      (m) => String.fromCharCode(int.parse(m[1]!, radix: 16)),
    );

void main() {
  final vectors = File('test/fixtures/dictionary/key_vectors.tsv')
      .readAsLinesSync()
      .where((l) => l.isNotEmpty && !l.startsWith('#'))
      .map((l) => l.split('\t').map(_unescape).toList());

  for (final [input, key] in vectors) {
    test('${input.runes.map((r) => r.toRadixString(16)).join(' ')} -> $key', () {
      expect(lookupKey(input), key);
    });
  }

  test('decomposed accents compose (NFC) for Latin and Greek', () {
    expect(lookupKey('naïve'), 'naïve');
    expect(lookupKey('Å'), 'å');
    expect(lookupKey('ǖ'), 'ǖ');
    expect(lookupKey('ά'), 'ά');
  });
}
