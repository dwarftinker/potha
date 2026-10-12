import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:potha/core/document/document_format.dart';
import 'package:potha/features/reader/domain/text_search.dart';

class _Doc extends Fake implements ReaderDocument {
  _Doc(this.pages);
  final Map<int, String> pages;
  final requested = <int>[];
  int count = 0;

  @override
  int get pageCount => count == 0 ? pages.keys.fold(0, (a, b) => a > b ? a : b) : count;

  @override
  Future<PageText?> loadPageText(int page) async {
    requested.add(page);
    final text = pages[page] ?? '';
    return PageText(text, [
      for (var i = 0; i < text.length; i++)
        text[i] == '\n'
            ? ui.Rect.zero
            : ui.Rect.fromLTWH((i % 50) / 50, (i ~/ 50) / 60, 1 / 50, 1 / 60),
    ]);
  }

  @override
  Future<Uint8List?> renderPagePng(int pageNumber, {required int width}) async => null;
}

Future<List<SearchResult>> all(SearchRun run) async {
  await run.done;
  return run.results;
}

void main() {
  group('foldForSearch', () {
    test('folds case and accents and maps back to the original', () {
      final f = foldForSearch('Le Café');
      expect(f.text, 'le cafe');
      expect(f.source[6], 6); // 'e' came from 'é'
    });

    test('ß becomes ss, both mapping to the same original character', () {
      final f = foldForSearch('Straße');
      expect(f.text, 'strasse');
      expect(f.source.sublist(4, 6), [4, 4]);
    });

    test('runs of whitespace and line breaks become one space', () {
      expect(foldForSearch('a  \n\tb').text, 'a b');
    });
  });

  test('matches ignore case and accents (FR-030)', () async {
    final doc = _Doc({1: 'Le Café du Port', 2: 'CAFE OPEN', 3: 'a naïve reader'});
    final results = await all(TextSearch(doc).start('cafe', fromPage: 1));
    expect(results.map((r) => r.page), [1, 2]);
    expect((await all(TextSearch(doc).start('NAIVE', fromPage: 1))).single.page, 3);
  });

  test('a match maps back to the original characters and their rects', () async {
    final doc = _Doc({1: 'Die Straße ist lang'});
    final r = (await all(TextSearch(doc).start('strasse', fromPage: 1))).single;
    expect(r.snippet.substring(r.matchStart, r.matchStart + r.matchLength), 'Straße');
    expect(r.rects, isNotEmpty);
    // One line, so one rect covering the six characters.
    expect(r.rects.single.left, closeTo(4 / 50, 1e-9));
    expect(r.rects.single.right, closeTo(10 / 50, 1e-9));
  });

  test('a phrase across a line break matches', () async {
    final doc = _Doc({1: 'the white\nwhale rose'});
    expect(await all(TextSearch(doc).start('white whale', fromPage: 1)), hasLength(1));
  });

  test('several matches on one page come in order', () async {
    final doc = _Doc({1: 'whale and whale and whale'});
    final results = await all(TextSearch(doc).start('whale', fromPage: 1));
    expect(results, hasLength(3));
    expect(results.map((r) => r.indexOnPage), [0, 1, 2]);
  });

  test('snippets hold about 40 characters each side, cut at word boundaries', () async {
    final words = List.generate(40, (i) => 'word$i').join(' ');
    final doc = _Doc({1: '$words WHALE $words'});
    final r = (await all(TextSearch(doc).start('whale', fromPage: 1))).single;
    expect(r.snippet.startsWith('…'), isTrue);
    expect(r.snippet.endsWith('…'), isTrue);
    expect(r.snippet.length, lessThan(100));
    expect(r.snippet.substring(r.matchStart, r.matchStart + 5), 'WHALE');
    // Whole words only.
    expect(r.snippet, isNot(contains(RegExp(r'…\S*\d \S'))));
    expect(RegExp(r'^… word\d+ ').hasMatch(r.snippet), isTrue);
  });

  test('searches from the current page and wraps around', () async {
    final doc = _Doc({1: 'whale', 2: 'x', 3: 'whale', 4: 'x', 5: 'whale'});
    final results = await all(TextSearch(doc).start('whale', fromPage: 3));
    expect(results.map((r) => r.page), [3, 5, 1]);
    expect(doc.requested, [3, 4, 5, 1, 2]);
  });

  test('results arrive as each page is searched (FR-031)', () async {
    final doc = _Doc({1: 'whale', 2: 'whale', 3: 'whale'});
    final run = TextSearch(doc).start('whale', fromPage: 1);
    final counts = <int>[];
    run.addListener(() => counts.add(run.results.length));
    await run.done;
    expect(counts.first, lessThan(3));
    expect(run.results, hasLength(3));
    expect(run.isDone, isTrue);
  });

  test('cancelling stops before the next page (FR-033)', () async {
    final doc = _Doc({for (var p = 1; p <= 50; p++) p: 'whale'});
    final run = TextSearch(doc).start('whale', fromPage: 1);
    await Future<void>.delayed(Duration.zero);
    run.cancel();
    await run.done;
    expect(run.isCancelled, isTrue);
    expect(doc.requested.length, lessThan(50));
  });

  test('an empty query finds nothing and reads no pages', () async {
    final doc = _Doc({1: 'whale'});
    expect(await all(TextSearch(doc).start('   ', fromPage: 1)), isEmpty);
    expect(doc.requested, isEmpty);
  });

  test('a book whose sampled pages have no text reports no text (FR-034)', () async {
    final doc = _Doc({})..count = 500;
    expect(await TextSearch(doc).hasText(), isFalse);
    expect(doc.requested.length, 20);
    expect(doc.requested.first, 1);
    expect(doc.requested.last, 500);
  });

  test('one page with text is enough', () async {
    final doc = _Doc({250: 'text'})..count = 500;
    // Page 250 is not one of the samples, so the sample says no...
    expect(await TextSearch(doc).hasText(), isFalse);
    // ...but a full search finds it, and reports that text exists.
    final run = TextSearch(doc).start('text', fromPage: 1);
    await run.done;
    expect(run.results.single.page, 250);
    expect(run.sawText, isTrue);
    final doc2 = _Doc({1: 'text'})..count = 500;
    expect(await TextSearch(doc2).hasText(), isTrue);
  });

  test('a full search over pages with no text reports it (FR-034)', () async {
    final doc = _Doc({})..count = 30;
    final run = TextSearch(doc).start('whale', fromPage: 1);
    await run.done;
    expect(run.sawText, isFalse);
  });
}
