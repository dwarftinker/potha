import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:potha/core/storage/book_file_store.dart';
import 'package:potha/core/storage/book_file_store_io.dart';

Stream<List<int>> chunks(int count, {int size = 1000}) async* {
  for (var i = 0; i < count; i++) {
    yield List.filled(size, i % 256);
    await Future<void>.delayed(Duration.zero);
  }
}

void main() {
  late Directory root;
  late IoBookFileStore store;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('potha_store_test');
    store = IoBookFileStore(root: () async => root);
  });
  tearDown(() => root.delete(recursive: true));

  List<FileSystemEntity> staging() {
    final dir = Directory('${root.path}/staging');
    return dir.existsSync() ? dir.listSync() : [];
  }

  test('stage streams bytes and reports progress', () async {
    final progress = <int>[];
    final staged = await store.stage(chunks(5), totalBytes: 5000, onProgress: progress.add);

    expect(staged.ref.sizeBytes, 5000);
    expect((await staged.ref.readAll()).length, 5000);
    expect(progress.last, 5000);
    expect(staging(), hasLength(1));
  });

  test('cancel deletes the staging file', () async {
    final cancel = Completer<void>();
    final future = store.stage(chunks(1000), cancel: cancel.future);
    await Future<void>.delayed(const Duration(milliseconds: 5));
    cancel.complete();

    await expectLater(future, throwsA(isA<StagingCancelledException>()));
    expect(staging(), isEmpty);
  });

  test('a source error deletes the staging file and is rethrown', () async {
    Stream<List<int>> failing() async* {
      yield [1, 2, 3];
      throw const FormatException('bad');
    }

    await expectLater(store.stage(failing()), throwsA(isA<FormatException>()));
    expect(staging(), isEmpty);
  });

  test('commit moves the file to books/<bookId>.pdf', () async {
    final staged = await store.stage(chunks(2));
    final ref = await store.commit(staged, 'book-1');

    expect(ref.path, '${root.path}/books/book-1.pdf');
    expect(File(ref.path!).lengthSync(), 2000);
    expect(staging(), isEmpty);
    expect((await store.find('book-1'))?.sizeBytes, 2000);
  });

  test('discard and delete remove files', () async {
    final staged = await store.stage(chunks(1));
    await store.discard(staged);
    expect(staging(), isEmpty);

    await store.commit(await store.stage(chunks(1)), 'book-2');
    await store.delete('book-2');
    expect(await store.find('book-2'), isNull);
  });

  test('cleanUp empties staging and removes unknown books', () async {
    await store.commit(await store.stage(chunks(1)), 'keep');
    await store.commit(await store.stage(chunks(1)), 'orphan');
    await store.stage(chunks(1)); // left in staging, as after a crash

    await store.cleanUp({'keep'});

    expect(staging(), isEmpty);
    expect(await store.find('keep'), isNotNull);
    expect(await store.find('orphan'), isNull);
  });
}
