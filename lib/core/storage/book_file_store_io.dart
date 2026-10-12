// Android and iOS: books live under the app support directory (research R3), which is
// private to the app and not shown in the iOS Files app.
import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:path_provider/path_provider.dart';

import 'book_file_store.dart';

BookFileStore createBookFileStore() =>
    IoBookFileStore(root: getApplicationSupportDirectory);

/// errno for "No space left on device" on Linux, Android and Darwin.
const _enospcCodes = {28};

class IoBookFileStore implements BookFileStore {
  // ignore: prefer_initializing_formals (named parameters can't be private)
  IoBookFileStore({required Future<Directory> Function() root}) : _root = root;

  final Future<Directory> Function() _root;
  final _random = Random();

  Future<Directory> _dir(String name) async {
    final dir = Directory('${(await _root()).path}/$name');
    if (!dir.existsSync()) await dir.create(recursive: true);
    return dir;
  }

  Future<File> _bookFile(String bookId) async =>
      File('${(await _dir('books')).path}/$bookId.pdf');

  BookFileRef _ref(File file) => BookFileRef(
        path: file.path,
        readAll: file.readAsBytes,
        sizeBytes: file.lengthSync(),
      );

  @override
  Future<StagedFile> stage(
    Stream<List<int>> source, {
    int? totalBytes,
    void Function(int written)? onProgress,
    Future<void>? cancel,
  }) async {
    final id = '${DateTime.now().microsecondsSinceEpoch}-${_random.nextInt(0x7fffffff)}';
    final file = File('${(await _dir('staging')).path}/$id.pdf');
    final sink = file.openWrite();
    final done = Completer<void>();
    var written = 0;
    late final StreamSubscription<List<int>> sub;

    Future<void> fail(Object error, [StackTrace? stack]) async {
      if (done.isCompleted) return;
      done.completeError(error, stack);
      await sub.cancel();
    }

    sub = source.listen(
      (chunk) {
        sink.add(chunk);
        written += chunk.length;
        onProgress?.call(written);
      },
      onError: fail,
      onDone: () {
        if (!done.isCompleted) done.complete();
      },
      cancelOnError: true,
    );
    cancel?.then((_) => fail(const StagingCancelledException()));

    try {
      await done.future;
      await sink.flush();
      await sink.close();
    } catch (error) {
      await _closeQuietly(sink);
      await _deleteQuietly(file);
      if (error is FileSystemException && _isStorageFull(error)) {
        throw StorageFullException(error);
      }
      rethrow;
    }
    return StagedFile(id: id, ref: _ref(file));
  }

  @override
  Future<BookFileRef> commit(StagedFile staged, String bookId) async {
    final target = await _bookFile(bookId);
    final moved = await File(staged.ref.path!).rename(target.path);
    return _ref(moved);
  }

  @override
  Future<void> discard(StagedFile staged) => _deleteQuietly(File(staged.ref.path!));

  @override
  Future<BookFileRef?> find(String bookId) async {
    final file = await _bookFile(bookId);
    return file.existsSync() ? _ref(file) : null;
  }

  @override
  Future<void> delete(String bookId) async => _deleteQuietly(await _bookFile(bookId));

  @override
  Future<void> cleanUp(Set<String> knownBookIds) async {
    await for (final entity in (await _dir('staging')).list()) {
      await entity.delete(recursive: true);
    }
    await for (final entity in (await _dir('books')).list()) {
      final name = entity.uri.pathSegments.last;
      final id = name.endsWith('.pdf') ? name.substring(0, name.length - 4) : name;
      if (!knownBookIds.contains(id)) await entity.delete(recursive: true);
    }
  }

  @override
  Future<void> requestPersistence() async {}

  static bool _isStorageFull(FileSystemException e) =>
      _enospcCodes.contains(e.osError?.errorCode);

  static Future<void> _closeQuietly(IOSink sink) async {
    try {
      await sink.close();
    } catch (_) {}
  }

  static Future<void> _deleteQuietly(File file) async {
    try {
      if (file.existsSync()) await file.delete();
    } catch (_) {}
  }
}
