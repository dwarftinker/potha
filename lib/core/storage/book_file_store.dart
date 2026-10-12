// Where the app keeps its own copy of each book (FR-004).
// See specs/001-library-and-import/contracts/storage-and-import.md and research R3.
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../document/document_format.dart';
import 'book_file_store_io.dart'
    if (dart.library.js_interop) 'book_file_store_web.dart' as platform;

export '../document/document_format.dart' show BookFileRef;

/// A file copied into staging but not yet part of the library.
class StagedFile {
  const StagedFile({required this.id, required this.ref});

  final String id;
  final BookFileRef ref;
}

/// The device or browser ran out of space.
class StorageFullException implements Exception {
  const StorageFullException([this.cause]);
  final Object? cause;

  @override
  String toString() => 'StorageFullException($cause)';
}

/// Staging stopped because the caller cancelled it.
class StagingCancelledException implements Exception {
  const StagingCancelledException();
}

abstract interface class BookFileStore {
  /// Streams [source] into a new staging file, calling [onProgress] with the bytes
  /// written so far. If [cancel] completes, or [source] emits an error, the staging file
  /// is deleted and the error ([StagingCancelledException] for a cancel) is rethrown.
  /// Throws [StorageFullException] when out of space.
  Future<StagedFile> stage(
    Stream<List<int>> source, {
    int? totalBytes,
    void Function(int written)? onProgress,
    Future<void>? cancel,
  });

  /// Moves a staged file to its permanent name for [bookId].
  Future<BookFileRef> commit(StagedFile staged, String bookId);

  Future<void> discard(StagedFile staged);

  Future<BookFileRef?> find(String bookId);

  Future<void> delete(String bookId);

  /// Removes all staging files and every stored book whose id is not in [knownBookIds].
  Future<void> cleanUp(Set<String> knownBookIds);

  /// Web only: asks the browser to keep this site's storage. No-op elsewhere.
  Future<void> requestPersistence();
}

final bookFileStoreProvider =
    Provider<BookFileStore>((ref) => platform.createBookFileStore());
