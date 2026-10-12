import 'dart:async';

import 'package:flutter/foundation.dart';

/// Whether the reader's controls are shown, and when they hide on their own (FR-003):
/// 3 s after the last interaction, unless something holds them open (a panel, a slider
/// drag) or a screen reader is on.
class AutoHide extends ChangeNotifier {
  AutoHide({this.delay = const Duration(seconds: 3)});

  final Duration delay;

  bool _visible = false;
  int _holds = 0;
  bool _screenReaderOn = false;
  Timer? _timer;

  bool get visible => _visible;

  set screenReaderOn(bool on) {
    if (on == _screenReaderOn) return;
    _screenReaderOn = on;
    _restart();
  }

  void show() {
    _set(true);
    _restart();
  }

  void hide() {
    _timer?.cancel();
    _set(false);
  }

  void toggle() => _visible ? hide() : show();

  /// The reader touched a control: start the 3 s again.
  void interacted() {
    if (_visible) _restart();
  }

  /// Keeps the controls up until the matching [release].
  void hold() {
    _holds++;
    _timer?.cancel();
  }

  void release() {
    if (_holds > 0) _holds--;
    _restart();
  }

  void _restart() {
    _timer?.cancel();
    if (_visible && _holds == 0 && !_screenReaderOn) _timer = Timer(delay, hide);
  }

  void _set(bool visible) {
    if (visible == _visible) return;
    _visible = visible;
    notifyListeners();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}
