// Format-agnostic document abstraction (constitution Principle III).
// See specs/001-library-and-import/contracts/reader-document.md.
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

/// A readable handle to a stored or staged book file.
///
/// On Android and iOS [path] is set; on the web the bytes come from browser storage.
class BookFileRef {
  const BookFileRef({this.path, required this.readAll, required this.sizeBytes});

  final String? path;
  final Future<Uint8List> Function() readAll;
  final int sizeBytes;
}

/// Asks the user for a document password. Returns null if they cancel.
typedef AskPassword = Future<String?> Function({required bool retry});

abstract interface class DocumentFormat {
  /// Stable id stored in books.format, e.g. 'pdf'.
  String get id;

  /// Cheap check on the first bytes of a file.
  bool sniff(Uint8List header);

  /// Opens [file]. Tries [knownPassword] first, then [askPassword] if the document is
  /// encrypted. Throws [DocumentOpenException].
  Future<ReaderDocument> open(
    BookFileRef file, {
    String? knownPassword,
    AskPassword? askPassword,
  });
}

abstract interface class ReaderDocument {
  int get pageCount;

  /// The password that opened the document, or null if none was needed.
  String? get usedPassword;

  /// Best effort; never throws. Blank values are returned as null.
  Future<DocumentMetadata> readMetadata();

  /// PNG bytes of page [pageNumber] (1-based), [width] px wide, or null if it can't be
  /// rendered.
  Future<Uint8List?> renderPagePng(int pageNumber, {required int width});

  Future<void> close();
}

@immutable
class DocumentMetadata {
  const DocumentMetadata({this.title, this.author});

  static const empty = DocumentMetadata();

  final String? title;
  final String? author;

  @override
  bool operator ==(Object other) =>
      other is DocumentMetadata && other.title == title && other.author == author;

  @override
  int get hashCode => Object.hash(title, author);

  @override
  String toString() => 'DocumentMetadata(title: $title, author: $author)';
}

enum DocumentOpenFailure { damaged, passwordCancelled, unsupported }

class DocumentOpenException implements Exception {
  const DocumentOpenException(this.kind, [this.cause]);

  final DocumentOpenFailure kind;
  final Object? cause;

  @override
  String toString() => 'DocumentOpenException($kind, $cause)';
}

/// Builds the page view for an opened document.
abstract interface class DocumentViewFactory {
  Widget build(
    ReaderDocument doc, {
    required int initialPage,
    required ValueChanged<int> onPageChanged,
  });
}
