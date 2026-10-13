import 'package:flutter/foundation.dart';

import '../../../core/document/document_format.dart';

/// What a tap on the page does (contracts/reader-ui.md, "Taps").
@immutable
sealed class TapAction {
  const TapAction();
}

class ToggleControls extends TapAction {
  const ToggleControls();
  @override
  bool operator ==(Object other) => other is ToggleControls;
  @override
  int get hashCode => 1;
}

class PreviousPage extends TapAction {
  const PreviousPage();
  @override
  bool operator ==(Object other) => other is PreviousPage;
  @override
  int get hashCode => 2;
}

class NextPage extends TapAction {
  const NextPage();
  @override
  bool operator ==(Object other) => other is NextPage;
  @override
  int get hashCode => 3;
}

class FollowLink extends TapAction {
  const FollowLink(this.link);
  final DocumentLink link;
  @override
  bool operator ==(Object other) => other is FollowLink && identical(other.link, link);
  @override
  int get hashCode => identityHashCode(link);
  @override
  String toString() => 'FollowLink($link)';
}

/// The share of the view width, on each side, that turns pages (FR-007).
const edgeZone = 0.2;

/// Classifies a tap at [x] in a view [viewWidth] wide. [pagePoint] is the page point
/// under the tap (null between pages) and [linksOnPage] the links on that page. A link
/// wins, then the edges, then the middle.
TapAction classifyTap({
  required double x,
  required double viewWidth,
  PagePoint? pagePoint,
  List<DocumentLink> linksOnPage = const [],
}) {
  if (pagePoint != null) {
    for (final link in linksOnPage) {
      if (link.rect.contains(pagePoint.offset)) return FollowLink(link);
    }
  }
  if (x < viewWidth * edgeZone) return const PreviousPage();
  if (x > viewWidth * (1 - edgeZone)) return const NextPage();
  return const ToggleControls();
}
