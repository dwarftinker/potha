# Contract: Book storage and import

## BookFileStore

Platform-specific (Principle I). One IO implementation (Android, iOS) and one web
implementation (OPFS, IndexedDB fallback), selected by conditional import.

```dart
abstract interface class BookFileStore {
  /// Streams [source] into a new staging file. Calls [onProgress] with bytes written.
  /// Stops and deletes the staging file when [cancel] completes.
  /// Throws StorageFullException when the device or browser runs out of space.
  Future<StagedFile> stage(Stream<List<int>> source,
      {required int? totalBytes,
      void Function(int written)? onProgress,
      Future<void>? cancel});

  /// Moves a staged file to its permanent name for [bookId].
  Future<BookFileRef> commit(StagedFile staged, String bookId);

  Future<void> discard(StagedFile staged);
  Future<BookFileRef?> find(String bookId);
  Future<void> delete(String bookId);

  /// Removes all staging files and every stored file whose id is not in [knownBookIds].
  Future<void> cleanUp(Set<String> knownBookIds);

  /// Web only: asks the browser to keep this site's storage. No-op elsewhere.
  Future<void> requestPersistence();
}
```

## ImportService

```dart
abstract interface class ImportService {
  /// Imports [files] one after another. A failure in one does not stop the rest.
  /// Emits progress events; the final event carries one ImportResult per file.
  Stream<ImportEvent> importFiles(List<ImportSource> files);

  /// Cancels the file currently being imported and skips the rest of the batch.
  void cancel();
}
```

`ImportSource` = `{String name, int? size, Stream<List<int>> Function() openRead}`. The
file picker, Open with / Share to, and drag and drop all produce `ImportSource`s.

### Events

| Event | When | UI |
|---|---|---|
| `started(index, total, fileName)` | each file begins | nothing yet |
| `progress(fraction?)` | while copying | progress bar and Cancel button, shown only after 1 s (FR-008) |
| `needsPassword(fileName, retry)` | encrypted PDF | password dialog |
| `finished(results)` | batch done | single file: open or snackbar; several files: summary (FR-009) |

### Rules

1. Web: reject files over 100 MB (104,857,600 bytes) before staging, as
   `tooLargeForWeb` (FR-008a). If the size is unknown, stop when the limit is passed.
2. Reject with `notAPdf` when the header sniff fails, before inspecting further.
3. If the hash matches an existing book, discard the staged file and report
   `alreadyInLibrary(bookId)`. The UI offers "Open" (FR-007).
4. Commit = one database transaction (books + book_covers), then
   `BookFileStore.commit`, then save the password if one was used (FR-028). If the file
   move fails, the transaction is rolled back.
5. Any failure or cancel → `discard`, and nothing is written to the database.

## LibraryRepository

```dart
abstract interface class LibraryRepository {
  Stream<List<BookSummary>> watchBooks({required SortOrder sort, String query = ''});
  Future<Uint8List?> cover(String bookId);
  Future<Book?> findByHash(String contentHash);
  Future<void> markOpened(String bookId);
  Future<void> saveProgress(String bookId, int currentPage);
  Future<int?> currentPage(String bookId);
  Future<void> remove(String bookId);          // row, cover, progress, file, password
  Stream<LibraryPreferences> watchPreferences();
  Future<void> updatePreferences(LibraryPreferences prefs);
}
```

`BookSummary` = `{id, title, author?, progressLabel ('New' | 'NN%'), hasCover}`. No image
bytes, so a 500-book list stays light (SC-003).
