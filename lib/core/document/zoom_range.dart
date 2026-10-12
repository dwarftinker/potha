import 'dart:math';
import 'dart:ui';

/// How far the reader can zoom, relative to the normal view (zoom 1.0).
class ZoomRange {
  const ZoomRange(this.min, this.max);

  final double min;
  final double max;

  /// Zoom buttons and keys step by a quarter (FR-016).
  static const step = 1.25;

  double clamp(double zoom) => zoom.clamp(min, max);
  double stepIn(double zoom) => clamp(zoom * step);
  double stepOut(double zoom) => clamp(zoom / step);
}

/// From the whole page fitting the view, up to 5 times the fit-width size (FR-018).
/// [pageAtNormal] is the page's size on screen at the normal view.
ZoomRange zoomRange({required Size pageAtNormal, required Size view}) {
  if (pageAtNormal.isEmpty || view.isEmpty) return const ZoomRange(1, 5);
  final whole = min(view.width / pageAtNormal.width, view.height / pageAtNormal.height);
  final fitWidth = view.width / pageAtNormal.width;
  return ZoomRange(min(1.0, whole), 5 * fitWidth);
}
