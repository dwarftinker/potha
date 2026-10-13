// The page view for PDFs (feature 002), built on pdfrx's PdfViewer.
//
// Pages are laid out in view-sized units: each page is scaled so that, at zoom 1.0, it
// fits the view's width (or the whole page fits, for fit page). Zoom 1.0 is therefore
// always the normal view, whatever the page sizes (FR-021, FR-036).
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:pdfrx/pdfrx.dart';

import '../document_format.dart';
import '../page_unavailable.dart';
import '../zoom_range.dart';
import 'pdf_document_format.dart';
import 'pdf_paged_layout.dart';
import 'pdf_view_controller.dart';

/// Gap between pages in continuous mode, in view pixels.
const continuousGap = 8.0;

/// The scale that fits a [pageWidth] × [pageHeight] page into [view] for [fit].
double fitScale(double pageWidth, double pageHeight, Size view, PageFit fit) =>
    fit == PageFit.fitWidth
    ? view.width / pageWidth
    : min(view.width / pageWidth, view.height / pageHeight);

/// Pages one below the other, each centred horizontally (continuous mode).
PdfPageLayout continuousLayout(List<Size> pages, Size view, PageFit fit) {
  final rects = <Rect>[];
  var y = 0.0;
  for (final p in pages) {
    final s = fitScale(p.width, p.height, view, fit);
    final w = p.width * s, h = p.height * s;
    rects.add(Rect.fromLTWH((view.width - w) / 2, y, w, h));
    y += h + continuousGap;
  }
  return PdfPageLayout(
    pageLayouts: rects,
    documentSize: Size(view.width, max(0.0, y - continuousGap)),
  );
}

class PdfDocumentViewFactory implements DocumentViewFactory {
  const PdfDocumentViewFactory();

  @override
  DocumentViewController createController() => PdfViewController();

  @override
  Widget build(
    ReaderDocument doc, {
    required DocumentViewController controller,
    required ReaderViewConfig config,
  }) => PdfDocumentView(
    document: doc as PdfReaderDocument,
    controller: controller as PdfViewController,
    config: config,
  );
}

class PdfDocumentView extends StatefulWidget {
  const PdfDocumentView({
    super.key,
    required this.document,
    required this.controller,
    required this.config,
  });

  final PdfReaderDocument document;
  final PdfViewController controller;
  final ReaderViewConfig config;

  @override
  State<PdfDocumentView> createState() => _PdfDocumentViewState();
}

class _PdfDocumentViewState extends State<PdfDocumentView> {
  late final _ref = PdfDocumentRefDirect(widget.document.document, autoDispose: false);
  late final _drag = PagedDragHandler(widget.controller);
  Size _view = Size.zero;

  bool get _paged => widget.config.mode == PageMode.paged;

  PdfViewController get _c => widget.controller;

  @override
  void initState() {
    super.initState();
    _c.interactionLock.addListener(_lockChanged);
    _c
      ..mode = widget.config.mode
      ..currentPage = widget.config.initialPosition.page
      ..onPositionChanged = widget.config.onPositionChanged;
  }

  @override
  void dispose() {
    _c.interactionLock.removeListener(_lockChanged);
    super.dispose();
  }

  /// A long-press or handle drag locks pans and zooms (003 research R6). The viewer's
  /// InteractiveViewer reads panEnabled and scaleEnabled on every update, so this takes
  /// effect mid-gesture.
  void _lockChanged() {
    if (mounted) setState(() {});
  }

  @override
  void didUpdateWidget(PdfDocumentView old) {
    super.didUpdateWidget(old);
    _c.onPositionChanged = widget.config.onPositionChanged;
    if (old.config.mode != widget.config.mode || old.config.fit != widget.config.fit) {
      // Keep the reader's place across a layout change (FR-015).
      final keep = _c.position;
      _c
        ..mode = widget.config.mode
        ..currentPage = keep.page;
      _restore(keep);
    }
  }

  /// Puts the reader back on [keep] after a layout change (FR-015). pdfrx also moves to
  /// its own guess of the current page, with a short animation that can finish after our
  /// first move, so the position is applied again once that has settled.
  void _restore(ReadingPosition keep) {
    _afterLayout(() => _c.goTo(keep, animate: false));
    Future<void>.delayed(const Duration(milliseconds: 350), () {
      if (mounted && !_c.position.isNearlySameAs(keep)) _c.goTo(keep, animate: false);
    });
  }

  void _afterLayout(VoidCallback action) => WidgetsBinding.instance.addPostFrameCallback((_) {
    if (mounted) WidgetsBinding.instance.addPostFrameCallback((_) => action());
  });

