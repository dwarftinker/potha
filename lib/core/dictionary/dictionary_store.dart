// Opens or prepares the platform's dictionary file (003 research R2, FR-022):
// unpacked from the app's asset on Android and iOS, downloaded once on the web.
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'dictionary_store_io.dart'
    if (dart.library.js_interop) 'dictionary_store_web.dart'
    as platform;
import 'lexicon.dart';

export 'lexicon.dart';

/// The asset every platform uses (research R2).
const dictionaryAsset = 'assets/dictionary/en.sqlite.gz';
const dictionaryVersionAsset = 'assets/dictionary/version';

abstract interface class DictionaryStore {
  DictionaryStatus get current;

  /// Emits each change of [current].
  Stream<DictionaryStatus> get status;

  /// Starts preparing: unpacking on mobile, downloading on the web. Safe to call again;
  /// after a failure it retries.
  void ensureStarted();

  /// Completes once the dictionary can be used. Never fails: failures show in [status].
  Future<Lexicon> get ready;

  Future<void> close();
}

final dictionaryStoreProvider = Provider<DictionaryStore>((ref) {
  final store = platform.createDictionaryStore();
  ref.onDispose(store.close);
  return store;
});
