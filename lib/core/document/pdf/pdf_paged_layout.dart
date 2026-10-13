// Paged mode on top of pdfrx's PdfViewer (002 research R2).
//
// Each page sits in a slot exactly one view wide, scaled to the fit, so at zoom 1.0 a
// horizontal move of one slot turns one page and neighbours slide in naturally. pdfrx's
// own panning is off in paged mode; [PagedDragHandler] moves the view instead, so it can
// snap to pages (pdfrx has no paging) and turn on a swipe at a zoomed page's edge.
import 'dart:math';

import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';
import 'package:pdfrx/pdfrx.dart';

import '../paged_snap.dart';
import '../document_format.dart';
import 'pdf_document_view.dart' show fitScale;
import 'pdf_view_controller.dart';

/// Space between slots, in view pixels; visible only while a page slides.
const pagedGap = 16.0;

/// One page per slot, left to right. A page shorter than the view is centred
/// vertically; a narrower one horizontally.
PdfPageLayout pagedLayout(List<Size> pages, Size view, PageFit fit) {
  final rects = <Rect>[];
  var height = view.height;
  for (var i = 0; i < pages.length; i++) {
    final p = pages[i];
    final s = fitScale(p.width, p.height, view, fit);
    final w = p.width * s, h = p.height * s;
    final x = i * (view.width + pagedGap) + (view.width - w) / 2;
    final y = h < view.height ? (view.height - h) / 2 : 0.0;
    rects.add(Rect.fromLTWH(x, y, w, h));
    height = max(height, h);
  }
  return PdfPageLayout(
    pageLayouts: rects,
    documentSize: Size(max(0.0, pages.length * (view.width + pagedGap) - pagedGap), height),
  );
}

/// The left edge of [page]'s slot.
double slotLeft(int page, Size view) => (page - 1) * (view.width + pagedGap);

/// Keeps the view on the current page: inside the page's rect when zoomed in, on its
/// slot at the normal view, and centred on any axis where the page is smaller than the
/// view. While [sliding], horizontal movement is free between the neighbouring slots.
Matrix4 clampToPage(
  Matrix4 m, {
  required PdfPageLayout layout,
  required Size view,
  required int page,
  bool sliding = false,
}) {
  final zoom = m.getMaxScaleOnAxis();
  final t = m.getTranslation();
  final rect = layout.pageLayouts[page - 1];

  double clampAxis(double translation, double start, double length, double viewLength) {
    final content = length * zoom;
    if (content <= viewLength) return -start * zoom + (viewLength - content) / 2;
    return translation.clamp(-(start + length) * zoom + viewLength, -start * zoom);
  }

  double x;
  if (sliding) {
    final lo = slotLeft(max(1, page - 1), view);
    final hi = slotLeft(min(layout.pageLayouts.length, page + 1), view);
    x = t.x.clamp(-hi * zoom, -lo * zoom);
  } else if (zoom <= 1.001) {
    x = clampAxis(t.x, slotLeft(page, view), view.width, view.width);
  } else {
    x = clampAxis(t.x, rect.left, rect.width, view.width);
  }
  final top = min(rect.top, 0.0);
  final bottom = max(rect.bottom, view.height);
  final y = clampAxis(t.y, top, bottom - top, view.height);
  return Matrix4.diagonal3Values(zoom, zoom, 1)..setTranslationRaw(x, y, 0);
}

/// One-finger drags in paged mode: slide and snap at the normal view; pan, and turn at
/// the edge, when zoomed. Two fingers belong to pdfrx's pinch zoom.
class PagedDragHandler {
  PagedDragHandler(this.controller);

  final PdfViewController controller;

  /// True while a drag slides between pages; read by the view's normalizeMatrix.
  bool sliding = false;

  final _pointers = <int>{};
  int? _pointer;
  Offset? _down;
  Offset? _last;
  bool _dragging = false;
  bool _pinched = false;
  double _overscroll = 0;
  VelocityTracker? _velocity;

