// Page text for lookups, kept for the last pages used (003 research R4).
import 'dart:async';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:potha/core/document/document_format.dart';
import 'package:potha/features/reader/data/page_text_cache.dart';

void main() {
  late List<int> loads;
  late Map<int, Completer<PageText?>> pending;
  late bool deferred;

  Future<PageText?> load(int page) {
    loads.add(page);
    if (!deferred) return Future.value(PageText('page $page', const [Rect.zero]));
    return (pending[page] = Completer<PageText?>()).future;
  }

  setUp(() {
    loads = [];
    pending = {};
    deferred = false;
  });

  test('keeps the 8 most recently used pages', () async {
    final cache = PageTextCache(load);
    for (var p = 1; p <= 9; p++) {
      await cache.get(p);
    }
    expect(cache.peek(1), isNull, reason: 'page 1 was the least recently used');
    expect(cache.peek(9)!.text, 'page 9');
    await cache.get(2); // still cached: no load
    expect(loads, [1, 2, 3, 4, 5, 6, 7, 8, 9]);
    await cache.get(10); // evicts 3, not the just-used 2
    expect(cache.peek(2), isNotNull);
    expect(cache.peek(3), isNull);
  });

  test('concurrent requests for one page load it once', () async {
    deferred = true;
    final cache = PageTextCache(load);
    final a = cache.get(4);
    final b = cache.get(4);
    pending[4]!.complete(const PageText('four', []));
    expect((await a)!.text, 'four');
    expect((await b)!.text, 'four');
    expect(loads, [4]);
  });

  test('prefetch loads only uncached pages', () async {
    final cache = PageTextCache(load);
    await cache.get(2);
    await cache.prefetch([1, 2, 3]);
    expect(loads, [2, 1, 3]);
    expect(cache.peek(3), isNotNull);
  });

  test('a failed load is not cached', () async {
    var fail = true;
    final cache = PageTextCache((page) async {
      loads.add(page);
      if (fail) throw StateError('broken page');
      return const PageText('ok', []);
    });
    expect(await cache.get(5), isNull);
    fail = false;
    expect((await cache.get(5))!.text, 'ok');
    expect(loads, [5, 5]);
  });

  test('a null result (unreadable page) is not cached either', () async {
    final cache = PageTextCache((page) async {
      loads.add(page);
      return null;
    });
    await cache.get(1);
    await cache.get(1);
    expect(loads, [1, 1]);
  });
}
