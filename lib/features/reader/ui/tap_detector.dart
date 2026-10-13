import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';

/// Reports taps on pointer up, without waiting to see whether a second tap follows
/// (FR-017, research R3). It listens to raw pointer events and never joins the gesture
/// arena, so recognisers below (pdfrx's pan, zoom and double tap) can't delay it.
///
/// A tap is one pointer, lifted within [maxDuration] and [slop] of where it went down,
/// while [movement] (the view's position) did not change.
///
/// 003 adds (research R6, contracts/lookup.md):
/// - a long-press: one pointer held [longPressDuration] within [slop], the view not
///   moving. It fires while the pointer is down; later moves of that pointer go to
///   [onLongPressMove] and its lift to [onLongPressEnd], with no tap.
/// - a mouse double-click: a second click within [maxDuration] and [slop]. The single
///   clicks have already fired as taps.
class TapDetector extends StatefulWidget {
  const TapDetector({
    super.key,
    required this.onTap,
    required this.child,
    this.onLongPress,
    this.onLongPressMove,
    this.onLongPressEnd,
    this.onDoubleClick,
    this.movement,
    this.slop = 18,
    this.maxDuration = const Duration(milliseconds: 300),
    this.longPressDuration = const Duration(milliseconds: 500),
  });

  final void Function(Offset globalPosition, Offset localPosition) onTap;
  final void Function(Offset globalPosition, Offset localPosition)? onLongPress;
  final void Function(Offset globalPosition)? onLongPressMove;
  final VoidCallback? onLongPressEnd;
  final void Function(Offset globalPosition, Offset localPosition)? onDoubleClick;
  final Listenable? movement;
  final double slop;
  final Duration maxDuration;
  final Duration longPressDuration;
  final Widget child;

  @override
  State<TapDetector> createState() => _TapDetectorState();
}

class _TapDetectorState extends State<TapDetector> {
  final _pointers = <int>{};
  int? _pointer;
  Offset? _down;
  Offset? _downLocal;
  Timer? _tooLong;
  Timer? _longPress;

  /// The gesture can no longer be a tap.
  bool _cancelled = false;

  /// The gesture can no longer become a long-press (moved, second pointer, view moved).
  bool _noLongPress = false;

  /// A long-press fired and owns this pointer until it is lifted.
  bool _longPressing = false;

  /// The last mouse click, while a second one would make a double-click.
  Offset? _lastClick;
  Timer? _clickWindow;

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
    _longPress?.cancel();
    _clickWindow?.cancel();
    super.dispose();
  }

  void _moved() {
    if (_pointer != null && !_longPressing) {
      _cancelled = true;
      _noLongPress = true;
      _longPress?.cancel();
    }
  }

  void _onDown(PointerDownEvent e) {
    _pointers.add(e.pointer);
    if (_pointers.length > 1) {
      _cancelled = true;
      _noLongPress = true;
      _longPress?.cancel();
      return;
    }
    _pointer = e.pointer;
    _down = e.position;
    _downLocal = e.localPosition;
    _cancelled = false;
    _noLongPress = false;
    _longPressing = false;
    _tooLong?.cancel();
    // Timers rather than event time stamps: they also work under fake time in tests.
    _tooLong = Timer(widget.maxDuration, () => _cancelled = true);
    _longPress?.cancel();
    if (widget.onLongPress != null) {
      _longPress = Timer(widget.longPressDuration, _fireLongPress);
    }
  }

  void _fireLongPress() {
    if (_pointer == null || _noLongPress || !mounted) return;
    _longPressing = true;
    _cancelled = true;
    widget.onLongPress?.call(_down!, _downLocal!);
  }

  void _onMove(PointerMoveEvent e) {
    if (e.pointer != _pointer) return;
    if (_longPressing) {
      widget.onLongPressMove?.call(e.position);
      return;
    }
    if ((e.position - _down!).distance > widget.slop) {
      _cancelled = true;
      _noLongPress = true;
      _longPress?.cancel();
    }
  }

  void _onUp(PointerUpEvent e) {
    _pointers.remove(e.pointer);
    if (e.pointer != _pointer) return;
    _pointer = null;
    _tooLong?.cancel();
    _longPress?.cancel();
    if (_longPressing) {
      _longPressing = false;
      widget.onLongPressEnd?.call();
      return;
    }
    if (_cancelled) return;
    if ((e.position - _down!).distance > widget.slop) return;
    widget.onTap(e.position, e.localPosition);
    if (e.kind == PointerDeviceKind.mouse) _click(e);
  }

  void _click(PointerUpEvent e) {
    final last = _lastClick;
    _clickWindow?.cancel();
    if (last != null && (e.position - last).distance <= widget.slop) {
      _lastClick = null;
      widget.onDoubleClick?.call(e.position, e.localPosition);
      return;
    }
    _lastClick = e.position;
    _clickWindow = Timer(widget.maxDuration, () => _lastClick = null);
  }

  void _onCancel(PointerCancelEvent e) {
    _pointers.remove(e.pointer);
    if (e.pointer == _pointer) {
      _pointer = null;
      _tooLong?.cancel();
      _longPress?.cancel();
      if (_longPressing) {
        _longPressing = false;
        widget.onLongPressEnd?.call();
      }
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
