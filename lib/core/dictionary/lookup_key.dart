// The key a word is looked up by (003 research R5). tool/build_dictionary.py builds the
// dictionary with the same rules; both are tested against
// test/fixtures/dictionary/key_vectors.tsv.
part 'lookup_key_compositions.dart';

final _space = RegExp(r'\s+');

/// Lowercase, NFC, ’ and ‘ as ', runs of white space as one space, trimmed.
String lookupKey(String text) {
  final composed = _compose(text);
  return composed
      .replaceAll('’', "'")
      .replaceAll('‘', "'")
      .replaceAll(_space, ' ')
      .trim()
      .toLowerCase();
}

/// Canonical composition for the scripts in [_compositions]. Text from PDFs is almost
/// always composed already, so this is a fast no-op unless a combining mark is present.
String _compose(String text) {
  if (!text.runes.any(_isCombining)) return text;
  final out = <int>[];
  for (final rune in text.runes) {
    if (out.isNotEmpty && _isCombining(rune)) {
      final composed = _compositions[(out.last << 16) | rune];
      if (composed != null) {
        out[out.length - 1] = composed;
        continue;
      }
    }
    out.add(rune);
  }
  return String.fromCharCodes(out);
}

bool _isCombining(int rune) => rune >= 0x300 && rune <= 0x36F;
