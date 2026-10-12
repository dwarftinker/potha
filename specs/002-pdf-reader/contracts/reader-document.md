# Contract: Document abstraction for the reader

This extends 001's `contracts/reader-document.md`. The reader screen, search, contents,
thumbnails, jump-back and progress depend only on these interfaces (Principle III). The
PDF implementation uses pdfrx; EPUB (006) will add its own. Signatures are illustrative
Dart; names may change during implementation, but the behaviour must not.

## ReaderDocument (additions)

```dart
abstract interface class ReaderDocument {
  // From 001: pageCount, usedPassword, readMetadata(), renderPagePng(), close().

  /// Page size in points (unrotated as displayed). Used for layout maths and
  /// thumbnail aspect ratios. Never throws; damaged pages report a default A4 size.
  Size pageSize(int pageNumber);

  /// The table of contents, or an empty list if the book has none (FR-024).
  /// Best effort; never throws.
  Future<List<OutlineEntry>> loadOutline();

  /// Links on a page, with rects normalised to the page (0–1). Best effort.
  Future<List<DocumentLink>> loadLinks(int pageNumber);

  /// Text of a page with one rect per character (normalised 0–1), or null if the
  /// page cannot be read. Text is '' for pages without a text layer. 003 builds
  /// word-at-a-point on this.
  Future<PageText?> loadPageText(int pageNumber);

  /// Renders a page to an image [width] px wide for thumbnails (FR-035). Returns null
  /// if the page cannot be rendered. Cancelling [cancel] stops the work.
  Future<ui.Image?> renderPageImage(int pageNumber,
      {required int width, Future<void>? cancel});
}
```

Rules:
- Page numbers are 1-based everywhere.
- None of these may block the UI thread for more than a frame; PDFium work runs on
  pdfrx's background worker (native isolate or web worker).
- `loadPageText` and `loadLinks` results are cached per page by the caller, not here.

## Reading view

```dart
abstract interface class DocumentViewFactory {
  Widget build(ReaderDocument doc, {
    required DocumentViewController controller,
    required ReaderViewConfig config,
  });
}

class ReaderViewConfig {
  final PageMode mode;                 // paged | continuous
  final PageFit fit;                   // fitWidth | fitPage
  final ReadingPosition initialPosition;
  final ColorFilter? pageFilter;       // theme recolouring (research R5), null = light
  final List<PageHighlight> highlights; // search matches: page + normalised rects
  final ValueChanged<ReadingPosition> onPositionChanged;
  final ValueChanged<ReaderTap> onTap;  // instant taps (research R3)
}

abstract interface class DocumentViewController {
  ReadingPosition get position;
  double get zoom;                       // 1.0 = the normal view (fit)
  Future<void> goTo(ReadingPosition position, {bool animate = true});
  Future<void> next();                   // FR-007: a page (paged) or a screen (continuous)
  Future<void> previous();
  Future<void> zoomIn();                 // FR-016: around the centre of the view
  Future<void> zoomOut();
  /// Converts a global point to a page and a normalised point on it, or null if the
  /// point is between pages. Used for link hit-tests now and words in 003.
  PagePoint? pagePointAt(Offset globalPosition);
}

class ReaderTap {
  final Offset globalPosition;
  final PagePoint? pagePoint;
}
```

Behaviour the PDF implementation must guarantee:

| # | Behaviour | Spec |
|---|---|---|
| 1 | `onTap` fires on pointer up with no wait for a second tap; pdfrx tap handling (including links) is disabled | FR-017, R3 |
| 2 | `next` / `previous` in paged mode turn exactly one page and show the new page from its top-left corner, at the same relative zoom; at the first and last page they do nothing | FR-007, FR-010, FR-021 |
| 3 | `next` / `previous` in continuous mode scroll one view height, less one line of overlap (about 1/24 of the view height) | FR-007 |
| 4 | Changing `mode` or `fit` and resizing or rotating keep `position` | FR-015 |
| 5 | `onPositionChanged` fires when the position changes by at least 1% of a page or the page changes, and not more than once a frame | FR-011 |
| 6 | Pages that fail to render show a placeholder ("This page can't be shown") and do not stop other pages | FR-037 |
| 7 | Zoom ranges from the page fitting the screen to 5× the fit-width size | FR-018 |
| 8 | Text is redrawn sharply after a zoom ends | FR-020 |
