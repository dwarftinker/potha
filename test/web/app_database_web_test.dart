// The app database on IndexedDB keeps its schema version without being closed: a reload
// right after the first visit must not run onCreate again. drift 2.35 writes IndexedDB
// only after statements, and sets the version last without one; AppDatabase's beforeOpen
// writes it itself.
//
// Run with: flutter test --platform chrome test/web
// test/web/sqlite3.wasm and drift_worker.js are symlinks to web/ so drift can load here.
@TestOn('browser')
library;

import 'dart:async';
import 'dart:js_interop';
import 'dart:math';
import 'dart:typed_data';

import 'package:drift/wasm.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:potha/core/db/app_database.dart';
import 'package:web/web.dart' as web;

void main() {
  String freshName() => 'potha-test-${Random().nextInt(1 << 30)}';

  Future<AppDatabase?> open(String name, WasmStorageImplementation storage) async {
    final probe = await WasmDatabase.probe(
      sqlite3Uri: Uri.parse('sqlite3.wasm'),
      driftWorkerUri: Uri.parse('drift_worker.js'),
      databaseName: name,
    );
    if (!probe.availableStorages.contains(storage)) return null;
    final result = await probe.open(storage, name);
    return AppDatabase(result.executor);
  }

  for (final storage in [
    WasmStorageImplementation.sharedIndexedDb,
    WasmStorageImplementation.unsafeIndexedDb,
  ]) {
    test('${storage.name}: the saved file has the schema version once opened', () async {
      final name = freshName();
      final db = await open(name, storage);
      if (db == null) return markTestSkipped('${storage.name} not available here');
      addTearDown(() => _deleteIdb(name));
      addTearDown(db.close);

      await db.customSelect('SELECT 1').get(); // opens and creates the schema

      // Not closed: closing would save everything and hide the problem.
      expect(await _savedUserVersion(name), db.schemaVersion);
    });
  }

  test('a second connection (a reload) opens the database the first one created', () async {
    const storage = WasmStorageImplementation.unsafeIndexedDb;
    final name = freshName();
    final first = await open(name, storage);
    if (first == null) return markTestSkipped('unsafeIndexedDb not available here');
    addTearDown(() => _deleteIdb(name));
    addTearDown(first.close);
    await first.customSelect('SELECT 1').get();

    // unsafeIndexedDb loads the saved file into a separate copy, like a reloaded page.
    final second = (await open(name, storage))!;
    addTearDown(second.close);
    final rows = await second.customSelect('SELECT count(*) AS n FROM library_preferences').get();
    expect(rows.single.read<int>('n'), 1);
  });
}

/// `user_version` from the header of the database file saved in IndexedDB [dbName]
/// (sqlite3's IndexedDbFileSystem layout; see lib/core/dictionary/sqlite_idb_writer.dart).
Future<int> _savedUserVersion(String dbName) async {
  final db = (await _request(web.window.indexedDB.open(dbName))) as web.IDBDatabase;
  try {
    final tx = db.transaction(['files'.toJS, 'blocks'.toJS].toJS);
    final fileId = await _request(
      tx.objectStore('files').index('fileName').getKey('/database'.toJS),
    );
    final block = await _request(tx.objectStore('blocks').get([fileId, 0.toJS].toJS));
    final header = (block as JSArrayBuffer).toDart.asUint8List();
    return ByteData.sublistView(header).getUint32(60);
  } finally {
    db.close();
  }
}

Future<void> _deleteIdb(String dbName) => _request(web.window.indexedDB.deleteDatabase(dbName));

Future<JSAny?> _request(web.IDBRequest request) {
  final done = Completer<JSAny?>();
  request.onsuccess = (web.Event _) {
    done.complete(request.result);
  }.toJS;
  request.onerror = (web.Event _) {
    done.completeError(StateError('IndexedDB: ${request.error?.message}'));
  }.toJS;
  return done.future;
}
