import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:potha/core/document/zoom_range.dart';

void main() {
  const view = Size(400, 800);

  test('fit width: from the whole page fitting to 5x fit width (FR-018)', () {
    // A Letter page at fit width on a 400 x 800 view: 400 x 517.6, already whole.
    final r = zoomRange(pageAtNormal: const Size(400, 517.6), view: view);
    expect(r.min, 1);
    expect(r.max, 5);
  });

  test('fit width, a page taller than the view: zooming out may show it whole', () {
    final r = zoomRange(pageAtNormal: const Size(400, 1000), view: view);
    expect(r.min, closeTo(0.8, 1e-9));
    expect(r.max, 5);
  });

  test('fit page: the maximum is 5x the fit-width size', () {
    // A landscape page fitted whole: 400 x 283; fit width is the same, so max 5.
    expect(zoomRange(pageAtNormal: const Size(400, 283), view: view).max, 5);
    // A tall page fitted whole on a wide view: 300 x 400; fit width would be 2x.
    final r = zoomRange(pageAtNormal: const Size(300, 400), view: const Size(600, 400));
    expect(r.min, 1);
    expect(r.max, closeTo(10, 1e-9));
  });

  test('zoom steps multiply by 1.25 and stay in range', () {
    const r = ZoomRange(1, 5);
    expect(r.stepIn(1), 1.25);
    expect(r.stepOut(1.25), 1);
    expect(r.stepIn(4.5), 5);
    expect(r.stepOut(1.1), 1);
  });
}
