import 'package:flutter/foundation.dart';

import '../../../core/document/reading_position.dart';

/// One step back after a jump (FR-026, research R8): where the reader was before the
/// latest jump. Page turns and scrolling leave it alone.
class JumpBack extends ChangeNotifier {
  ReadingPosition? _target;

  ReadingPosition? get target => _target;

  void recordJump({required ReadingPosition from}) {
    _target = from;
    notifyListeners();
  }

  /// Returns the position to go back to, and forgets it.
  ReadingPosition? use() {
    final target = _target;
    clear();
    return target;
  }

  void clear() {
    if (_target == null) return;
    _target = null;
    notifyListeners();
  }
}
