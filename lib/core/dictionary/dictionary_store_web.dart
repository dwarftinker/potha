// Web: nothing is fetched at app load. The first time the reader opens a book (or looks
// a word up), the gzip asset is downloaded with progress and decompressed by the
// browser's DecompressionStream as it arrives. It is kept as `dictionary-en-<version>`,
// so lookups work offline after that (FR-022, research R2).
//
// Where drift would keep it decides how it gets there (T006/T082: drift's
// initializeDatabase held several full copies in memory, a 712 MB peak on the S24):
// - IndexedDB (Chrome on Android): streamed straight into IndexedDB in 4 KiB blocks
//   (sqlite_idb_writer.dart), then opened by drift;
// - OPFS: the decompressed file goes to drift's initializeDatabase, which writes it to
//   disk without further copies.
// ignore_for_file: prefer_initializing_formals (named parameters can't be private)
import 'dart:async';
import 'dart:js_interop';

import 'package:drift/wasm.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:web/web.dart' as web;

import 'dictionary_database.dart';
import 'dictionary_store.dart';
import 'sqlite_idb_writer.dart';

DictionaryStore createDictionaryStore() => WebDictionaryStore(
  // Flutter web serves an asset at assets/<asset path>.
  assetUrl: 'assets/$dictionaryAsset',
  loadVersion: () async => (await rootBundle.loadString(dictionaryVersionAsset)).trim(),
  sqlite3Wasm: Uri.parse('sqlite3.wasm'),
  driftWorker: Uri.parse('drift_worker.js'),
);

const _namePrefix = 'dictionary-en-';

class _Offline implements Exception {
  const _Offline();
}

class WebDictionaryStore implements DictionaryStore {
  WebDictionaryStore({
    required String assetUrl,
    required Future<String> Function() loadVersion,
    required Uri sqlite3Wasm,
    required Uri driftWorker,
    bool Function()? isOnline,
    @visibleForTesting WasmStorageImplementation? storage,
  }) : _assetUrl = assetUrl,
       _loadVersion = loadVersion,
       _sqlite3Wasm = sqlite3Wasm,
       _driftWorker = driftWorker,
       _isOnline = isOnline ?? (() => web.window.navigator.onLine),
       _storage = storage;

  final String _assetUrl;
  final Future<String> Function() _loadVersion;
  final Uri _sqlite3Wasm;
  final Uri _driftWorker;
  final bool Function() _isOnline;

  /// Tests: use this storage instead of drift's choice.
  final WasmStorageImplementation? _storage;

  final _changes = StreamController<DictionaryStatus>.broadcast();
  final _ready = Completer<Lexicon>();
  DictionaryStatus _current = const DictionaryNotStarted();
  bool _running = false;
  DictionaryDatabase? _db;

  @override
  DictionaryStatus get current => _current;

  @override
  Stream<DictionaryStatus> get status => _changes.stream;

  @override
  Future<Lexicon> get ready => _ready.future;

  @override
  void ensureStarted() {
    if (_running || _ready.isCompleted) return;
    _running = true;
    unawaited(_prepare()); // clears _running itself on failure; success completes ready
  }

  Future<void> _prepare() async {
    String? name;
    Object? downloadError;
    try {
      name = '$_namePrefix${await _loadVersion()}';
      final probe = await WasmDatabase.probe(
        sqlite3Uri: _sqlite3Wasm,
        driftWorkerUri: _driftWorker,
        databaseName: name,
      );
      final storage = _storage ?? _choose(probe, name);
      var initialize = !probe.existingDatabases.any((e) => e.$2 == name);
      if (storage.storageApi == WebStorageApi.indexedDb && !await sqliteIdbHasDatabase(name)) {
        // Also clears a write that was cut short (no file entry yet).
        await sqliteIdbDelete(name);
        await sqliteIdbWrite(name, await _download());
        initialize = false;
      }
      final connection = await probe.open(
        storage,
        name,
        // An exception here isn't passed on by drift's open (it surfaces as an
        // uncaught error, and drift carries on with an empty database). So the error is
        // kept, null makes drift create an empty file, and DictionaryDatabase.open
        // rejects that; the empty file is deleted below.
        initializeDatabase: initialize
            ? () async {
                try {
                  final buffer = await web.Response(await _download()).arrayBuffer().toDart;
                  return buffer.toDart.asUint8List();
                } catch (e) {
                  downloadError = e;
                  return null;
                }
              }
            : null,
      );
      final db = await DictionaryDatabase.open(connection);
      _db = db;
      _set(const DictionaryReady());
      _ready.complete(db);
      unawaited(_deleteOlder(keep: name));
    } catch (e) {
      final reason = (downloadError ?? e) is _Offline
          ? DictionaryFailure.offline
          : DictionaryFailure.error;
      // Remove a partial or empty copy so the next attempt downloads again.
      if (name != null) await _delete(name);
      _running = false; // before announcing it, so a listener can retry at once
      _set(DictionaryFailed(reason));
    }
  }