  PdfPageLayout _layoutPages(List<PdfPage> pages, PdfViewerParams params) {
    final view = _view.isEmpty ? const Size(400, 800) : _view;
    final sizes = [for (var i = 0; i < pages.length; i++) widget.document.pageSize(i + 1)];
    return _paged
        ? pagedLayout(sizes, view, widget.config.fit)
        : continuousLayout(sizes, view, widget.config.fit);
  }

  /// Zoom 1.0 is the normal view: pages are laid out at the fit already.
  static double? _normalZoom(
    PdfDocument document,
    PdfViewerController controller,
    double fit,
    double cover,
  ) => 1.0;

  /// Zoom limits from the current page as laid out at the normal view (FR-018).
  ZoomRange _zoomRange(Size view) {
    if (view.isEmpty) return const ZoomRange(1, 5);
    final page = widget.document.pageSize(_c.lastPosition.page.clamp(1, widget.document.pageCount));
    final s = fitScale(page.width, page.height, view, widget.config.fit);
    return zoomRange(pageAtNormal: page * s, view: view);
  }

  /// Search matches (FR-032) and the lookup selection (003 FR-002), painted in colours
  /// chosen to look right after the theme filter (research R5).
  void _paintHighlights(Canvas canvas, Rect pageRect, PdfPage page) {
    final config = widget.config;
    for (final h in config.highlights) {
      if (h.page != page.pageNumber) continue;
      final paint = Paint()
        ..color = switch (h.kind) {
          HighlightKind.match => config.highlightColor,
          HighlightKind.activeMatch => config.activeHighlightColor,
          HighlightKind.selection => config.selectionColor,
        };
      for (final r in h.rects) {
        canvas.drawRect(
          Rect.fromLTRB(
            pageRect.left + r.left * pageRect.width,
            pageRect.top + r.top * pageRect.height,
            pageRect.left + r.right * pageRect.width,
            pageRect.top + r.bottom * pageRect.height,
          ).inflate(1),
          paint,
        );
      }
    }
  }

  Matrix4 _normalize(Matrix4 m, Size viewSize, PdfPageLayout layout, PdfViewerController? c) {
    if (!_paged || _view.isEmpty || layout.pageLayouts.isEmpty) return m;
    return clampToPage(
      m,
      layout: layout,
      view: _view,
      page: _c.currentPage,
      sliding: _drag.sliding,
    );
  }

  @override
  Widget build(BuildContext context) {
    final config = widget.config;
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = constraints.biggest;
        if (size != _view) {
          final keep = _c.isReady ? _c.position : null;
          _view = size;
          _c.viewSize = size;
          // Rotation or a window resize: stay on the same content (FR-015).
          if (keep != null) _restore(keep);
        }
        final range = _zoomRange(size);
        final locked = _c.interactionLock.value;
        _c
          ..minZoom = range.min
          ..maxZoom = range.max;
        final viewer = PdfViewer(
          _ref,
          controller: _c.pdf,
          params: PdfViewerParams(
            layoutPages: _layoutPages,
            // Paged mode moves the view itself (PagedDragHandler); pinch stays with pdfrx.
            panEnabled: !_paged && !locked,
            scaleEnabled: !locked,
            normalizeMatrix: _paged ? _normalize : null,
            margin: 0,
            // The theme filter would recolour the background too; it is painted below.
            backgroundColor: Colors.transparent,
            sizeDelegateProvider: PdfViewerSizeDelegateProviderLegacy(
              minScale: range.min,
              maxScale: range.max,
              useAlternativeFitScaleAsMinScale: false,
              calculateInitialZoom: _normalZoom,
            ),
            // Taps belong to the reader's TapDetector (research R3); pdfrx handles none.
            onGeneralTap: (context, controller, details) => true,
            textSelectionParams: const PdfTextSelectionParams(enabled: false),
            enableKeyboardNavigation: false,
            onViewerReady: (document, controller) {
              _c.viewSize = _view;
              _c.goTo(config.initialPosition, animate: false);
            },
            pagePaintCallbacks: config.highlights.isEmpty ? null : [_paintHighlights],
            pageOverlaysBuilder: (context, pageRect, page) => [
              if (widget.document.failedPages.contains(page.pageNumber))
                const Positioned.fill(child: PageUnavailable()),
            ],
          ),
        );
        final filter = config.pageFilter;
        // Pages are recoloured for the reading theme (research R5). Everything pdfrx
        // paints is inside the filter, so highlight colours are chosen to come out right.
        final themed = ColoredBox(
          color: config.backgroundColor,
          child: filter == null ? viewer : ColorFiltered(colorFilter: filter, child: viewer),
        );
        if (!_paged) return themed;
        return Listener(
          onPointerDown: _drag.onDown,
          onPointerMove: _drag.onMove,
          onPointerUp: _drag.onUp,
          onPointerCancel: _drag.onCancel,
          child: themed,
        );
      },
    );
  }
}
