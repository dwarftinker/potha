import 'dart:async';

/// Saves the reader's current page (FR-016b) at most once per [interval], always with
/// the latest page, and once more when disposed.
class ProgressSaver {
  ProgressSaver({
    required this.pageCount,
    required this.save,
    this.interval = const Duration(seconds: 1),
  });

  final int pageCount;
  final Duration interval;
  final Future<void> Function(int page) save;

  Timer? _timer;
  int? _pending;
  int? _saved;

  void pageChanged(int page) {
    _pending = page.clamp(1, pageCount);
    _timer ??= Timer(interval, () {
      _timer = null;
      _write();
    });
  }

  Future<void> _write() async {
    final page = _pending;
    _pending = null;
    if (page == null || page == _saved) return;
    _saved = page;
    await save(page);
  }

  Future<void> dispose() async {
    _timer?.cancel();
    _timer = null;
    await _write();
  }
}
