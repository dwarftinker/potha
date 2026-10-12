import 'dart:async';

import '../../core/document/reading_position.dart';

/// Saves the reading position (002 FR-011) at most once per [interval], always with the
/// latest position, and immediately on [flush] and [dispose]. Moves of under 1% of a
/// page are not worth a write.
class ProgressSaver {
  ProgressSaver({
    required this.pageCount,
    required this.save,
    this.interval = const Duration(seconds: 1),
  });

  final int pageCount;
  final Duration interval;
  final Future<void> Function(ReadingPosition position) save;

  Timer? _timer;
  ReadingPosition? _pending;
  ReadingPosition? _saved;

  void positionChanged(ReadingPosition position) {
    _pending = ReadingPosition.clamped(position.page, position.offsetY, pageCount: pageCount);
    _timer ??= Timer(interval, () {
      _timer = null;
      _write();
    });
  }

  /// Writes the pending position now (on leaving the book or the app going to the
  /// background).
  Future<void> flush() {
    _timer?.cancel();
    _timer = null;
    return _write();
  }

  Future<void> _write() async {
    final position = _pending;
    _pending = null;
    if (position == null) return;
    final saved = _saved;
    if (saved != null && saved.isNearlySameAs(position)) return;
    _saved = position;
    await save(position);
  }

  Future<void> dispose() => flush();
}
