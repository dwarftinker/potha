// From a point on the page to the word to look up (003 research R4, FR-007 to FR-011).
// Pure Dart over PageText (Principle III): nothing here knows the file format.
//
// PDFium (pdfrx 2.6.5) ends a line with "\r\n", and replaces a line-end hyphen with U+0002
// and no line break ("exam\u0002ple"). A hyphen followed by a line break ("exam-\r\nple")
// is handled the same way, for other formats.
import 'dart:ui';

import 'package:flutter/foundation.dart';

import '../../../core/dictionary/lookup_key.dart';
import '../../../core/document/document_format.dart';

/// PDFium's marker for a hyphen at a line end.
const _lineHyphen = 0x02;
const _softHyphen = 0xAD;

/// A word or phrase selected on one page: characters [start, end) of that page's text.
@immutable
class WordSelection {
  const WordSelection({
    required this.page,
    required this.start,
    required this.end,
    required this.text,
    required this.rects,
  });

  final int page;
  final int start;
  final int end;

  /// As shown on the page ("exam-ple", "“Hello,” " without the quotes).
  final String text;

  /// One rect per line, normalised to the page.
  final List<Rect> rects;

  @override
  bool operator ==(Object other) =>
      other is WordSelection && other.page == page && other.start == start && other.end == end;

  @override
  int get hashCode => Object.hash(page, start, end);

  @override
  String toString() => 'WordSelection($page, $start-$end, "$text")';
}

/// What to look up for a selection (data-model.md).
@immutable
class LookupQuery {
  const LookupQuery({
    required this.candidates,
    required this.display,
    this.parts = const [],
    this.capitalisedMidSentence = false,
    this.isPhrase = false,
    this.garbled = false,
  });

  /// Lookup keys to try in order: the joined line-break word before the hyphenated one.
  final List<String> candidates;

  /// The word as the reader saw it, for notes and history ("Running").
  final String display;

  /// A hyphenated word's parts, shown as sections if the whole has no entry (FR-009).
  final List<String> parts;

  /// "in Turkey": proper-noun entries come first (FR-010).
  final bool capitalisedMidSentence;
  final bool isPhrase;

  /// The text isn't readable (broken fonts, FR-029); nothing is looked up.
  final bool garbled;

  @override
  String toString() =>
      'LookupQuery($candidates, parts: $parts, "$display"'
      '${garbled ? ', garbled' : ''}${capitalisedMidSentence ? ', mid-sentence' : ''})';
}

/// The character under [point] (normalised to the page) in [text], or null: the
/// character whose rect contains it, else the nearest one within half a line height.
/// White space never counts.
int? hitTest(PageText text, Offset point) {
  int? best;
  var bestDistance = double.infinity;
  for (var i = 0; i < text.charRects.length && i < text.text.length; i++) {
    final r = text.charRects[i];
    if (r.isEmpty) continue;
    final dx = point.dx < r.left
        ? r.left - point.dx
        : (point.dx > r.right ? point.dx - r.right : 0.0);
    final dy = point.dy < r.top
        ? r.top - point.dy
        : (point.dy > r.bottom ? point.dy - r.bottom : 0.0);
    if (dx == 0 && dy == 0) return _isSpace(text.text.codeUnitAt(i)) ? null : i;
    final reach = r.height / 2;
    if (dx > reach || dy > reach) continue;
    final d = dx * dx + dy * dy;
    if (d < bestDistance) {
      bestDistance = d;
      best = i;
    }
  }
  if (best == null || _isSpace(text.text.codeUnitAt(best))) return null;
  return best;
}

class WordExtractor {
  const WordExtractor();

  /// The word around [index], or null if it isn't one (numbers, symbols, URLs, emails:
  /// FR-011). Garbled text gives a selection whose query is [LookupQuery.garbled].
  WordSelection? wordAt(PageText text, int index, {int page = 1}) {
    final s = text.text;
    if (index < 0 || index >= s.length || _isSpace(s.codeUnitAt(index))) return null;
    final (tokenStart, tokenEnd) = _token(s, index);
    final token = s.substring(tokenStart, tokenEnd);
    if (_isGarbled(token)) return _selection(text, page, tokenStart, tokenEnd);
    if (_isUrlOrEmail(_withoutBreaks(token))) return null;
    // The word core: letters, marks and digits with inner joiners, around [index].
    var at = index;
    if (!_isWordChar(s.codeUnitAt(at))) {
      at = _nearestWordChar(s, at, tokenStart, tokenEnd) ?? -1;
      if (at < 0) return null;
    }
    var start = at, end = at + 1;
    while (start > tokenStart) {
      final j = _joinedBefore(s, start, tokenStart);
      if (j == null) break;
      start = j;
    }
    while (end < tokenEnd) {
      final j = _joinedAfter(s, end, tokenEnd);
      if (j == null) break;
      end = j;
    }
    final core = s.substring(start, end);
    if (!core.runes.any(_isLetter)) return null;
    return _selection(text, page, start, end);
  }

