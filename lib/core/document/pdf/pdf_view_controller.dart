// DocumentViewController over pdfrx's PdfViewerController (002 contracts/reader-document.md).
//
// The view lays pages out in view-sized units (pdf_document_view.dart), so a zoom of 1.0
// is always the normal view (fit width or fit page) and positions are plain arithmetic.
import 'dart:math';

import 'package:flutter/widgets.dart';
import 'package:pdfrx/pdfrx.dart';

import '../document_format.dart';
import '../paged_snap.dart';
import '../zoom_range.dart';

class PdfViewController extends ChangeNotifier implements DocumentViewController {
  PdfViewController() {
    pdf.addListener(_matrixChanged);
  }

  /// The underlying pdfrx controller; the view attaches it to its PdfViewer.
  final pdf = PdfViewerController();

  /// Set by the view: the current mode and view size.
  PageMode mode = PageMode.continuous;
  Size viewSize = Size.zero;

  /// Paged mode: the page being shown. Owned by the paged gesture handler.
  int currentPage = 1;

  /// Maximum zoom, relative to the normal view (FR-018). Set by the view.
  double maxZoom = 5;

  /// Minimum zoom, relative to the normal view. Set by the view.
  double minZoom = 1;

  ReadingPosition? _lastReported;
  ValueChanged<ReadingPosition>? onPositionChanged;

  @override
  bool get isReady => pdf.isReady && !viewSize.isEmpty;

  PdfPageLayout get _layout => pdf.layout;

  @override
  double get zoom => isReady ? pdf.currentZoom : 1;

  /// The visible area in document coordinates.
  Rect get visibleRect => pdf.visibleRect;

  /// The last position reported, without asking pdfrx (safe during layout).
  ReadingPosition get lastPosition => _lastReported ?? ReadingPosition(currentPage, 0);

  @override
  ReadingPosition get position {
    if (!isReady) return lastPosition;
    final double top;
    try {
      top = visibleRect.top;
    } catch (_) {
      // pdfrx has a document but no view size yet (its viewer is being laid out).
      return lastPosition;
    }
    final pages = _layout.pageLayouts;
    if (mode == PageMode.paged) {
      final rect = pages[currentPage - 1];
      return ReadingPosition.fromVisible(page: currentPage, pageRect: rect, visibleTop: top);
    }
    // Continuous: the page under the top edge of the view (or the next one, in a gap).
    var index = _firstPageEndingBelow(top);
    if (index >= pages.length) index = pages.length - 1;
    return ReadingPosition.fromVisible(page: index + 1, pageRect: pages[index], visibleTop: top);
  }

  /// Index of the first page whose bottom is below [y] (binary search; pages are in
  /// vertical order in continuous mode).
  int _firstPageEndingBelow(double y) {
    final pages = _layout.pageLayouts;
    var lo = 0, hi = pages.length;
    while (lo < hi) {
      final mid = (lo + hi) >> 1;
      if (pages[mid].bottom <= y) {
        lo = mid + 1;
      } else {
        hi = mid;
      }
    }
    return lo;
  }

  void _matrixChanged() {
    if (!isReady) return;
    notifyListeners();
    final p = position;
    final last = _lastReported;
    if (last != null && last.isNearlySameAs(p)) return;
    _lastReported = p;
    onPositionChanged?.call(p);
  }

  Matrix4 matrixFor({required double x, required double y, required double zoom}) =>
      Matrix4.diagonal3Values(zoom, zoom, 1)..setTranslationRaw(-x * zoom, -y * zoom, 0);

  /// The document x at the left of the view, keeping the current horizontal position when
  /// zoomed and centring otherwise.
  double _left(Rect pageRect, double zoom) {
    final viewWidth = viewSize.width / zoom;
    if (mode == PageMode.paged) return pageRect.left - max(0.0, (viewWidth - pageRect.width) / 2);
    if (zoom <= 1.001) return (_layout.documentSize.width - viewWidth) / 2;
    return visibleRect.left;
  }

  @override
  Future<void> goTo(ReadingPosition position, {bool animate = true}) async {
    if (!isReady) return;
    final p = ReadingPosition.clamped(
      position.page,
      position.offsetY,
      pageCount: _layout.pageLayouts.length,
    );
    final rect = _layout.pageLayouts[p.page - 1];
    final z = pdf.currentZoom;
    if (mode == PageMode.paged) currentPage = p.page;
    var top = p.topIn(rect);
    if (mode == PageMode.paged) {
      // Never above the page; a page shorter than the view is centred by the view.
      top = top.clamp(rect.top, max(rect.top, rect.bottom - viewSize.height / z));
    }
    await pdf.goTo(
      matrixFor(x: _left(rect, z), y: top, zoom: z),
      duration: animate ? const Duration(milliseconds: 200) : Duration.zero,
    );
    _matrixChanged();
  }

  /// One view height less about one line (FR-007), in document units.
  double get _screenStep => continuousStep(viewSize.height) / pdf.currentZoom;

  Future<void> _scrollDocument(double dy) async {
    if (!isReady) return;
    final v = visibleRect;
    final maxTop = max(0.0, _layout.documentSize.height - v.height);
    final top = (v.top + dy).clamp(0.0, maxTop);
    await pdf.goTo(
      matrixFor(x: v.left, y: top, zoom: pdf.currentZoom),
      duration: const Duration(milliseconds: 200),
    );
  }

  @override
  Future<void> next() async {
    if (!isReady) return;
    if (mode == PageMode.paged) {
      if (currentPage < _layout.pageLayouts.length) {
        await goTo(ReadingPosition(currentPage + 1, 0));
      }
      return;
    }
    await _scrollDocument(_screenStep);
  }

  @override
  Future<void> previous() async {
    if (!isReady) return;
    if (mode == PageMode.paged) {
      if (currentPage > 1) await goTo(ReadingPosition(currentPage - 1, 0));
      return;
    }
    await _scrollDocument(-_screenStep);
  }

  @override
  Future<void> scrollBy(double fraction) =>
      _scrollDocument(fraction * viewSize.height / pdf.currentZoom);

  ZoomRange get _range => ZoomRange(minZoom, maxZoom);

  Future<void> setZoom(double zoom) async {
    if (!isReady) return;
    await pdf.setZoom(pdf.centerPosition, _range.clamp(zoom));
  }

  /// Around the centre of the view (FR-016).
  @override
  Future<void> zoomIn() => setZoom(_range.stepIn(zoom));

  @override
  Future<void> zoomOut() => setZoom(_range.stepOut(zoom));

  @override
  PagePoint? pagePointAt(Offset globalPosition) {
    if (!isReady) return null;
    final doc = pdf.globalToDocument(globalPosition);
    if (doc == null) return null;
    final pages = _layout.pageLayouts;
    for (var i = 0; i < pages.length; i++) {
      final r = pages[i];
      if (r.contains(doc)) {
        return PagePoint(i + 1, Offset((doc.dx - r.left) / r.width, (doc.dy - r.top) / r.height));
      }
    }
    return null;
  }

  @override
  void dispose() {
    pdf.removeListener(_matrixChanged);
    super.dispose();
  }
}
