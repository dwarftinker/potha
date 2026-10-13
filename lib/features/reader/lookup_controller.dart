// The lookup flow for one open book (003 contracts/lookup.md, data-model.md):
// page point -> character -> word -> query -> result. Each request gets an id and only
// the latest one is shown (FR-014, SC-007). Owned by the reader screen, like the
// progress saver, because it uses the open book's page text.
import 'dart:async';
import 'dart:ui' show Offset;

import 'package:flutter/foundation.dart';

import '../../core/dictionary/dictionary_store.dart';
import '../../core/document/document_format.dart';
import 'data/page_text_cache.dart';
import 'domain/lookup_resolver.dart';
import 'domain/word_extractor.dart';

export 'domain/lookup_resolver.dart' show LookupResult, ResultSection, EntrySource;
export 'domain/word_extractor.dart' show WordSelection, LookupQuery;

@immutable
sealed class LookupState {
  const LookupState();

  /// The word highlighted on the page, if any.
  WordSelection? get selection => null;

  /// Whether the panel is showing.
  bool get isOpen => false;
}

class LookupIdle extends LookupState {
  const LookupIdle();
}

/// A long-press on a page without a text layer: the reader shows a brief message.
class LookupNoText extends LookupState {
  const LookupNoText();
}

/// The dictionary isn't ready yet: downloading (web), unpacking (mobile) or failed.
class LookupPreparing extends LookupState {
  const LookupPreparing(this.selection, this.status);

  @override
  final WordSelection? selection;
  final DictionaryStatus status;

  @override
  bool get isOpen => true;
}

class LookupLoading extends LookupState {
  const LookupLoading(this.selection);

  @override
  final WordSelection? selection;

  @override
  bool get isOpen => true;
}

class LookupShown extends LookupState {
  const LookupShown(this.selection, this.result);

  @override
  final WordSelection? selection;
  final LookupResult result;

  @override
  bool get isOpen => true;
}

class LookupNotFound extends LookupState {
  const LookupNotFound(this.selection, this.result);

  @override
  final WordSelection? selection;
  final LookupResult result;

  @override
  bool get isOpen => true;
}

// ignore_for_file: prefer_initializing_formals (named parameters can't be private)

class LookupController extends ChangeNotifier {
  LookupController({
    required DictionaryStore store,
    required PageTextCache pageText,
    WordExtractor extractor = const WordExtractor(),
  }) : _store = store,
       _pageText = pageText,
       _extractor = extractor;

  final DictionaryStore _store;
  final PageTextCache _pageText;
  final WordExtractor _extractor;

  LookupState _state = const LookupIdle();
  int _request = 0;
  bool _disposed = false;

  DictionaryInfo? _info;

  /// The page text and word the current selection grows from (FR-018).
  PageText? _text;
  WordSelection? _anchor;

  /// The selection while it is being extended; looked up when the drag ends.
  WordSelection? _extended;

  LookupState get state => _state;

  /// The dictionary's source and licence, once it has been opened (FR-034).
  DictionaryInfo? get info => _info;
  WordSelection? get selection => _extended ?? _state.selection;

  /// Looks up the word at [point] (long-press, double-click, tap-to-define). Returns
  /// false if there is no word there (empty space, a number, a page without text), so a
  /// tap can toggle the controls instead.
  Future<bool> lookUpAt(PagePoint point, {bool reportNoText = true}) async {
    final id = ++_request;
    final text = await _pageText.get(point.page);
    if (id != _request) return false;
    if (text == null || !text.hasText) {
      if (reportNoText) {
        _set(const LookupNoText());
        _set(const LookupIdle());
      }
      return false;
    }
    final index = hitTest(text, point.offset);
    if (index == null) return false; // empty space: nothing changes
    final selection = _extractor.wordAt(text, index, page: point.page);
    if (selection == null) return false; // a number, URL or symbol (FR-011)
    _text = text;
    _anchor = selection;
    _extended = null;
    await _resolve(id, selection, _extractor.queryFor(text, selection));
    return true;
  }

  /// A handle drag starts: the selection grows from its other end.
  void beginHandleDrag({required bool start}) {
    final text = _text;
    final current = selection;
    if (text == null || current == null) return;
    final at = start ? current.end - 1 : current.start;
    _anchor = _extractor.wordAt(text, at, page: current.page) ?? _anchor;
  }

  /// Extends the selection word by word to [point] (long-press drag, handles, mouse
  /// drag). Only the highlight changes until [endExtend].
  void extendTo(PagePoint point) {
    final text = _text, anchor = _anchor;
    if (text == null || anchor == null || point.page != anchor.page) return;
    final index = hitTest(text, point.offset) ?? _nearestOnLine(text, point.offset);
    if (index == null) return;
    final next = _extractor.extendTo(text, anchor, index);
    if (next == selection) return;
    _extended = next;
    notifyListeners();
  }

  /// The drag ended: looks up the new selection, if it changed.
  Future<void> endExtend() async {
    final extended = _extended, text = _text;
    if (extended == null || text == null) return;
    if (extended == _state.selection) {
      _extended = null;
      return;
    }
    final id = ++_request;
    await _resolve(id, extended, _extractor.queryFor(text, extended));
    if (id == _request) _extended = null;
  }

  /// A drag past the end of a line: the last character on the line under it.
  static int? _nearestOnLine(PageText text, Offset point) {
    int? best;
    var bestDx = double.infinity;
    for (var i = 0; i < text.charRects.length && i < text.text.length; i++) {
      final r = text.charRects[i];
      if (r.isEmpty || point.dy < r.top || point.dy > r.bottom) continue;
      final dx = (point.dx - r.center.dx).abs();
      if (dx < bestDx) {
        bestDx = dx;
        best = i;
      }
    }
    return best;
  }

  Future<void> _resolve(int id, WordSelection? selection, LookupQuery query) async {
    final lexicon = await _lexicon(id, selection);
    if (lexicon == null || id != _request) return;
    _set(LookupLoading(selection));
    final result = await LookupResolver(lexicon).resolve(query);
    if (id != _request) return;
    _set(result.found ? LookupShown(selection, result) : LookupNotFound(selection, result));
  }

  /// The dictionary, waiting in the preparing state if needed. Null if a newer request
  /// took over.
  Future<Lexicon?> _lexicon(int id, WordSelection? selection) async {
    if (_store.current is! DictionaryReady) {
      _store.ensureStarted(); // also retries after a failure (FR-022)
      _set(LookupPreparing(selection, _store.current));
    }
    final sub = _store.status.listen((status) {
      if (id == _request && status is! DictionaryReady) _set(LookupPreparing(selection, status));
    });
    try {
      final lexicon = await _store.ready;
      _info = lexicon.info;
      return id == _request ? lexicon : null;
    } finally {
      // Not awaited: nothing depends on it, and a broadcast cancel can complete late.
      unawaited(sub.cancel());
    }
  }

  /// Closes the panel and clears the selection; a pending lookup is dropped.
  void close() {
    _request++;
    _extended = null;
    _anchor = null;
    _set(const LookupIdle());
  }

  void _set(LookupState state) {
    if (_disposed) return;
    _state = state;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _request++;
    super.dispose();
  }
}