  /// drift's own choice (WasmDatabase.open): the best storage, or the one already
  /// holding [name].
  static WasmStorageImplementation _choose(WasmProbeResult probe, String name) {
    final available = [...probe.availableStorages]..sort((a, b) => a.index - b.index);
    final best = available.firstOrNull ?? WasmStorageImplementation.inMemory;
    for (final (api, existing) in probe.existingDatabases) {
      if (existing != name || api == best.storageApi) continue;
      return available.firstWhere((e) => e.storageApi == api, orElse: () => best);
    }
    return best;
  }

  /// The decompressed dictionary as a stream; progress is reported as the compressed
  /// bytes arrive. Nothing is kept: each chunk goes on to the decompressor.
  Future<web.ReadableStream> _download() async {
    if (!_isOnline()) throw const _Offline();
    _set(const DictionaryDownloading(0, null));
    final response = await web.window.fetch(_assetUrl.toJS).toDart;
    if (!response.ok) throw StateError('Dictionary download failed: HTTP ${response.status}');
    final total = int.tryParse(response.headers.get('Content-Length') ?? '');
    final gzip = web.DecompressionStream('gzip');
    final writer = gzip.writable.getWriter();
    final reader = response.body!.getReader() as web.ReadableStreamDefaultReader;
    unawaited(() async {
      var bytes = 0;
      try {
        while (true) {
          final result = await reader.read().toDart;
          if (result.done) break;
          final chunk = result.value as JSUint8Array;
          bytes += chunk.toDart.lengthInBytes;
          _set(DictionaryDownloading(bytes, total));
          await writer.write(chunk).toDart;
        }
        if (total == null) _set(DictionaryDownloading(bytes, bytes));
        await writer.close().toDart;
      } catch (e) {
        // The reader of the decompressed stream sees the error.
        unawaited(writer.abort(e.toString().toJS).toDart.catchError((_) => null));
      }
    }());
    return gzip.readable;
  }

  Future<void> _deleteOlder({required String keep}) async {
    // drift's probe doesn't list IndexedDB databases (Chrome on the S24 kept the old
    // copy), so those are found by name.
    try {
      final names = (await web.window.indexedDB.databases().toDart).toDart.map((d) => d.name);
      for (final name in names) {
        if (name.startsWith(_namePrefix) && name != keep) await sqliteIdbDelete(name);
      }
    } catch (_) {}
    try {
      final probe = await WasmDatabase.probe(
        sqlite3Uri: _sqlite3Wasm,
        driftWorkerUri: _driftWorker,
      );
      for (final existing in probe.existingDatabases) {
        if (existing.$2.startsWith(_namePrefix) && existing.$2 != keep) {
          await probe.deleteDatabase(existing);
        }
      }
    } catch (_) {
      // Best effort: an old copy only costs space.
    }
  }

  Future<void> _delete(String name) async {
    try {
      final probe = await WasmDatabase.probe(
        sqlite3Uri: _sqlite3Wasm,
        driftWorkerUri: _driftWorker,
        databaseName: name,
      );
      for (final existing in probe.existingDatabases) {
        if (existing.$2 == name) await probe.deleteDatabase(existing);
      }
    } catch (_) {}
  }

  void _set(DictionaryStatus status) {
    _current = status;
    if (!_changes.isClosed) _changes.add(status);
  }

  @override
  Future<void> close() async {
    await _changes.close();
    await _db?.close();
  }
}
