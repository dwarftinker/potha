import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:potha/core/document/document_format.dart';
import 'package:potha/features/reader/data/thumbnail_cache.dart';

class _Doc extends Fake implements ReaderDocument {
  final renders = <int>[];
  final failing = <int>{};
  final pending = <int, Completer<void>>{};
  bool hold = false;
  var cancelled = <int>[];

  @override
  int get pageCount => 1000;

  @override
  Future<ui.Image?> renderPageImage(int page, {required int width, Future<void>? cancel}) async {
    renders.add(page);
    var wasCancelled = false;
    cancel?.then((_) => wasCancelled = true);
    if (hold) await (pending[page] = Completer<void>()).future;
    if (wasCancelled) {
      cancelled.add(page);
      return null;
    }
    if (failing.contains(page)) return null;
    final recorder = ui.PictureRecorder();
    ui.Canvas(recorder).drawColor(const ui.Color(0xFFFFFFFF), ui.BlendMode.src);
    return recorder.endRecording().toImage(width, width);
  }

  @override
  Future<Uint8List?> renderPagePng(int pageNumber, {required int width}) async => null;
}

void main() {
  late _Doc doc;
  late ThumbnailCache cache;

  setUp(() {
    doc = _Doc();
    cache = ThumbnailCache(doc, width: 20, capacity: 3);
  });
  tearDown(() => cache.dispose());

  test('loads once and serves later requests from memory', () async {
    final a = await cache.load(1);
    final b = await cache.load(1);
    expect(doc.renders, [1]);
    expect(a, isNotNull);
    expect(b, isNotNull);
    a!.dispose();
    b!.dispose();
    final peeked = cache.peek(1)!;
    peeked.dispose();
  });

  test('a page already loading is shared, not rendered twice', () async {
    doc.hold = true;
    final a = cache.load(5);
    final b = cache.load(5);
    await Future<void>.delayed(Duration.zero);
    doc.pending[5]!.complete();
    (await a)!.dispose();
    (await b)!.dispose();
    expect(doc.renders, [5]);
  });

  test('keeps at most capacity images, dropping the least recently used', () async {
    for (final p in [1, 2, 3]) {
      (await cache.load(p))!.dispose();
    }
    (await cache.load(1))!.dispose(); // 1 is now the most recent
    (await cache.load(4))!.dispose(); // evicts 2
    expect(cache.peek(2), isNull);
    final one = cache.peek(1);
    expect(one, isNotNull);
    one!.dispose();
    expect(cache.length, 3);
  });

  test('cancelling a request for a tile scrolled away stops the render', () async {
    doc.hold = true;
    final cancel = Completer<void>();
    final request = cache.load(7, cancel: cancel.future);
    await Future<void>.delayed(Duration.zero);
    cancel.complete();
    await Future<void>.delayed(Duration.zero);
    doc.pending[7]!.complete();
    expect(await request, isNull);
    expect(doc.cancelled, [7]);
    // Not remembered as failed: it can be loaded later.
    expect(cache.failed(7), isFalse);
  });

  test('a page that fails to render is remembered and not retried', () async {
    doc.failing.add(9);
    expect(await cache.load(9), isNull);
    expect(cache.failed(9), isTrue);
    expect(await cache.load(9), isNull);
    expect(doc.renders, [9]);
  });
}
