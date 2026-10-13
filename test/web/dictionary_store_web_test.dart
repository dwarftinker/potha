// The web dictionary: downloaded on first use, then kept (003 T017, FR-022, research R2).
// Run with: flutter test --platform chrome test/web/
// test/web/sqlite3.wasm and drift_worker.js are symlinks to web/ so drift can load here.
@TestOn('browser')
library;

import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'dart:math';
import 'dart:typed_data';

import 'package:drift/wasm.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:potha/core/dictionary/dictionary_database.dart';
import 'package:potha/core/dictionary/dictionary_store.dart';
import 'package:potha/core/dictionary/dictionary_store_web.dart';
import 'package:potha/core/dictionary/sqlite_idb_writer.dart';
import 'package:web/web.dart' as web;

const _sample = '../fixtures/dictionary/dict_sample.sqlite.gz';

void main() {
  final stores = <WebDictionaryStore>[];

  tearDown(() async {
    for (final s in stores) {
      await s.close();
    }
    stores.clear();
  });

  String freshVersion() => 'test-${Random().nextInt(1 << 30)}';

  WebDictionaryStore store({
    String asset = _sample,
    bool Function()? isOnline,
    String? version,
    WasmStorageImplementation? storage,
  }) {
    // A fresh database name per test, so earlier downloads don't count.
    final v = version ?? freshVersion();
    final s = WebDictionaryStore(
      assetUrl: asset,
      loadVersion: () async => v,
      sqlite3Wasm: Uri.parse('sqlite3.wasm'),
      driftWorker: Uri.parse('drift_worker.js'),
      isOnline: isOnline,
      storage: storage,
    );
    stores.add(s);
    return s;
  }

  int requestsFor(String asset) => web.window.performance
      .getEntriesByType('resource')
      .toDart
      .where((e) => e.name.endsWith(asset.split('/').last))
      .length;

  test('no request happens before ensureStarted', () async {
    web.window.performance.clearResourceTimings();
    final s = store();
    await Future<void>.delayed(const Duration(milliseconds: 200));
    expect(requestsFor(_sample), 0);
    expect(s.current, isA<DictionaryNotStarted>());
  });

  test('downloads with progress up to 100%, then is ready and looks up', () async {
    final s = store();
    final statuses = <DictionaryStatus>[];
    s.status.listen(statuses.add);
    s.ensureStarted();
    final lexicon = await s.ready.timeout(const Duration(seconds: 30));
    final progress = statuses.whereType<DictionaryDownloading>().toList();
    expect(progress, isNotEmpty);
    expect(progress.last.fraction, 1.0);
    expect(statuses.last, isA<DictionaryReady>());
    expect(await lexicon.entries('melancholy'), isNotEmpty);
    expect(lexicon.info.licence, 'CC BY-SA 4.0');
  });

  test('a failed download gives failed(error)', () async {
    final s = store(asset: 'missing.sqlite.gz');
    s.ensureStarted();
    final failed = await s.status
        .firstWhere((e) => e is DictionaryFailed)
        .timeout(const Duration(seconds: 30));
    expect((failed as DictionaryFailed).reason, DictionaryFailure.error);
  });

  test('offline gives failed(offline), and the next ensureStarted retries', () async {
    var online = false;
    final s = store(isOnline: () => online);
    s.ensureStarted();
    final failed = await s.status
        .firstWhere((e) => e is DictionaryFailed)
        .timeout(const Duration(seconds: 30));
    expect((failed as DictionaryFailed).reason, DictionaryFailure.offline);
    online = true;
    s.ensureStarted();
    final lexicon = await s.ready.timeout(const Duration(seconds: 30));
    expect(await lexicon.hasEntry('melancholy'), isTrue);
  });

  // The streamed IndexedDB path (research R2: Chrome on Android uses IndexedDB, where
  // drift's initializeDatabase peaked at 712 MB).
  Future<WasmStorageImplementation?> indexedDbStorage() async {
    final probe = await WasmDatabase.probe(
      sqlite3Uri: Uri.parse('sqlite3.wasm'),
      driftWorkerUri: Uri.parse('drift_worker.js'),
    );
    for (final s in [
      WasmStorageImplementation.sharedIndexedDb,
      WasmStorageImplementation.unsafeIndexedDb,
    ]) {
      if (probe.availableStorages.contains(s)) return s;
    }
    return null;
  }

  test('IndexedDB: the download is streamed into IndexedDB, drift opens it, and a later '
      'start reuses it without downloading', () async {
    final storage = await indexedDbStorage();
    if (storage == null) return markTestSkipped('no IndexedDB storage in this browser');
    final version = freshVersion();
    final s = store(version: version, storage: storage);
    final statuses = <DictionaryStatus>[];
    s.status.listen(statuses.add);
    s.ensureStarted();
    final lexicon = await s.ready.timeout(const Duration(seconds: 30));
    expect(statuses.whereType<DictionaryDownloading>().last.fraction, 1.0);
    expect(await lexicon.entries('melancholy'), isNotEmpty);
    expect(await sqliteIdbHasDatabase('dictionary-en-$version'), isTrue);
    await s.close();

    web.window.performance.clearResourceTimings();
    final again = store(version: version, storage: storage)..ensureStarted();
    final reopened = await again.ready.timeout(const Duration(seconds: 30));
    expect(await reopened.hasEntry('melancholy'), isTrue);
    expect(requestsFor(_sample), 0, reason: 'no second download');
  });

  test('IndexedDB writer: many small batches give a database drift reads', () async {
    final storage = await indexedDbStorage();
    if (storage == null) return markTestSkipped('no IndexedDB storage in this browser');
    final name = 'dictionary-en-${freshVersion()}';
    final gzip = web.DecompressionStream('gzip');
    final response = await web.window.fetch(_sample.toJS).toDart;
    final length = await sqliteIdbWrite(
      name,
      response.body!.pipeThrough(
        web.ReadableWritablePair(readable: gzip.readable, writable: gzip.writable),
      ),
      batchBytes: 8192,
    );
    expect(length % 4096, 0, reason: 'SQLite files are whole pages');
    final probe = await WasmDatabase.probe(
      sqlite3Uri: Uri.parse('sqlite3.wasm'),
      driftWorkerUri: Uri.parse('drift_worker.js'),
      databaseName: name,
    );
    final db = await DictionaryDatabase.open(await probe.open(storage, name));
    expect(await db.entries('melancholy'), isNotEmpty);
    expect(await db.formsOf('mice'), isNotEmpty);
    await db.close();
    await sqliteIdbDelete(name);
  });

  test('IndexedDB: a write cut short is cleared and downloaded again', () async {
    final storage = await indexedDbStorage();
    if (storage == null) return markTestSkipped('no IndexedDB storage in this browser');
    final version = freshVersion();
    final name = 'dictionary-en-$version';
    // A stream that gives one block's worth, then fails: blocks but no file entry.
    final source = JSObject()
      ..setProperty(
        'start'.toJS,
        ((web.ReadableStreamDefaultController c) {
          c.enqueue(Uint8List(4096).toJS);
          c.error('cut'.toJS);
        }).toJS,
      );
    await expectLater(sqliteIdbWrite(name, web.ReadableStream(source)), throwsA(anything));
    expect(await sqliteIdbHasDatabase(name), isFalse);

    final s = store(version: version, storage: storage)..ensureStarted();
    final lexicon = await s.ready.timeout(const Duration(seconds: 30));
    expect(await lexicon.hasEntry('melancholy'), isTrue);
  });

  test('older dictionary versions in IndexedDB are deleted once the new one is ready', () async {
    final old = 'dictionary-en-${freshVersion()}';
    final response = await web.window.fetch(_sample.toJS).toDart;
    final gzip = web.DecompressionStream('gzip');
    await sqliteIdbWrite(
      old,
      response.body!.pipeThrough(
        web.ReadableWritablePair(readable: gzip.readable, writable: gzip.writable),
      ),
    );
    expect(await sqliteIdbHasDatabase(old), isTrue);
    final s = store()..ensureStarted();
    await s.ready.timeout(const Duration(seconds: 30));
    final end = DateTime.now().add(const Duration(seconds: 10));
    while (await sqliteIdbHasDatabase(old) && DateTime.now().isBefore(end)) {
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }
    expect(await sqliteIdbHasDatabase(old), isFalse);
  });
}
