import 'dart:async';

import 'package:flutter/widgets.dart';

/// Reports taps on pointer up, without waiting to see whether a second tap follows
/// (FR-017, research R3). It listens to raw pointer events and never joins the gesture
/// arena, so recognisers below (pdfrx's pan, zoom and double tap) can't delay it.
///
/// A tap is one pointer, lifted within [maxDuration] and [slop] of where it went down,
/// while [movement] (the view's position) did not change.
class TapDetector extends StatefulWidget {
  const TapDetector({
    super.key,
    required this.onTap,
    required this.child,
    this.movement,
    this.slop = 18,
    this.maxDuration = const Duration(milliseconds: 300),
  });

  final void Function(Offset globalPosition, Offset localPosition) onTap;
  final Listenable? movement;
  final double slop;
  final Duration maxDuration;
  final Widget child;

  @override
  State<TapDetector> createState() => _TapDetectorState();
}

class _TapDetectorState extends State<TapDetector> {
  final _pointers = <int>{};
  int? _pointer;
  Offset? _down;
  Timer? _tooLong;
  bool _cancelled = false;

  @override
  void initState() {
    super.initState();
    widget.movement?.addListener(_moved);
  }

  @override
  void didUpdateWidget(TapDetector old) {
    super.didUpdateWidget(old);
    if (old.movement != widget.movement) {
      old.movement?.removeListener(_moved);
      widget.movement?.addListener(_moved);
    }
  }

  @override
  void dispose() {
    widget.movement?.removeListener(_moved);
    _tooLong?.cancel();
    super.dispose();
  }

  void _moved() {
    if (_pointer != null) _cancelled = true;
  }

  void _onDown(PointerDownEvent e) {
    _pointers.add(e.pointer);
    if (_pointers.length > 1) {
      _cancelled = true;
      return;
    }
    _pointer = e.pointer;
    _down = e.position;
    _cancelled = false;
    _tooLong?.cancel();
    // A timer rather than event time stamps: it also works under fake time in tests.
    _tooLong = Timer(widget.maxDuration, () => _cancelled = true);
  }

  void _onMove(PointerMoveEvent e) {
    if (e.pointer == _pointer && (e.position - _down!).distance > widget.slop) {
      _cancelled = true;
    }
  }

  void _onUp(PointerUpEvent e) {
    _pointers.remove(e.pointer);
    if (e.pointer != _pointer) return;
    _pointer = null;
    _tooLong?.cancel();
    if (_cancelled) return;
    if ((e.position - _down!).distance > widget.slop) return;
    widget.onTap(e.position, e.localPosition);
  }

  void _onCancel(PointerCancelEvent e) {
    _pointers.remove(e.pointer);
    if (e.pointer == _pointer) {
      _pointer = null;
      _tooLong?.cancel();
    }
  }

  @override
  Widget build(BuildContext context) => Listener(
    onPointerDown: _onDown,
    onPointerMove: _onMove,
    onPointerUp: _onUp,
    onPointerCancel: _onCancel,
    child: widget.child,
  );
}