  LookupQuery queryFor(PageText text, WordSelection selection) {
    final raw = text.text.substring(selection.start, selection.end);
    if (_isGarbled(raw)) {
      return LookupQuery(candidates: const [], display: raw, garbled: true);
    }
    // Normalise line-break hyphens to one marker, and drop soft hyphens.
    var word = raw
        .replaceAll(RegExp('-(\r\n|\r|\n)'), '\u0002')
        .replaceAll(String.fromCharCode(_softHyphen), '');
    word = _stripPossessive(word);
    final List<String> surfaces;
    if (word.contains('\u0002')) {
      surfaces = [word.replaceAll('\u0002', ''), word.replaceAll('\u0002', '-')];
    } else {
      surfaces = [word];
    }
    final hyphenated = surfaces.last;
    final parts = hyphenated.contains('-')
        ? [
            for (final p in hyphenated.split('-'))
              if (p.isNotEmpty) lookupKey(p),
          ]
        : const <String>[];
    final candidates = <String>[];
    for (final c in surfaces) {
      final key = lookupKey(c);
      if (!candidates.contains(key)) candidates.add(key);
    }
    return LookupQuery(
      candidates: candidates,
      display: surfaces.first,
      parts: parts.length > 1 ? parts : const [],
      capitalisedMidSentence:
          _isUpper(word.runes.first) && !_atSentenceStart(text.text, selection.start),
    );
  }

  WordSelection _selection(PageText text, int page, int start, int end) => WordSelection(
    page: page,
    start: start,
    end: end,
    text: _shown(text.text.substring(start, end)),
    rects: _lineRects(text, start, end),
  );
}

/// The run of non-space characters around [index]. A hyphen followed by a line break
/// continues onto the next line.
(int, int) _token(String s, int index) {
  var start = index, end = index + 1;
  while (true) {
    if (start > 0 && !_isSpace(s.codeUnitAt(start - 1))) {
      start--;
      continue;
    }
    // At a line start: continue if the previous line ended in "-" after a letter.
    final b = _breakBefore(s, start);
    if (b != null &&
        b > 0 &&
        s.codeUnitAt(b - 1) == 0x2D &&
        b > 1 &&
        _isLetter(s.codeUnitAt(b - 2))) {
      start = b - 1;
      continue;
    }
    break;
  }
  while (true) {
    if (end < s.length && !_isSpace(s.codeUnitAt(end))) {
      end++;
      continue;
    }
    // "-" then a line break then a letter: the word goes on.
    if (end > 1 && s.codeUnitAt(end - 1) == 0x2D && _isLetter(s.codeUnitAt(end - 2))) {
      final next = _afterBreak(s, end);
      if (next != null && next < s.length && _isLetter(s.codeUnitAt(next))) {
        end = next + 1;
        continue;
      }
    }
    break;
  }
  return (start, end);
}

/// If [i] starts a line, the index of the line break before it.
int? _breakBefore(String s, int i) {
  var j = i;
  var sawBreak = false;
  while (j > 0 && (s.codeUnitAt(j - 1) == 0x0A || s.codeUnitAt(j - 1) == 0x0D)) {
    j--;
    sawBreak = true;
  }
  return sawBreak ? j : null;
}

/// If a line break starts at [i], the index after it.
int? _afterBreak(String s, int i) {
  var j = i;
  while (j < s.length && (s.codeUnitAt(j) == 0x0D || s.codeUnitAt(j) == 0x0A)) {
    j++;
  }
  return j > i ? j : null;
}

/// The start of the word part joined to the character before [start], or null.
int? _joinedBefore(String s, int start, int min) {
  final c = s.codeUnitAt(start - 1);
  if (_isWordChar(c)) return start - 1;
  if (_isJoiner(c) && start - 2 >= min && _isWordChar(s.codeUnitAt(start - 2))) {
    return start - 2;
  }
  // "exam-\r\n|ple"
  final b = _breakBefore(s, start);
  if (b != null &&
      b - 2 >= min &&
      s.codeUnitAt(b - 1) == 0x2D &&
      _isWordChar(s.codeUnitAt(b - 2))) {
    return b - 2;
  }
  return null;
}

/// The end of the word part joined after [end], or null.
int? _joinedAfter(String s, int end, int max) {
  final c = s.codeUnitAt(end);
  if (_isWordChar(c)) return end + 1;
  if (_isJoiner(c) && end + 1 < max && _isWordChar(s.codeUnitAt(end + 1))) return end + 2;
  if (c == 0x2D) {
    final next = _afterBreak(s, end + 1);
    if (next != null && next < max && _isWordChar(s.codeUnitAt(next))) return next + 1;
  }
  return null;
}

