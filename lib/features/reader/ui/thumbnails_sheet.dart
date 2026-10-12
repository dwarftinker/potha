// Page thumbnails (FR-035): a grid of page images, opened at the current page.
import 'dart:async';
import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../../core/document/document_format.dart';
import '../data/thumbnail_cache.dart';

const _tileWidth = 110.0;
const _spacing = 12.0;
const _labelHeight = 24.0;

/// Shows the grid; returns the chosen page, or null.
Future<int?> showThumbnailsSheet(
  BuildContext context, {
  required ReaderDocument doc,
  required ThumbnailCache cache,
  required int currentPage,
}) => showModalBottomSheet<int>(
  context: context,
  isScrollControlled: true,
  showDragHandle: true,
  builder: (context) => DraggableScrollableSheet(
    expand: false,
    initialChildSize: 0.85,
    maxChildSize: 0.95,
    builder: (context, scroll) =>
        _ThumbnailGrid(doc: doc, cache: cache, currentPage: currentPage, scroll: scroll),
  ),
);

class _ThumbnailGrid extends StatefulWidget {
  const _ThumbnailGrid({
    required this.doc,
    required this.cache,
    required this.currentPage,
    required this.scroll,
  });

  final ReaderDocument doc;
  final ThumbnailCache cache;
  final int currentPage;
  final ScrollController scroll;

  @override
  State<_ThumbnailGrid> createState() => _ThumbnailGridState();
}

class _ThumbnailGridState extends State<_ThumbnailGrid> {
  bool _scrolled = false;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final columns = max(1, ((constraints.maxWidth - _spacing) / (_tileWidth + _spacing)).floor());
      final tileWidth = (constraints.maxWidth - _spacing * (columns + 1)) / columns;
      // Tiles share one aspect ratio (the first page's), so rows are even and the grid
      // can jump straight to the current page.
      final first = widget.doc.pageSize(1);
      final imageHeight = tileWidth * first.height / first.width;
      final rowHeight = imageHeight + _labelHeight + _spacing;
      if (!_scrolled) {
        _scrolled = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          final scroll = widget.scroll;
          if (!scroll.hasClients) return;
          final row = (widget.currentPage - 1) ~/ columns;
          scroll.jumpTo(min(row * rowHeight, scroll.position.maxScrollExtent));
        });
      }
      return GridView.builder(
        controller: widget.scroll,
        padding: const EdgeInsets.all(_spacing),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: columns,
          mainAxisSpacing: _spacing,
          crossAxisSpacing: _spacing,
          mainAxisExtent: imageHeight + _labelHeight,
        ),
        itemCount: widget.doc.pageCount,
        itemBuilder: (context, i) => _Thumbnail(
          page: i + 1,
          cache: widget.cache,
          current: i + 1 == widget.currentPage,
          onTap: () => Navigator.of(context).pop(i + 1),
        ),
      );
    },
  );
}

class _Thumbnail extends StatefulWidget {
  const _Thumbnail({
    required this.page,
    required this.cache,
    required this.current,
    required this.onTap,
  });

  final int page;
  final ThumbnailCache cache;
  final bool current;
  final VoidCallback onTap;

  @override
  State<_Thumbnail> createState() => _ThumbnailState();
}

class _ThumbnailState extends State<_Thumbnail> {
  final _cancel = Completer<void>();
  ui.Image? _image;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _image = widget.cache.peek(widget.page);
    if (_image == null) _load();
  }

  Future<void> _load() async {
    final image = await widget.cache.load(widget.page, cancel: _cancel.future);
    if (!mounted) {
      image?.dispose();
      return;
    }
    setState(() {
      _image = image;
      _failed = image == null && widget.cache.failed(widget.page);
    });
  }

  @override
  void dispose() {
    // Scrolled away: stop rendering this page (research R11).
    if (!_cancel.isCompleted) _cancel.complete();
    _image?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final image = _image;
    final label =
        'Page ${widget.page}'
        '${widget.current ? ', current page' : ''}'
        "${_failed ? ", can't be shown" : ''}";
    return Semantics(
      label: label,
      button: true,
      excludeSemantics: true,
      child: InkWell(
        onTap: widget.onTap,
        borderRadius: BorderRadius.circular(4),
        child: Column(
          children: [
            Expanded(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border.all(
                    color: widget.current ? scheme.primary : scheme.outlineVariant,
                    width: widget.current ? 3 : 1,
                  ),
                ),
                child: SizedBox.expand(
                  child: image != null
                      ? RawImage(image: image, fit: BoxFit.contain)
                      : _failed
                      ? const Icon(Icons.broken_image_outlined, color: Color(0xFF757575))
                      : null,
                ),
              ),
            ),
            SizedBox(
              height: _labelHeight,
              child: Center(
                child: Text(
                  '${widget.page}',
                  style: TextStyle(
                    fontWeight: widget.current ? FontWeight.bold : null,
                    color: widget.current ? scheme.primary : null,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
