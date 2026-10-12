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
  Widget build(ReaderDocument doc,
          {required DocumentViewController controller, required ReaderViewConfig config}) =>
      PdfDocumentView(
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
    _c
      ..mode = widget.config.mode
      ..currentPage = widget.config.initialPosition.page
      ..onPositionChanged = widget.config.onPositionChanged;
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
      _afterLayout(() => _c.goTo(keep, animate: false));
    }
  }

  void _afterLayout(VoidCallback action) =>
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) WidgetsBinding.instance.addPostFrameCallback((_) => action());
      });

  PdfPageLayout _layoutPages(List<PdfPage> pages, PdfViewerParams params) {
    final view = _view.isEmpty ? const Size(400, 800) : _view;
    final sizes = [
      for (var i = 0; i < pages.length; i++) widget.document.pageSize(i + 1),
    ];
    return _paged
        ? pagedLayout(sizes, view, widget.config.fit)
        : continuousLayout(sizes, view, widget.config.fit);
  }

  Matrix4 _normalize(Matrix4 m, Size viewSize, PdfPageLayout layout, PdfViewerController? c) {
    if (!_paged || _view.isEmpty || layout.pageLayouts.isEmpty) return m;
    return clampToPage(m,
        layout: layout, view: _view, page: _c.currentPage, sliding: _drag.sliding);
  }

  @override
  Widget build(BuildContext context) {
    final config = widget.config;
    return LayoutBuilder(builder: (context, constraints) {
      final size = constraints.biggest;
      if (size != _view) {
        final keep = _c.isReady ? _c.position : null;
        _view = size;
        _c.viewSize = size;
        // Rotation or a window resize: stay on the same content (FR-015).
        if (keep != null) _afterLayout(() => _c.goTo(keep, animate: false));
      }
      final viewer = PdfViewer(
        _ref,
        controller: _c.pdf,
        params: PdfViewerParams(
          layoutPages: _layoutPages,
          // Paged mode moves the view itself (PagedDragHandler); pinch stays with pdfrx.
          panEnabled: !_paged,
          normalizeMatrix: _paged ? _normalize : null,
          margin: 0,
          backgroundColor: config.backgroundColor,
          sizeDelegateProvider: PdfViewerSizeDelegateProviderLegacy(
            minScale: _c.minZoom,
            maxScale: _c.maxZoom,
            useAlternativeFitScaleAsMinScale: false,
            calculateInitialZoom: (document, controller, fitZoom, coverZoom) => 1.0,
          ),
          // Taps belong to the reader's TapDetector (research R3); pdfrx handles none.
          onGeneralTap: (context, controller, details) => true,
          textSelectionParams: const PdfTextSelectionParams(enabled: false),
          enableKeyboardNavigation: false,
          onViewerReady: (document, controller) {
            _c.viewSize = _view;
            _c.goTo(config.initialPosition, animate: false);
          },
          pageOverlaysBuilder: (context, pageRect, page) => [
            if (widget.document.failedPages.contains(page.pageNumber))
              const Positioned.fill(child: PageUnavailable()),
          ],
        ),
      );
      if (!_paged) return viewer;
      return Listener(
        onPointerDown: _drag.onDown,
        onPointerMove: _drag.onMove,
        onPointerUp: _drag.onUp,
        onPointerCancel: _drag.onCancel,
        child: viewer,
      );
    });
  }
}
