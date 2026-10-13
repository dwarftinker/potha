// Where the lookup panel opens (003 FR-003, research R7): at the bottom, or at the top
// when a bottom panel would cover the selected word. The first height is at most a third
// of the view; the reader can drag it taller.
import 'dart:ui';

enum PanelEdge { top, bottom }

typedef PanelPlacement = ({PanelEdge edge, double height});

/// Space kept between the word and the panel.
const _gap = 8.0;

/// [word] is the selection's rect in the same coordinates as [view] (0,0 at the top left).
PanelPlacement panelPlacement({required Size view, required Rect word}) {
  final height = view.height / 3;
  if (word.bottom + _gap <= view.height - height) return (edge: PanelEdge.bottom, height: height);
  if (word.top - _gap >= height) return (edge: PanelEdge.top, height: height);
  // Covered either way (a very tall selection): the edge farther from it.
  final edge = word.center.dy <= view.height / 2 ? PanelEdge.bottom : PanelEdge.top;
  return (edge: edge, height: height);
}
