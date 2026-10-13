// Web only. Writes a database file straight into IndexedDB in the layout of sqlite3's
// IndexedDbFileSystem, which drift's IndexedDB storage reads (sqlite3 3.5.x, drift 2.35;
// research R2). The dictionary is streamed in 4 KiB blocks, a batch per transaction, so
// the page never holds the whole file: drift's own initializeDatabase path keeps several
// full copies in memory at once (712 MB peak on the S24, T082).
//
// The layout, per IndexedDB database (named after the drift database):
// - store `files`: `{name, length}` values, auto-increment keys, unique index `fileName`
//   on `name`;
// - store `blocks`: 4096-byte ArrayBuffers keyed `[fileId, offset]`; the last block is
//   padded, the file's `length` says where it ends.
// The file entry is written last, so an interrupted write leaves no file behind.
import 'dart:async';
import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

/// Where drift's IndexedDB storage keeps the database in each file system.
const sqliteDatabasePath = '/database';

const _filesStore = 'files';
const _blocksStore = 'blocks';
const _fileNameIndex = 'fileName';
const _blockSize = 4096;
const _fileId = 1;

/// Whether IndexedDB database [dbName] holds a complete database file.
Future<bool> sqliteIdbHasDatabase(String dbName) async {
  final idb = web.window.indexedDB;
  final names = (await idb.databases().toDart).toDart.map((d) => d.name);
  if (!names.contains(dbName)) return false;
  final db = await _open(dbName);
  try {
    final tx = db.transaction(_filesStore.toJS, 'readonly');
    final entry = await _request(
      tx.objectStore(_filesStore).index(_fileNameIndex).get(sqliteDatabasePath.toJS),
    );
    final length = (entry.dartify() as Map?)?['length'] as num?;
    return (length ?? 0) > 0;
  } finally {
    db.close();
  }
}

/// Deletes IndexedDB database [dbName], if it exists.
Future<void> sqliteIdbDelete(String dbName) async {
  final request = web.window.indexedDB.deleteDatabase(dbName);
  final done = _request(request);
  // Blocked only while another connection is open; it goes ahead once that closes.
  request.onblocked = (web.Event _) {}.toJS;
  await done;
}

/// Writes [data] (the database file's bytes) as the database of IndexedDB database
/// [dbName], which must not exist yet. Holds at most [batchBytes] plus the stream's
/// current chunk. Returns the file's length.
Future<int> sqliteIdbWrite(
  String dbName,
  web.ReadableStream data, {
  int batchBytes = 1 << 20,
}) async {
  assert(batchBytes % _blockSize == 0);
  final db = await _open(dbName);
  try {
    final reader = data.getReader() as web.ReadableStreamDefaultReader;
    final batch = Uint8List(batchBytes);
    var filled = 0; // bytes in batch
    var written = 0; // bytes in earlier batches

    Future<void> flush() async {
      if (filled == 0) return;
      final tx = db.transaction(_blocksStore.toJS, 'readwrite');
      final blocks = tx.objectStore(_blocksStore);
      for (var at = 0; at < filled; at += _blockSize) {
        // A fresh, full-size block (sqlite3 reads ArrayBuffers of 4096 bytes).
        final block = Uint8List(_blockSize)
          ..setRange(0, (filled - at).clamp(0, _blockSize), batch, at);
        blocks.put(block.buffer.toJS, [_fileId.toJS, (written + at).toJS].toJS);
      }
      await _complete(tx);
      written += filled;
      filled = 0;
    }

    while (true) {
      final result = await reader.read().toDart;
      if (result.done) break;
      final chunk = (result.value as JSUint8Array).toDart;
      var from = 0;
      while (from < chunk.length) {
        final n = (chunk.length - from).clamp(0, batchBytes - filled);
        batch.setRange(filled, filled + n, chunk, from);
        filled += n;
        from += n;
        if (filled == batchBytes) await flush();
      }
    }
    await flush();

    final tx = db.transaction(_filesStore.toJS, 'readwrite');
    tx
        .objectStore(_filesStore)
        .put({'name': sqliteDatabasePath, 'length': written}.jsify(), _fileId.toJS);
    await _complete(tx);
    return written;
  } finally {
    db.close();
  }
}

/// Opens (or creates, with sqlite3's schema) IndexedDB database [dbName].
Future<web.IDBDatabase> _open(String dbName) {
  final request = web.window.indexedDB.open(dbName, 1);
  request.onupgradeneeded = (web.IDBVersionChangeEvent change) {
    final db = request.result as web.IDBDatabase;
    if (change.oldVersion == 0) {
      db
          .createObjectStore(_filesStore, web.IDBObjectStoreParameters(autoIncrement: true))
          .createIndex(_fileNameIndex, 'name'.toJS, web.IDBIndexParameters(unique: true));
      db.createObjectStore(_blocksStore);
    }
  }.toJS;
  return _request(request).then((db) => db as web.IDBDatabase);
}

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

Future<void> _complete(web.IDBTransaction tx) {
  final done = Completer<void>();
  tx.oncomplete = (web.Event _) {
    done.complete();
  }.toJS;
  tx.onerror = (web.Event _) {
    if (!done.isCompleted) done.completeError(StateError('IndexedDB: ${tx.error?.message}'));
  }.toJS;
  tx.onabort = (web.Event _) {
    if (!done.isCompleted) done.completeError(StateError('IndexedDB: transaction aborted'));
  }.toJS;
  return done.future;
}
