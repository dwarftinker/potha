// Web: books live in the Origin Private File System (OPFS), or in IndexedDB as Blobs
// when OPFS writing is unavailable (research R3). Requires a secure context.
import 'dart:async';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'dart:math';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

import 'book_file_store.dart';

BookFileStore createBookFileStore() => WebBookFileStore(
      OpfsBackend.isSupported ? OpfsBackend() : IndexedDbBackend(),
    );

/// Minimal file operations the web store needs from a browser storage API.
abstract interface class WebFileBackend {
  Future<WebFileWriter> create(String dir, String name);

  /// The stored file as a Blob, or null if it does not exist.
  Future<web.Blob?> open(String dir, String name);

  Future<void> move(String fromDir, String fromName, String toDir, String toName);

  Future<void> delete(String dir, String name);

  Future<List<String>> list(String dir);
}

abstract interface class WebFileWriter {
  Future<void> write(Uint8List chunk);
  Future<void> close();
  Future<void> abort();
}

/// True if [error] is the browser's "out of storage" error.
bool isQuotaExceeded(Object error) {
  if (error is StorageFullException) return true;
  final text = error.toString();
  if (text.contains('QuotaExceededError')) return true;
  try {
    final name = (error as JSObject).getProperty<JSAny?>('name'.toJS);
    return name.isA<JSString>() && (name as JSString).toDart == 'QuotaExceededError';
  } catch (_) {
    return false;
  }
}

class WebBookFileStore implements BookFileStore {
  WebBookFileStore(this._backend);

  final WebFileBackend _backend;
  final _random = Random();

  static const _staging = 'staging';
  static const _books = 'books';

  BookFileRef _ref(web.Blob blob) => BookFileRef(
        readAll: () async => (await blob.arrayBuffer().toDart).toDart.asUint8List(),
        sizeBytes: blob.size,
      );

  @override
  Future<StagedFile> stage(
    Stream<List<int>> source, {
    int? totalBytes,
    void Function(int written)? onProgress,
    Future<void>? cancel,
  }) async {
    final id = '${DateTime.now().microsecondsSinceEpoch}-${_random.nextInt(0x7fffffff)}';
    final name = '$id.pdf';
    WebFileWriter? writer;
    var written = 0;
    try {
      writer = await _backend.create(_staging, name);
      await for (final chunk in _untilCancelled(source, cancel)) {
        await writer.write(chunk is Uint8List ? chunk : Uint8List.fromList(chunk));
        written += chunk.length;
        onProgress?.call(written);
      }
      await writer.close();
    } catch (error) {
      try {
        await writer?.abort();
      } catch (_) {}
      try {
        await _backend.delete(_staging, name);
      } catch (_) {}
      if (isQuotaExceeded(error)) throw StorageFullException(error);
      rethrow;
    }
    final blob = await _backend.open(_staging, name);
    return StagedFile(id: id, ref: _ref(blob!));
  }

  @override
  Future<BookFileRef> commit(StagedFile staged, String bookId) async {
    await _backend.move(_staging, '${staged.id}.pdf', _books, '$bookId.pdf');
    return _ref((await _backend.open(_books, '$bookId.pdf'))!);
  }

  @override
  Future<void> discard(StagedFile staged) => _backend.delete(_staging, '${staged.id}.pdf');

  @override
  Future<BookFileRef?> find(String bookId) async {
    final blob = await _backend.open(_books, '$bookId.pdf');
    return blob == null ? null : _ref(blob);
  }

  @override
  Future<void> delete(String bookId) => _backend.delete(_books, '$bookId.pdf');

  @override
  Future<void> cleanUp(Set<String> knownBookIds) async {
    for (final name in await _backend.list(_staging)) {
      await _backend.delete(_staging, name);
    }
    for (final name in await _backend.list(_books)) {
      final id = name.endsWith('.pdf') ? name.substring(0, name.length - 4) : name;
      if (!knownBookIds.contains(id)) await _backend.delete(_books, name);
    }
  }

