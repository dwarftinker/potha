// Web: nothing is fetched at app load. The first time the reader opens a book (or looks
// a word up), the gzip asset is downloaded with progress, decompressed by the browser's
// DecompressionStream, and handed to drift's initializeDatabase, which keeps it in OPFS
// (or IndexedDB) as `dictionary-en-<version>`. After that, lookups work offline
// (FR-022, research R2).
//
// Risk (R2): initializeDatabase takes the whole file in memory. If peak memory on phones
// is too high, stream into drift's OPFS file instead (measured in T006 / T082).
// ignore_for_file: prefer_initializing_formals (named parameters can't be private)
import 'dart:async';
import 'dart:js_interop';

import 'package:drift/wasm.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:flutter/services.dart';
import 'package:web/web.dart' as web;

import 'dictionary_database.dart';
import 'dictionary_store.dart';

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
  }) : _assetUrl = assetUrl,
       _loadVersion = loadVersion,
       _sqlite3Wasm = sqlite3Wasm,
       _driftWorker = driftWorker,
       _isOnline = isOnline ?? (() => web.window.navigator.onLine);

  final String _assetUrl;
  final Future<String> Function() _loadVersion;
  final Uri _sqlite3Wasm;
  final Uri _driftWorker;
  final bool Function() _isOnline;

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
      final executor = driftDatabase(
        name: name,
        web: DriftWebOptions(
          sqlite3Wasm: _sqlite3Wasm,
          driftWorker: _driftWorker,
          // An exception here isn't passed on by drift's open (it surfaces as an
          // uncaught error, and drift carries on with an empty database). So the error is
          // kept, null makes drift create an empty file, and DictionaryDatabase.open
          // rejects that; the empty file is deleted below.
          initializeDatabase: () async {
            try {
              return await _download();
            } catch (e) {
              downloadError = e;
              return null;
            }
          },
        ),
      );
      final db = await DictionaryDatabase.open(executor);
      _db = db;
      _set(const DictionaryReady());
      _ready.complete(db);
      unawaited(_deleteOlder(keep: name));
    } catch (e) {
      final reason = (downloadError ?? e) is _Offline
          ? DictionaryFailure.offline
          : DictionaryFailure.error;
      // If drift kept an empty database after the failed download, remove it so the
      // next attempt downloads again.
      if (name != null) await _delete(name);
      _running = false; // before announcing it, so a listener can retry at once
      _set(DictionaryFailed(reason));
    }
  }

  Future<Uint8List> _download() async {
    if (!_isOnline()) throw const _Offline();
    _set(const DictionaryDownloading(0, null));
    final response = await web.window.fetch(_assetUrl.toJS).toDart;
    if (!response.ok) throw StateError('Dictionary download failed: HTTP ${response.status}');
    final total = int.tryParse(response.headers.get('Content-Length') ?? '');
    final reader = response.body!.getReader() as web.ReadableStreamDefaultReader;
    final chunks = <JSUint8Array>[];
    var bytes = 0;
    while (true) {
      final result = await reader.read().toDart;
      if (result.done) break;
      final chunk = result.value as JSUint8Array;
      chunks.add(chunk);
      bytes += chunk.toDart.lengthInBytes;
      _set(DictionaryDownloading(bytes, total));
    }
    if (total == null) _set(DictionaryDownloading(bytes, bytes));
    // Decompressed by the browser, off the Dart code's critical path.
    final gzip = web.DecompressionStream('gzip');
    final stream = web.Blob(chunks.toJS)
        .stream()
        .pipeThrough(web.ReadableWritablePair(readable: gzip.readable, writable: gzip.writable));
    final buffer = await web.Response(stream).arrayBuffer().toDart;
    return buffer.toDart.asUint8List();
  }

  Future<void> _deleteOlder({required String keep}) async {
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
