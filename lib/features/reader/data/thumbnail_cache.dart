// Page thumbnails for the grid (FR-035, research R11).
import 'dart:async';
import 'dart:ui' as ui;

import '../../../core/document/document_format.dart';

/// Renders page images on demand and keeps the most recent [capacity] in memory.
///
/// Callers get their own handle (a clone) of each image and must dispose it; the cache
/// disposes its handles when it evicts an image or is disposed.
class ThumbnailCache {
  ThumbnailCache(this.doc, {required this.width, this.capacity = 200});

  final ReaderDocument doc;
  final int width;
  final int capacity;

  // Insertion-ordered (a Map literal is a LinkedHashMap): the first key is the oldest.
  final _images = <int, ui.Image>{};
  final _loading = <int, Future<ui.Image?>>{};
  final _failed = <int>{};
  bool _disposed = false;

  int get length => _images.length;

  bool failed(int page) => _failed.contains(page);

  /// The image if it's already in memory (marked as recently used), or null.
  ui.Image? peek(int page) {
    final image = _images.remove(page);
    if (image == null) return null;
    _images[page] = image;
    return image.clone();
  }

  /// Loads [page]'s image; null if it can't be rendered or [cancel] completed first.
  Future<ui.Image?> load(int page, {Future<void>? cancel}) async {
    final cached = peek(page);
    if (cached != null) return cached;
    if (_failed.contains(page)) return null;
    final image = await (_loading[page] ??= _render(page, cancel));
    return image?.clone();
  }

  Future<ui.Image?> _render(int page, Future<void>? cancel) async {
    var cancelled = false;
    unawaited(cancel?.then((_) => cancelled = true));
    try {
      final image = await doc.renderPageImage(page, width: width, cancel: cancel);
      if (image == null) {
        if (!cancelled) _failed.add(page);
        return null;
      }
      if (_disposed) {
        image.dispose();
        return null;
      }
      _images[page] = image;
      while (_images.length > capacity) {
        final oldest = _images.keys.first;
        _images.remove(oldest)!.dispose();
      }
      return image;
    } finally {
      _loading.remove(page);
    }
  }

  void dispose() {
    _disposed = true;
    for (final image in _images.values) {
      image.dispose();
    }
    _images.clear();
  }
}