  static const _slop = 18.0;

  PdfViewerController get _pdf => controller.pdf;
  Size get _view => controller.viewSize;

  void onDown(PointerDownEvent e) {
    _pointers.add(e.pointer);
    if (_pointers.length > 1) {
      _pinched = true;
      _endDrag(settle: false);
      return;
    }
    _pinched = false;
    _pointer = e.pointer;
    _down = _last = e.position;
    _dragging = false;
    _overscroll = 0;
    _velocity = VelocityTracker.withKind(e.kind)..addPosition(e.timeStamp, e.position);
  }

  void onMove(PointerMoveEvent e) {
    if (e.pointer != _pointer || _pinched || !controller.isReady) return;
    if (controller.interactionLock.value) {
      // A long-press took this pointer for a selection (003 research R6): drop it, so
      // neither the move nor the lift slides or turns the page.
      _pointer = null;
      _dragging = false;
      return;
    }
    _velocity?.addPosition(e.timeStamp, e.position);
    final delta = e.position - _last!;
    _last = e.position;
    if (!_dragging && (e.position - _down!).distance > _slop) _dragging = true;
    if (!_dragging) return;

    final m = _pdf.value.clone();
    final t = m.getTranslation();
    if (_pdf.currentZoom <= 1.001) {
      // Normal view: slide the strip; vertical movement only if the page is taller.
      sliding = true;
      m.setTranslationRaw(t.x + delta.dx, t.y + delta.dy, 0);
      _pdf.goTo(_clamp(m), duration: Duration.zero);
    } else {
      m.setTranslationRaw(t.x + delta.dx, t.y + delta.dy, 0);
      final clamped = _clamp(m);
      final lost = m.getTranslation().x - clamped.getTranslation().x;
      // Travel the page edge swallowed counts towards turning (FR-019).
      _overscroll = lost.abs() > 0.5 ? _overscroll + delta.dx : 0;
      _pdf.goTo(clamped, duration: Duration.zero);
    }
  }

  void onUp(PointerUpEvent e) {
    _pointers.remove(e.pointer);
    if (_pinched) {
      if (_pointers.isEmpty) {
        _pinched = false;
        _settle();
      }
      return;
    }
    if (e.pointer != _pointer) return;
    _pointer = null;
    if (!_dragging || !controller.isReady) return;
    final page = controller.currentPage;
    final count = _pdf.pageCount;
    final Snap snap;
    if (_pdf.currentZoom <= 1.001) {
      snap = pagedSnap(
        travel: e.position.dx - _down!.dx,
        velocity: _velocity?.getVelocity().pixelsPerSecond.dx ?? 0,
        viewWidth: _view.width,
        page: page,
        pageCount: count,
      );
    } else {
      snap = zoomedEdgeTurn(
        overscroll: _overscroll,
        viewWidth: _view.width,
        page: page,
        pageCount: count,
      );
    }
    _endDrag(settle: false);
    switch (snap) {
      case Snap.next:
        controller.next();
      case Snap.previous:
        controller.previous();
      case Snap.stay:
        _settle();
    }
  }

  void onCancel(PointerCancelEvent e) {
    _pointers.remove(e.pointer);
    if (e.pointer == _pointer) _endDrag(settle: true);
  }

  void _endDrag({required bool settle}) {
    final wasSliding = sliding;
    _pointer = null;
    _dragging = false;
    sliding = false;
    if (settle && wasSliding) _settle();
  }

  /// Snaps back onto the current page (after a short swipe or a pinch).
  void _settle() {
    if (!controller.isReady) return;
    _pdf.goTo(_clamp(_pdf.value), duration: const Duration(milliseconds: 180));
  }

  Matrix4 _clamp(Matrix4 m) => clampToPage(
    m,
    layout: _pdf.layout,
    view: _view,
    page: controller.currentPage,
    sliding: sliding,
  );
}
