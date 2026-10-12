// Format-agnostic document abstraction (constitution Principle III).
// See specs/001-library-and-import/contracts/reader-document.md.
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import 'reading_position.dart';

export 'reading_position.dart';

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
  Future<ReaderDocument> open(BookFileRef file, {String? knownPassword, AskPassword? askPassword});
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

  /// Page size in points, as displayed. Never throws; a page that can't be read reports
  /// A4.
  Size pageSize(int pageNumber);

  /// The table of contents, or an empty list if there is none. Best effort; never throws.
  Future<List<OutlineEntry>> loadOutline();

  /// Links on a page, with rects normalised to the page (0–1). Best effort.
  Future<List<DocumentLink>> loadLinks(int pageNumber);

  /// Text of a page with one rect per character (normalised 0–1), or null if the page
  /// can't be read. The text is empty for a page without a text layer.
  Future<PageText?> loadPageText(int pageNumber);

  /// Renders a page [width] px wide, or null if it can't be rendered. Completing
  /// [cancel] stops the work.
  Future<ui.Image?> renderPageImage(int pageNumber, {required int width, Future<void>? cancel});

  Future<void> close();
}

/// An entry in a book's table of contents. [page] is null when the entry points
/// nowhere usable.
@immutable
class OutlineEntry {
  const OutlineEntry({required this.title, this.page, this.children = const []});

  final String title;
  final int? page;
  final List<OutlineEntry> children;

  @override
  String toString() => 'OutlineEntry($title, $page, ${children.length} children)';
}

/// A link area on a page; [rect] is normalised to the page (0–1, top-left origin).
@immutable
sealed class DocumentLink {
  const DocumentLink(this.rect);

  final Rect rect;
}

/// A link to another page in the same book.
class PageLink extends DocumentLink {
  const PageLink(super.rect, this.page);

  final int page;

  @override
  String toString() => 'PageLink($page, $rect)';
}

/// A link to a web address.
class WebLink extends DocumentLink {
  const WebLink(super.rect, this.uri);

  final Uri uri;

  @override
  String toString() => 'WebLink($uri, $rect)';
}

/// A page's text. [charRects] has one rect per UTF-16 unit of [text], normalised to the
/// page (0–1, top-left origin); line breaks and spaces may have empty rects.
@immutable
class PageText {
  const PageText(this.text, this.charRects);

  static const empty = PageText('', []);

  final String text;
  final List<Rect> charRects;

  bool get hasText => text.trim().isNotEmpty;
}

/// A point on a page, normalised to the page (0–1, top-left origin).
@immutable
class PagePoint {
  const PagePoint(this.page, this.offset);

  final int page;
  final Offset offset;

  @override
  bool operator ==(Object other) =>
      other is PagePoint && other.page == page && other.offset == offset;

  @override
  int get hashCode => Object.hash(page, offset);

  @override
  String toString() => 'PagePoint($page, $offset)';
}

/// Areas to highlight on a page (search matches), normalised to the page.
@immutable
class PageHighlight {
  const PageHighlight(this.page, this.rects, {this.active = false});

  final int page;
  final List<Rect> rects;

  /// The current match, drawn more strongly.
  final bool active;
}

/// One page at a time, or all pages in one vertical scroll.
enum PageMode { paged, continuous }

/// What the normal (unzoomed) view fits to the screen.
enum PageFit { fitWidth, fitPage }

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

/// Builds the page view for an opened document (002 contracts/reader-document.md).
abstract interface class DocumentViewFactory {
  /// Creates the controller for a view; one per view.
  DocumentViewController createController();

  Widget build(
    ReaderDocument doc, {
    required DocumentViewController controller,
    required ReaderViewConfig config,
  });
}

/// A tap on the page view, reported on pointer up without waiting for a second tap
/// (the reader's tap detector wraps the view; 002 research R3).
@immutable
class ReaderTap {
  const ReaderTap({required this.globalPosition, required this.localPosition, this.pagePoint});

  final Offset globalPosition;

  /// Relative to the view.
  final Offset localPosition;

  /// The page point under the tap, or null between pages.
  final PagePoint? pagePoint;
}

/// How the view shows the document.
@immutable
class ReaderViewConfig {
  const ReaderViewConfig({
    required this.mode,
    required this.fit,
    required this.initialPosition,
    required this.onPositionChanged,
    this.pageFilter,
    this.backgroundColor = const Color(0xFFE0E0E0),
    this.highlights = const [],
    this.highlightColor = const Color(0x66FFD54F),
    this.activeHighlightColor = const Color(0x99FF9800),
  });

  final PageMode mode;
  final PageFit fit;
  final ReadingPosition initialPosition;
  final ValueChanged<ReadingPosition> onPositionChanged;

  /// Recolours the pages for the reading theme; null leaves them as they are.
  final ColorFilter? pageFilter;
  final Color backgroundColor;
  final List<PageHighlight> highlights;

  /// Colours as painted, before [pageFilter] is applied.
  final Color highlightColor;
  final Color activeHighlightColor;

  ReaderViewConfig copyWith({
    PageMode? mode,
    PageFit? fit,
    ColorFilter? pageFilter,
    bool clearPageFilter = false,
    Color? backgroundColor,
    List<PageHighlight>? highlights,
    Color? highlightColor,
    Color? activeHighlightColor,
  }) => ReaderViewConfig(
    mode: mode ?? this.mode,
    fit: fit ?? this.fit,
    initialPosition: initialPosition,
    onPositionChanged: onPositionChanged,
    pageFilter: clearPageFilter ? null : pageFilter ?? this.pageFilter,
    backgroundColor: backgroundColor ?? this.backgroundColor,
    highlights: highlights ?? this.highlights,
    highlightColor: highlightColor ?? this.highlightColor,
    activeHighlightColor: activeHighlightColor ?? this.activeHighlightColor,
  );
}

/// Drives a page view. Methods do nothing until the view is ready.
abstract interface class DocumentViewController implements Listenable {
  bool get isReady;

  ReadingPosition get position;

  /// 1.0 is the normal view (the chosen fit).
  double get zoom;

  Future<void> goTo(ReadingPosition position, {bool animate = true});

  /// Forward one page (paged) or one screen (continuous).
  Future<void> next();

  /// Back one page (paged) or one screen (continuous).
  Future<void> previous();

  /// Scrolls by [fraction] of the view height (continuous mode; arrow keys).
  Future<void> scrollBy(double fraction);

  Future<void> zoomIn();

  Future<void> zoomOut();

  /// The page point under [globalPosition], or null between pages.
  PagePoint? pagePointAt(Offset globalPosition);

  void dispose();
}
