import 'package:flutter_test/flutter_test.dart';
import 'package:potha/core/document/paged_snap.dart';

void main() {
  const width = 400.0;

  Snap snap(double travel, {double velocity = 0, int page = 5, int pageCount = 10}) =>
      pagedSnap(
          travel: travel, velocity: velocity, viewWidth: width, page: page, pageCount: pageCount);

  test('a drag past 25% of the width turns the page in the drag direction', () {
    expect(snap(-101), Snap.next);
    expect(snap(101), Snap.previous);
  });

  test('a shorter, slow drag snaps back', () {
    expect(snap(-99), Snap.stay);
    expect(snap(60, velocity: 100), Snap.stay);
  });

  test('a fling turns even when short', () {
    expect(snap(-30, velocity: -900), Snap.next);
    expect(snap(30, velocity: 900), Snap.previous);
  });

  test('a fling against the drag direction does not turn', () {
    expect(snap(-30, velocity: 900), Snap.stay);
  });

  test('nothing turns past the first or last page (FR-010)', () {
    expect(snap(200, page: 1), Snap.stay);
    expect(snap(-200, page: 10), Snap.stay);
  });

  test('while zoomed only travel the page edge swallowed counts (FR-019)', () {
    // Panning inside the page builds no overscroll, so it never turns.
    expect(zoomedEdgeTurn(overscroll: 0, viewWidth: width, page: 5, pageCount: 10), Snap.stay);
    expect(zoomedEdgeTurn(overscroll: -99, viewWidth: width, page: 5, pageCount: 10), Snap.stay);
    expect(zoomedEdgeTurn(overscroll: -101, viewWidth: width, page: 5, pageCount: 10), Snap.next);
    expect(zoomedEdgeTurn(overscroll: 101, viewWidth: width, page: 5, pageCount: 10),
        Snap.previous);
    expect(zoomedEdgeTurn(overscroll: 101, viewWidth: width, page: 1, pageCount: 10),
        Snap.stay);
  });

  test('the continuous step is one view height less one line of overlap (FR-007)', () {
    expect(continuousStep(960), 920);
  });
}