  @override
  Future<void> requestPersistence() async {
    try {
      await web.window.navigator.storage.persist().toDart;
    } catch (_) {
      // Not supported or refused; books still work, they may just be evicted.
    }
  }

  static Stream<List<int>> _untilCancelled(Stream<List<int>> source, Future<void>? cancel) {
    if (cancel == null) return source;
    StreamSubscription<List<int>>? sub;
    late final StreamController<List<int>> controller;
    controller = StreamController<List<int>>(
      onListen: () {
        sub = source.listen(controller.add,
            onError: controller.addError, onDone: controller.close);
        cancel.then((_) {
          if (controller.isClosed) return;
          sub?.cancel();
          controller.addError(const StagingCancelledException());
          controller.close();
        });
      },
      onPause: () => sub?.pause(),
      onResume: () => sub?.resume(),
      onCancel: () => sub?.cancel(),
    );
    return controller.stream;
  }
}

// ---------------------------------------------------------------------------
// OPFS

extension on web.FileSystemDirectoryHandle {
  /// Async iterator over entry names (not yet in package:web).
  external JSObject keys();
}

extension on web.FileSystemFileHandle {
  /// FileSystemHandle.move(), where supported.
  @JS('move')
  external JSPromise<JSAny?> moveTo(web.FileSystemDirectoryHandle dir, JSString name);
}

class OpfsBackend implements WebFileBackend {
  /// OPFS with writable streams is available (not in older Safari).
  static bool get isSupported {
    final handle = globalContext.getProperty<JSAny?>('FileSystemFileHandle'.toJS);
    if (handle == null || !handle.isA<JSObject>()) return false;
    final proto = (handle as JSObject).getProperty<JSAny?>('prototype'.toJS);
    final storage = web.window.navigator.getProperty<JSAny?>('storage'.toJS);
    return proto != null &&
        (proto as JSObject).has('createWritable') &&
        storage != null &&
        (storage as JSObject).has('getDirectory');
  }

  Future<web.FileSystemDirectoryHandle> _dir(String name) async {
    final root = await web.window.navigator.storage.getDirectory().toDart;
    return root
        .getDirectoryHandle(name, web.FileSystemGetDirectoryOptions(create: true))
        .toDart;
  }

  Future<web.FileSystemFileHandle?> _file(String dir, String name) async {
    try {
      return await (await _dir(dir)).getFileHandle(name).toDart;
    } catch (_) {
      return null; // NotFoundError
    }
  }

  @override
  Future<WebFileWriter> create(String dir, String name) async {
    final handle = await (await _dir(dir))
        .getFileHandle(name, web.FileSystemGetFileOptions(create: true))
        .toDart;
    return _OpfsWriter(await handle.createWritable().toDart);
  }

  @override
  Future<web.Blob?> open(String dir, String name) async {
    final handle = await _file(dir, name);
    return handle == null ? null : await handle.getFile().toDart;
  }

  @override
  Future<void> move(String fromDir, String fromName, String toDir, String toName) async {
    final source = await _file(fromDir, fromName);
    if (source == null) throw StateError('Missing $fromDir/$fromName');
    final target = await _dir(toDir);
    if ((source as JSObject).has('move')) {
      await source.moveTo(target, toName.toJS).toDart;
      return;
    }
    // Fallback: copy, then delete the original.
    final file = await source.getFile().toDart;
    final copy = await target
        .getFileHandle(toName, web.FileSystemGetFileOptions(create: true))
        .toDart;
    await file.stream().pipeTo(await copy.createWritable().toDart).toDart;
    await delete(fromDir, fromName);
  }

  @override
  Future<void> delete(String dir, String name) async {
    try {
      await (await _dir(dir)).removeEntry(name).toDart;
    } catch (_) {
      // Already gone.
    }
  }

  @override
  Future<List<String>> list(String dir) async {
    final iterator = (await _dir(dir)).keys();
    final names = <String>[];
    while (true) {
      final next = await iterator.callMethod<JSPromise<JSObject>>('next'.toJS).toDart;
      if ((next.getProperty<JSBoolean>('done'.toJS)).toDart) break;
      names.add(next.getProperty<JSString>('value'.toJS).toDart);
    }
    return names;
  }
}

