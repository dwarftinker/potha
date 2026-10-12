// Run with: flutter test --platform chrome test/web/
@TestOn('browser')
library;

import 'dart:async';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:potha/core/storage/book_file_store.dart';
import 'package:potha/core/storage/book_file_store_web.dart';
import 'package:web/web.dart' as web;

Stream<List<int>> chunks(int count, {int size = 1000}) async* {
  for (var i = 0; i < count; i++) {
    yield List.filled(size, i % 256);
    await Future<void>.delayed(Duration.zero);
  }
}

/// Wraps a backend so its writer fails with a browser QuotaExceededError.
class QuotaBackend implements WebFileBackend {
  QuotaBackend(this.inner);
  final WebFileBackend inner;

  @override
  Future<WebFileWriter> create(String dir, String name) async =>
      _QuotaWriter(await inner.create(dir, name));
  @override
  Future<web.Blob?> open(String dir, String name) => inner.open(dir, name);
  @override
  Future<void> move(String a, String b, String c, String d) => inner.move(a, b, c, d);
  @override
  Future<void> delete(String dir, String name) => inner.delete(dir, name);
  @override
  Future<List<String>> list(String dir) => inner.list(dir);
}

class _QuotaWriter implements WebFileWriter {
  _QuotaWriter(this.inner);
  final WebFileWriter inner;
  var count = 0;

  @override
  Future<void> write(Uint8List chunk) async {
    if (++count == 2) {
      // Reject a real JS promise, the same way OPFS and IndexedDB report the error.
      final error = web.DOMException('The quota has been exceeded.', 'QuotaExceededError');
      await (globalContext['Promise'] as JSObject)
          .callMethod<JSPromise<JSAny?>>('reject'.toJS, error)
          .toDart;
    }
    await inner.write(chunk);
  }

  @override
  Future<void> close() => inner.close();
  @override
  Future<void> abort() => inner.abort();
}

void runStoreTests(String label, WebFileBackend Function() makeBackend) {
  group(label, () {
    late WebFileBackend backend;
    late WebBookFileStore store;

    setUp(() async {
      backend = makeBackend();
      store = WebBookFileStore(backend);
      await store.cleanUp({});
    });

    test('stage, commit, find and delete', () async {
      final progress = <int>[];
      final staged = await store.stage(chunks(3), onProgress: progress.add);
      expect(staged.ref.sizeBytes, 3000);
      expect(progress.last, 3000);

      final ref = await store.commit(staged, 'book-1');
      expect((await ref.readAll()).length, 3000);
      expect(await backend.list('staging'), isEmpty);
      expect((await store.find('book-1'))?.sizeBytes, 3000);

      await store.delete('book-1');
      expect(await store.find('book-1'), isNull);
    });

    test('cancel deletes the staging file', () async {
      final cancel = Completer<void>();
      final future = store.stage(chunks(1000), cancel: cancel.future);
      await Future<void>.delayed(const Duration(milliseconds: 5));
      cancel.complete();

      await expectLater(future, throwsA(isA<StagingCancelledException>()));
      expect(await backend.list('staging'), isEmpty);
    });

    test('cleanUp empties staging and removes unknown books', () async {
      await store.commit(await store.stage(chunks(1)), 'keep');
      await store.commit(await store.stage(chunks(1)), 'orphan');
      await store.stage(chunks(1));

      await store.cleanUp({'keep'});

      expect(await backend.list('staging'), isEmpty);
      expect(await store.find('keep'), isNotNull);
      expect(await store.find('orphan'), isNull);
    });

    test('QuotaExceededError becomes StorageFullException and leaves nothing', () async {
      final quotaStore = WebBookFileStore(QuotaBackend(backend));
      await expectLater(quotaStore.stage(chunks(5)), throwsA(isA<StorageFullException>()));
      expect(await backend.list('staging'), isEmpty);
    });
  });
}

void main() {
  test('OPFS is available in the test browser', () {
    expect(OpfsBackend.isSupported, isTrue);
  });

  runStoreTests('OPFS', OpfsBackend.new);
  runStoreTests('IndexedDB fallback',
      () => IndexedDbBackend(databaseName: 'potha_files_test'));
}
