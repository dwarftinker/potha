/// Where a page swipe ends (paged mode, research R2).
enum Snap { previous, stay, next }

/// Share of the view width a drag must cover to turn the page.
const turnDistance = 0.25;

/// A fling faster than this (logical px/s) turns the page whatever the distance.
const turnVelocity = 800.0;

/// Decides a swipe at the normal view. [travel] and [velocity] are horizontal and
/// negative to the left (towards the next page).
Snap pagedSnap({
  required double travel,
  required double velocity,
  required double viewWidth,
  required int page,
  required int pageCount,
}) {
  final far = travel.abs() > viewWidth * turnDistance;
  final flung = velocity.abs() > turnVelocity && velocity.sign == travel.sign;
  if (!far && !flung) return Snap.stay;
  return _towards(travel, page, pageCount);
}

/// Decides a swipe on a zoomed page: only the horizontal travel the page edge stopped
/// ([overscroll]) counts, so panning inside the page never turns it (FR-019).
Snap zoomedEdgeTurn({
  required double overscroll,
  required double viewWidth,
  required int page,
  required int pageCount,
}) {
  if (overscroll.abs() <= viewWidth * turnDistance) return Snap.stay;
  return _towards(overscroll, page, pageCount);
}

Snap _towards(double travel, int page, int pageCount) {
  if (travel < 0) return page < pageCount ? Snap.next : Snap.stay;
  return page > 1 ? Snap.previous : Snap.stay;
}

/// How far an edge tap or Page Down scrolls in continuous mode: one view height less
/// about one line (1/24 of the view), so the last line stays visible (FR-007).
double continuousStep(double viewHeight) => viewHeight - viewHeight / 24;