class _OpfsWriter implements WebFileWriter {
  _OpfsWriter(this._stream);

  final web.FileSystemWritableFileStream _stream;

  @override
  Future<void> write(Uint8List chunk) => _stream.write(chunk.toJS).toDart;

  @override
  Future<void> close() => _stream.close().toDart;

  @override
  Future<void> abort() => _stream.abort().toDart;
}

// ---------------------------------------------------------------------------
// IndexedDB fallback

Future<T> _request<T extends JSAny?>(web.IDBRequest request) {
  final completer = Completer<T>();
  request.onsuccess = ((web.Event _) => completer.complete(request.result as T)).toJS;
  request.onerror = ((web.Event _) => completer.completeError(
      request.error ?? StateError('IndexedDB request failed'))).toJS;
  return completer.future;
}

Future<void> _transactionDone(web.IDBTransaction tx) {
  final completer = Completer<void>();
  tx.oncomplete = ((web.Event _) => completer.complete()).toJS;
  tx.onerror = ((web.Event _) =>
      completer.completeError(tx.error ?? StateError('IndexedDB transaction failed'))).toJS;
  tx.onabort = ((web.Event _) =>
      completer.completeError(tx.error ?? StateError('IndexedDB transaction aborted'))).toJS;
  return completer.future;
}

class IndexedDbBackend implements WebFileBackend {
  IndexedDbBackend({this.databaseName = 'potha_files'});

  final String databaseName;
  static const _store = 'files';
  web.IDBDatabase? _db;

  Future<web.IDBDatabase> _open() async {
    if (_db != null) return _db!;
    final request = web.window.indexedDB.open(databaseName, 1);
    request.onupgradeneeded = ((web.Event _) {
      (request.result as web.IDBDatabase).createObjectStore(_store);
    }).toJS;
    return _db = await _request<web.IDBDatabase>(request);
  }

  Future<web.IDBObjectStore> _objects(String mode) async =>
      (await _open()).transaction(_store.toJS, mode).objectStore(_store);

  static String _key(String dir, String name) => '$dir/$name';

  @override
  Future<WebFileWriter> create(String dir, String name) async =>
      _IdbWriter(this, _key(dir, name));

  Future<void> _put(String key, web.Blob blob) async {
    final store = await _objects('readwrite');
    await _request<JSAny?>(store.put(blob, key.toJS));
    await _transactionDone(store.transaction);
  }

  @override
  Future<web.Blob?> open(String dir, String name) async {
    final store = await _objects('readonly');
    final result = await _request<JSAny?>(store.get(_key(dir, name).toJS));
    return result == null ? null : result as web.Blob;
  }

  @override
  Future<void> move(String fromDir, String fromName, String toDir, String toName) async {
    final blob = await open(fromDir, fromName);
    if (blob == null) throw StateError('Missing $fromDir/$fromName');
    await _put(_key(toDir, toName), blob);
    await delete(fromDir, fromName);
  }

  @override
  Future<void> delete(String dir, String name) async {
    final store = await _objects('readwrite');
    await _request<JSAny?>(store.delete(_key(dir, name).toJS));
    await _transactionDone(store.transaction);
  }

  @override
  Future<List<String>> list(String dir) async {
    final store = await _objects('readonly');
    final keys = await _request<JSArray<JSAny?>>(store.getAllKeys());
    final prefix = '$dir/';
    return [
      for (final key in keys.toDart)
        if (key.isA<JSString>() && (key as JSString).toDart.startsWith(prefix))
          key.toDart.substring(prefix.length),
    ];
  }
}

class _IdbWriter implements WebFileWriter {
  _IdbWriter(this._backend, this._key);

  final IndexedDbBackend _backend;
  final String _key;
  final _parts = <JSUint8Array>[];

  @override
  Future<void> write(Uint8List chunk) async => _parts.add(chunk.toJS);

  @override
  Future<void> close() => _backend._put(_key, web.Blob(_parts.toJS));

  @override
  Future<void> abort() async => _parts.clear();
}
