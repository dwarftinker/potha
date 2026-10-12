# Contract: Document format abstraction

Library, import and progress code depend only on these interfaces (Principle III). PDF is
the only implementation in this feature; EPUB adds another without changing callers.
Signatures are illustrative Dart; exact names may change during implementation, but the
behaviour must not.

## DocumentFormat

One per supported file format, registered in a `DocumentFormats` list.

```dart
abstract interface class DocumentFormat {
  /// Stable id stored in books.format, e.g. 'pdf'.
  String get id;

  /// Cheap check on the first bytes (PDF: '%PDF-' within the first 1024 bytes).
  bool sniff(Uint8List header);

  /// Opens a stored or staged file. Calls [askPassword] when the document is
  /// encrypted; returning null means the user cancelled.
  /// Throws DocumentOpenException(kind: damaged | passwordCancelled | unsupported).
  Future<ReaderDocument> open(
    BookFileRef file, {
    String? knownPassword,
    Future<String?> Function({required bool retry})? askPassword,
  });
}
```

## ReaderDocument

```dart
abstract interface class ReaderDocument {
  int get pageCount;

  /// The password that successfully opened the document, or null if none was needed.
  String? get usedPassword;

  /// Best effort; never throws. Blank values are returned as null.
  Future<DocumentMetadata> readMetadata();   // {String? title, String? author}

  /// Renders page [pageNumber] (1-based) to PNG bytes [width] px wide.
  /// Returns null if the page cannot be rendered.
  Future<Uint8List?> renderPagePng(int pageNumber, {required int width});

  Future<void> close();
}
```

Later features add operations here (text at a position, word at a point, search). They
are not part of this feature (Principle VIII).

## Reading view

```dart
abstract interface class DocumentViewFactory {
  /// Builds the page view for an opened document, starting at [initialPage] and
  /// reporting the current page (1-based) through [onPageChanged].
  Widget build(ReaderDocument doc,
      {required int initialPage, required ValueChanged<int> onPageChanged});
}
```

The PDF implementation lives in the deferred reader library (research R10).

## Behaviour required of every format

| Case | Required behaviour |
|---|---|
| Not this format | `sniff` returns false; the import reports `notAPdf` |
| Damaged file | `open` throws `damaged` |
| Encrypted, password cancelled | `open` throws `passwordCancelled` |
| Wrong password | `askPassword(retry: true)` is called again |
| No metadata | `readMetadata` returns `{null, null}` |
| Page cannot render | `renderPagePng` returns null |
