// Whether any network is connected (003 research R9). Used only to decide whether to
// offer "Search online"; a request can still fail and says so.
import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

abstract interface class NetworkStatus {
  bool get isOnline;

  /// Emits when [isOnline] changes.
  Stream<bool> get changes;
}

/// connectivity_plus on Android, iOS and web. Starts optimistic (online) until the first
/// check answers, so the button never flickers away on a connected device.
class ConnectivityNetworkStatus implements NetworkStatus {
  ConnectivityNetworkStatus([Connectivity? connectivity])
    : _connectivity = connectivity ?? Connectivity() {
    _subscription = _connectivity.onConnectivityChanged.listen(_update, onError: (_) {});
    _connectivity.checkConnectivity().then(_update, onError: (_) {});
  }

  final Connectivity _connectivity;
  late final StreamSubscription<List<ConnectivityResult>> _subscription;
  final _changes = StreamController<bool>.broadcast();
  bool _online = true;

  @override
  bool get isOnline => _online;

  @override
  Stream<bool> get changes => _changes.stream;

  void _update(List<ConnectivityResult> results) {
    final online = results.any((r) => r != ConnectivityResult.none);
    if (online == _online) return;
    _online = online;
    _changes.add(online);
  }

  void dispose() {
    _subscription.cancel();
    _changes.close();
  }
}

final networkStatusProvider = Provider<NetworkStatus>((ref) {
  final status = ConnectivityNetworkStatus();
  ref.onDispose(status.dispose);
  return status;
});
