// The lookup flow for one open book (003 contracts/lookup.md, data-model.md):
// page point -> character -> word -> query -> result. Each request gets an id and only
// the latest one is shown (FR-014, SC-007). Owned by the reader screen, like the
// progress saver, because it uses the open book's page text.
import 'dart:async';

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

  LookupState get state => _state;

  /// The dictionary's source and licence, once it has been opened (FR-034).
  DictionaryInfo? get info => _info;
  WordSelection? get selection => _state.selection;

  /// Looks up the word at [point] (long-press, double-click, tap-to-define).
  Future<void> lookUpAt(PagePoint point) async {
    final id = ++_request;
    final text = await _pageText.get(point.page);
    if (id != _request) return;
    if (text == null || !text.hasText) {
      _set(const LookupNoText());
      _set(const LookupIdle());
      return;
    }
    final index = hitTest(text, point.offset);
    if (index == null) return; // empty space: nothing changes
    final selection = _extractor.wordAt(text, index, page: point.page);
    if (selection == null) return; // a number, URL or symbol (FR-011)
    await _resolve(id, selection, _extractor.queryFor(text, selection));
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
