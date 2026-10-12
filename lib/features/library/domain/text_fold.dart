// Case- and accent-insensitive keys for library search and sorting (research R12).

const _groups = {
  'a': 'àáâãäåāăąǎǟǡǻȁȃȧ',
  'b': 'ƀ',
  'c': 'çćĉċč',
  'd': 'ďđð',
  'e': 'èéêëēĕėęěȅȇȩ',
  'g': 'ĝğġģǧǵ',
  'h': 'ĥħȟ',
  'i': 'ìíîïĩīĭįıǐȉȋ',
  'j': 'ĵǰ',
  'k': 'ķǩ',
  'l': 'ĺļľŀł',
  'n': 'ñńņňŉǹ',
  'o': 'òóôõöøōŏőǒǫǭǿȍȏȫȭȯȱ',
  'r': 'ŕŗřȑȓ',
  's': 'śŝşšșſ',
  't': 'ţťŧț',
  'u': 'ùúûüũūŭůűųǔǖǘǚǜȕȗ',
  'w': 'ŵ',
  'y': 'ýÿŷȳ',
  'z': 'źżžƶ',
  'ss': 'ß',
  'ae': 'æǽǣ',
  'oe': 'œ',
  'th': 'þ',
  'ij': 'ĳ',
};

final Map<int, String> _fold = {
  for (final entry in _groups.entries)
    for (final rune in entry.value.runes) rune: entry.key,
};

bool _isCombiningMark(int rune) => rune >= 0x0300 && rune <= 0x036F;

/// Lower-cases [text] and removes accents from Latin letters. Other scripts are only
/// lower-cased.
String fold(String text) {
  final out = StringBuffer();
  for (final rune in text.toLowerCase().runes) {
    if (_isCombiningMark(rune)) continue;
    out.write(_fold[rune] ?? String.fromCharCode(rune));
  }
  return out.toString();
}

final _leadingArticle = RegExp(r'^(the|a|an)\s+(?=\S)');

/// Sort key for titles: folded, without a leading "the", "a" or "an".
String sortTitle(String title) => fold(title.trim()).replaceFirst(_leadingArticle, '');

/// Search key: folded title and author joined by a space.
String searchKey(String title, String? author) =>
    fold([title, if (author != null && author.isNotEmpty) author].join(' '));