int? _nearestWordChar(String s, int at, int start, int end) {
  for (var d = 1; d < end - start; d++) {
    if (at + d < end && _isWordChar(s.codeUnitAt(at + d))) return at + d;
    if (at - d >= start && _isWordChar(s.codeUnitAt(at - d))) return at - d;
  }
  return null;
}

String _stripPossessive(String word) {
  for (final suffix in ["'s", '’s', "'S", '’S']) {
    if (word.length > suffix.length + 1 && word.endsWith(suffix)) {
      return word.substring(0, word.length - suffix.length);
    }
  }
  return word;
}

/// Is the word at [start] the first of a sentence (page start, or after . ! ? :)?
bool _atSentenceStart(String s, int start) {
  var i = start - 1;
  while (i >= 0) {
    final c = s.codeUnitAt(i);
    if (_isSpace(c) || _isOpening(c)) {
      i--;
      continue;
    }
    return c == 0x2E || c == 0x21 || c == 0x3F || c == 0x3A;
  }
  return true;
}

/// As shown: line-break markers drawn as hyphens, line breaks dropped.
String _shown(String raw) => raw
    .replaceAll('\u0002', '-')
    .replaceAll(RegExp('[\r\n]'), '')
    .replaceAll(String.fromCharCode(_softHyphen), '');

String _withoutBreaks(String token) => _shown(token);

final _url = RegExp(r'^[(\[<"“‘]*(https?://|www\.)', caseSensitive: false);
final _email = RegExp(r'[^@\s]+@[^@\s]+\.[a-z]{2,}', caseSensitive: false);
final _domain = RegExp(
  r'^[(\[<"“‘]*[a-z0-9-]+(\.[a-z0-9-]+)*\.(com|org|net|edu|gov|io|app|dev|co|uk|de|fr|info|biz|me|ly|ai|us|ca|au|in|jp)\b',
  caseSensitive: false,
);

bool _isUrlOrEmail(String token) =>
    _url.hasMatch(token) || _email.hasMatch(token) || _domain.hasMatch(token);

/// U+FFFD, private-use or control characters (other than PDFium's line-break hyphen
/// between letters, and line breaks) mean the font has no usable text (FR-029).
bool _isGarbled(String token) {
  for (var i = 0; i < token.length; i++) {
    final c = token.codeUnitAt(i);
    if (c == 0xFFFD || (c >= 0xE000 && c <= 0xF8FF)) return true;
    if (c < 0x20 && c != 0x0A && c != 0x0D) {
      final between =
          c == _lineHyphen &&
          i > 0 &&
          i + 1 < token.length &&
          _isLetter(token.codeUnitAt(i - 1)) &&
          _isLetter(token.codeUnitAt(i + 1));
      if (!between) return true;
    }
  }
  return false;
}

List<Rect> _lineRects(PageText text, int start, int end) {
  final out = <Rect>[];
  Rect? current;
  for (var i = start; i < end && i < text.charRects.length; i++) {
    final r = text.charRects[i];
    if (r.isEmpty) continue;
    if (current != null && (r.center.dy - current.center.dy).abs() < current.height / 2) {
      current = current.expandToInclude(r);
    } else {
      if (current != null) out.add(current);
      current = r;
    }
  }
  if (current != null) out.add(current);
  return out;
}

bool _isSpace(int c) =>
    c == 0x20 ||
    c == 0x09 ||
    c == 0x0A ||
    c == 0x0D ||
    c == 0xA0 ||
    c == 0x3000 ||
    (c >= 0x2000 && c <= 0x200B);

bool _isOpening(int c) =>
    c == 0x22 ||
    c == 0x27 ||
    c == 0x28 ||
    c == 0x5B ||
    c == 0x7B ||
    c == 0x201C ||
    c == 0x2018 ||
    c == 0xAB;

/// Inside a word: apostrophes, hyphens, PDFium's line-break hyphen, soft hyphen.
bool _isJoiner(int c) =>
    c == 0x27 ||
    c == 0x2019 ||
    c == 0x2D ||
    c == 0x2010 ||
    c == 0x2011 ||
    c == _lineHyphen ||
    c == _softHyphen;

bool _isWordChar(int c) => _isLetter(c) || _isDigit(c) || _isMark(c);

bool _isDigit(int c) => c >= 0x30 && c <= 0x39;

bool _isMark(int c) => c >= 0x300 && c <= 0x36F;

final _letter = RegExp(r'\p{L}', unicode: true);
final _upper = RegExp(r'\p{Lu}', unicode: true);

bool _isLetter(int c) {
  if ((c >= 0x41 && c <= 0x5A) || (c >= 0x61 && c <= 0x7A)) return true;
  if (c < 0xC0) return false;
  return _letter.hasMatch(String.fromCharCode(c));
}

bool _isUpper(int rune) => _upper.hasMatch(String.fromCharCode(rune));
