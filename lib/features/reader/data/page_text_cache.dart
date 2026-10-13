// Page text for lookups (003 research R4): the last pages used, loaded once each. The
// reader prefetches the visible pages when the view settles, so a long-press rarely waits
// for text extraction (R8 budget).

import '../../../core/document/document_format.dart';

class PageTextCache {
  PageTextCache(this._load, {this.capacity = 8});

  final Future<PageText?> Function(int page) _load;
  final int capacity;

  /// Most recently used last.
  final _pages = <int, PageText>{}; // a LinkedHashMap: insertion order
  final _loading = <int, Future<PageText?>>{};

  /// The page's text if cached, without loading it.
  PageText? peek(int page) => _pages[page];

  /// The page's text, or null if it can't be read. Failures are not cached.
  Future<PageText?> get(int page) {
    final cached = _pages.remove(page);
    if (cached != null) {
      _pages[page] = cached;
      return Future.value(cached);
    }
    return _loading[page] ??= _fetch(page);
  }

  Future<PageText?> _fetch(int page) async {
    try {
      final text = await _load(page);
      if (text != null) {
        _pages[page] = text;
        while (_pages.length > capacity) {
          _pages.remove(_pages.keys.first);
        }
      }
      return text;
    } catch (_) {
      return null;
    } finally {
      _loading.remove(page);
    }
  }

  /// Loads [pages] that aren't cached, one after another (idle-time work).
  Future<void> prefetch(Iterable<int> pages) async {
    for (final page in pages.toList()) {
      if (!_pages.containsKey(page)) await get(page);
    }
  }
}
