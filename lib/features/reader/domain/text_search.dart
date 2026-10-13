// Search in a book (FR-030 to FR-034, research R6). Format-agnostic: it reads page text
// through ReaderDocument, so EPUB gets it for free (Principle III).
import 'dart:async';
import 'dart:math';
import 'dart:ui';

import 'package:flutter/foundation.dart';

import '../../../core/document/document_format.dart';
import '../../library/domain/text_fold.dart';

/// Text folded for matching, with the original index of each folded character.
@immutable
class FoldedText {
  const FoldedText(this.text, this.source);

  final String text;

  /// source[i] is the index in the original string of folded character i.
  final List<int> source;
}

final _space = RegExp(r'\s');

/// Folds case and accents like the library search, and turns every run of whitespace
/// (including line breaks) into one space, keeping a map back to the original.
FoldedText foldForSearch(String original) {
  final out = StringBuffer();
  final source = <int>[];
  var lastWasSpace = false;
  var i = 0;
  for (final rune in original.runes) {
    final char = String.fromCharCode(rune);
    if (_space.hasMatch(char)) {
      if (!lastWasSpace) {
        out.write(' ');
        source.add(i);
        lastWasSpace = true;
      }
    } else {
      final folded = fold(char);
      for (var j = 0; j < folded.length; j++) {
        source.add(i);
      }
      out.write(folded);
      lastWasSpace = false;
    }
    i += char.length;
  }
  return FoldedText(out.toString(), source);
}

@immutable
class SearchResult {
  const SearchResult({
    required this.page,
    required this.indexOnPage,
    required this.snippet,
    required this.matchStart,
    required this.matchLength,
    required this.rects,
  });

  final int page;

  /// Order of this match on its page, from 0.
  final int indexOnPage;

  /// The text around the match, on one line.
  final String snippet;
  final int matchStart;
  final int matchLength;

  /// Where the match is, normalised to the page; one rect per line.
  final List<Rect> rects;
}

/// A running search. Listeners hear about each page's results as they arrive.
class SearchRun extends ChangeNotifier {
  SearchRun._(this.query);

  final String query;
  final results = <SearchResult>[];
  final _done = Completer<void>();
  bool _cancelled = false;
  bool _sawText = false;
  int _pagesSearched = 0;

  Future<void> get done => _done.future;
  bool get isDone => _done.isCompleted;
  bool get isCancelled => _cancelled;

  /// Whether any searched page had text (FR-034).
  bool get sawText => _sawText;
  int get pagesSearched => _pagesSearched;

  /// Stops before the next page (FR-033).
  void cancel() => _cancelled = true;

  void _add(List<SearchResult> found) {
    results.addAll(found);
    notifyListeners();
  }

  void _finish() {
    if (!_done.isCompleted) _done.complete();
    notifyListeners();
  }
}

class TextSearch {
  TextSearch(this.doc);

  final ReaderDocument doc;

  /// How many pages [hasText] looks at.
  static const samplePages = 20;

  /// Searches every page, starting at [fromPage] and wrapping around.
  SearchRun start(String query, {required int fromPage}) {
    final run = SearchRun._(query);
    final needle = foldForSearch(query.trim()).text;
    if (needle.isEmpty) {
      run._finish();
      return run;
    }
    () async {
      final n = doc.pageCount;
      for (var k = 0; k < n; k++) {
        if (run._cancelled) break;
        final page = (fromPage - 1 + k) % n + 1;
        final text = await doc.loadPageText(page);
        if (run._cancelled) break;
        run._pagesSearched++;
        if (text == null || !text.hasText) continue;
        run._sawText = true;
        final found = _matches(text, needle, page);
        if (found.isNotEmpty) run._add(found);
        // Let frames through between pages, so reading stays smooth (SC-007).
        await Future<void>.delayed(Duration.zero);
      }
      run._finish();
    }();
    return run;
  }

  /// Samples up to [samplePages] pages spread through the book; false if none has text
  /// (FR-034). Text on pages that weren't sampled is still found by a full search.
  Future<bool> hasText() async {
    final n = doc.pageCount;
    final k = min(samplePages, n);
    final pages = <int>{
      for (var i = 0; i < k; i++) k == 1 ? 1 : 1 + (i * (n - 1) / (k - 1)).round(),
    };
    for (final page in pages) {
      final text = await doc.loadPageText(page);
      if (text != null && text.hasText) return true;
    }
    return false;
  }

  static List<SearchResult> _matches(PageText page, String needle, int pageNumber) {
    final folded = foldForSearch(page.text);
    final out = <SearchResult>[];
    var from = 0;
    while (true) {
      final at = folded.text.indexOf(needle, from);
      if (at < 0) break;
      from = at + needle.length;
      final start = folded.source[at];
      final lastSource = folded.source[at + needle.length - 1];
      final end = lastSource + _charLength(page.text, lastSource);
      out.add(_result(page, pageNumber, out.length, start, end));
    }
    return out;
  }

  static int _charLength(String text, int index) {
    final unit = text.codeUnitAt(index);
    return unit >= 0xD800 && unit <= 0xDBFF && index + 1 < text.length ? 2 : 1;
  }

  /// About this many characters of context on each side.
  static const _context = 40;

  static SearchResult _result(PageText page, int pageNumber, int index, int start, int end) {
    final text = page.text;
    var from = max(0, start - _context);
    var to = min(text.length, end + _context);
    // Cut at word boundaries.
    if (from > 0) {
      final space = text.indexOf(_space, from);
      if (space >= 0 && space < start) from = space + 1;
    }
    if (to < text.length) {
      final space = text.lastIndexOf(_space, to);
      if (space >= end) to = space;
    }
    final before = (from > 0 ? '… ' : '') + text.substring(from, start).replaceAll(_spaces, ' ');
    final match = text.substring(start, end).replaceAll(_spaces, ' ');
    final after = text.substring(end, to).replaceAll(_spaces, ' ') + (to < text.length ? ' …' : '');
    return SearchResult(
      page: pageNumber,
      indexOnPage: index,
      snippet: before + match + after,
      matchStart: before.length,
      matchLength: match.length,
      rects: _lineRects(page.charRects, start, end),
    );
  }

  static final _spaces = RegExp(r'\s+');

  /// The characters' rects merged into one rect per line.
  static List<Rect> _lineRects(List<Rect> chars, int start, int end) {
    final lines = <Rect>[];
    for (var i = start; i < end && i < chars.length; i++) {
      final r = chars[i];
      if (r.isEmpty) continue;
      if (lines.isNotEmpty && (lines.last.center.dy - r.center.dy).abs() < r.height / 2) {
        lines[lines.length - 1] = lines.last.expandToInclude(r);
      } else {
        lines.add(r);
      }
    }
    return lines;
  }
}
