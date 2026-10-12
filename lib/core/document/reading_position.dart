// Where the reader is in a book (002 research R4).
import 'dart:ui';

import 'package:flutter/foundation.dart';

/// A page (1-based) and the fraction of that page's height at the top of the visible
/// area (0 = the top of the page). A fraction survives rotation, resizing and fit
/// changes, because it doesn't depend on how large the page is drawn.
@immutable
class ReadingPosition {
  const ReadingPosition(this.page, this.offsetY);

  /// [page] clamped to 1..[pageCount] and [offsetY] to 0..1.
  factory ReadingPosition.clamped(int page, double offsetY, {required int pageCount}) =>
      ReadingPosition(page.clamp(1, pageCount), offsetY.clamp(0.0, 1.0));

  /// The position whose top edge is at [visibleTop], on [page] laid out at [pageRect]
  /// (both in the same coordinates).
  factory ReadingPosition.fromVisible({
    required int page,
    required Rect pageRect,
    required double visibleTop,
  }) {
    if (pageRect.height <= 0) return ReadingPosition(page, 0);
    return ReadingPosition(page, ((visibleTop - pageRect.top) / pageRect.height).clamp(0.0, 1.0));
  }

  final int page;
  final double offsetY;

  /// The y coordinate to put at the top of the view, for this page laid out at [pageRect].
  double topIn(Rect pageRect) => pageRect.top + offsetY * pageRect.height;

  /// True if [other] is on the same page and less than 1% of a page away.
  bool isNearlySameAs(ReadingPosition other) =>
      other.page == page && (other.offsetY - offsetY).abs() < 0.01;

  @override
  bool operator ==(Object other) =>
      other is ReadingPosition && other.page == page && other.offsetY == offsetY;

  @override
  int get hashCode => Object.hash(page, offsetY);

  @override
  String toString() => 'ReadingPosition(page $page, ${offsetY.toStringAsFixed(3)})';
}
