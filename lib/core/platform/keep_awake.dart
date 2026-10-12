// Keeps the screen on while reading (002 FR-029, research R9).
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

abstract interface class KeepAwake {
  Future<void> enable();
  Future<void> disable();
}

/// Android and iOS through the platform's keep-screen-on flag; web through the Screen
/// Wake Lock API, which needs a secure context and is released when the tab is hidden.
class WakelockKeepAwake implements KeepAwake {
  const WakelockKeepAwake();

  @override
  Future<void> enable() async {
    try {
      await WakelockPlus.enable();
    } catch (_) {
      // Not supported here (e.g. an insecure web context); reading still works.
    }
  }

  @override
  Future<void> disable() async {
    try {
      await WakelockPlus.disable();
    } catch (_) {}
  }
}

final keepAwakeProvider = Provider<KeepAwake>((ref) => const WakelockKeepAwake());
