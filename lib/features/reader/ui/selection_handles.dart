// Handles at the ends of the lookup selection (003 FR-018, contracts/lookup-ui.md
// "Selection"): at least 48 × 48 dp, labelled, dragged with a raw Listener so the page
// view (locked meanwhile) never sees the drag.
import 'package:flutter/material.dart';

/// The visible knob's size inside the 48 dp touch target.
const _knob = 18.0;
const handleSize = 48.0;

class SelectionHandle extends StatelessWidget {
  const SelectionHandle({
    super.key,
    required this.start,
    required this.color,
    required this.onDragStart,
    required this.onDrag,
    required this.onDragEnd,
  });

  /// The start handle hangs below the selection's first character, the end handle
  /// below its last.
  final bool start;
  final Color color;
  final VoidCallback onDragStart;
  final ValueChanged<Offset> onDrag;
  final VoidCallback onDragEnd;

  @override
  Widget build(BuildContext context) => Semantics(
    container: true,
    label: start ? 'Selection start' : 'Selection end',
    child: Listener(
      behavior: HitTestBehavior.opaque,
      onPointerDown: (_) => onDragStart(),
      // The knob is below the text; aim the drag at the line above the finger.
      onPointerMove: (e) => onDrag(e.position - const Offset(0, handleSize / 2)),
      onPointerUp: (_) => onDragEnd(),
      onPointerCancel: (_) => onDragEnd(),
      child: SizedBox.square(
        dimension: handleSize,
        child: Align(
          alignment: Alignment.topCenter,
          child: Container(
            width: _knob,
            height: _knob,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.only(
                topLeft: start ? Radius.zero : const Radius.circular(_knob),
                topRight: start ? const Radius.circular(_knob) : Radius.zero,
                bottomLeft: const Radius.circular(_knob),
                bottomRight: const Radius.circular(_knob),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
