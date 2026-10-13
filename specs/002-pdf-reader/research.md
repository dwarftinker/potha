# Research: PDF Reader

**Feature**: 002-pdf-reader | **Date**: 2026-10-12

pdfrx 2.6.5 / pdfrx_engine 0.6.1 sources were read from the pub cache. Package versions
were checked on pub.dev on 2026-10-12; each new dependency is pinned to a release at least
two weeks old.

## R1. Viewer engine

- **Decision**: Keep pdfrx's `PdfViewer` as the page view for PDFs, as in 001. It already
  provides progressive rendering of visible pages, sharp re-rendering after zoom, pinch
  and Ctrl / Cmd + scroll zoom, mixed page sizes, `PdfViewerController` (`goToPage`,
  `goToDest`, `setZoom`, `zoomUp` / `zoomDown`, `visibleRect`, `globalToDocument`), and
  custom page layouts (`layoutPages`, `normalizeMatrix`).
- **Rationale**: FR-016 to FR-020 and SC-002 to SC-004 are what pdfrx's viewer is built
  for. Writing our own tiled renderer would be large and risky (Principle VIII).
- **Damaged pages (found while writing fixtures)**: PDFium draws a page with broken
  content, or an empty MediaBox, as a blank page; it does not fail. A page tree whose
  page count is wrong makes pdfrx refuse the whole file, which is FR-038's "can't be
  opened" path. So FR-037's placeholder is for renders that fail at run time (errors,
  out of memory), and it is tested with a fake document.
- **Alternatives considered**: our own viewer from `PdfPage.render` tiles (full control,
  weeks of work); Syncfusion PDF Viewer (commercial licence, still the CLAUDE.md fallback).

## R2. Paged mode

- **Decision**: Paged mode uses the same `PdfViewer` with a custom horizontal
  `layoutPages` (one page per slot, in a row) and a small `PagedNavigator` that owns page
  turns:
  - at the end of a drag or fling, it decides between "turn" (drag past 25% of the view
    width or a fling) and "snap back", and animates with `controller.goTo`;
  - `normalizeMatrix` keeps the view inside the current page, so panning a zoomed page
    stops at its edges, and only a further swipe at the edge turns the page (FR-019);
  - turning keeps the zoom factor relative to the page's normal view and shows the new
    page from its top-left corner (FR-007, FR-021, clarification Q4).
  Continuous mode uses pdfrx's default vertical layout.
- **Rationale**: pdfrx has no paging or snapping, but its layout and matrix hooks are
  enough to build it in one place. One viewer for both modes keeps rendering, zoom,
  search highlights and links the same in both.
- **Risk and fallback**: this is the riskiest part of the feature. The first story task is
  a spike on the S24 and mobile Chrome. If snapping fights pdfrx's own interaction
  handling, fall back to a Flutter `PageView` of single-page `PdfViewer`s (three alive at
  a time) that share the open `PdfDocument`.
- **Alternatives considered**: `PageView` of `PdfPageView` widgets inside
  `InteractiveViewer` (zoomed pages would stay blurry: FR-020 fails).

## R3. Instant taps, edge zones and links (no double-tap)

- **Decision**: Detect taps ourselves with a `Listener` over the viewer (`TapDetector`):
  one pointer, up within 300 ms and 18 logical pixels of the down point, and the viewer
  matrix did not change during the gesture. It fires on pointer up, without joining the
  gesture arena. The tap is then classified, in this order:
  1. a link under the finger (from cached `ReaderDocument.loadLinks`): jump or confirm
     the web address;
  2. the outer fifth on the left or right: previous or next (FR-007);
  3. anything else: show or hide the controls.
  pdfrx's `onGeneralTap` returns true for every tap type, so pdfrx does nothing on its own,
  and its built-in link handling is not used.
- **Rationale**: pdfrx's page `GestureDetector` always sets `onDoubleTapDown`, so its tap
  callback waits up to 300 ms for a possible second tap. That breaks FR-017 and would
  break tap-to-define in 003 (CLAUDE.md risk 5). A raw `Listener` has no such wait. Doing
  link hit-testing ourselves in document coordinates is also what 003 needs for words.
- **Alternatives considered**: a `GestureDetector` above the viewer (still in the same
  arena as pdfrx's double-tap recogniser); patching pdfrx (fork maintenance).

## R4. Reading position

- **Decision**: A position is `(page, offsetY)`, where `offsetY` in [0, 1] is the
  fraction of the page height at the top of the visible area (0 = top of the page). It is
  computed from `controller.visibleRect` and the page's layout rect, and restored by
  `goTo` with a matrix that puts that point at the top of the view. Horizontal position
  is not saved: a page reopens at its normal view (FR-021).
- **Rationale**: a fraction of the page survives rotation, window resizing, fit changes
  and mode switches (FR-015, spec assumption). It is pure arithmetic, so it is unit
  tested first (Principle IV).
- **Saving**: the 001 `ProgressSaver` is extended to save positions: at most once a
  second while it changes, on leaving the book, and on `AppLifecycleState.paused` /
  `hidden` (FR-011).

## R5. Themes (light, dark, sepia)

- **Decision**: Recolour the page layer, not the controls, with a `ColorFiltered`
  colour matrix around the viewer:
  - sepia: a multiply-style matrix maps white to the paper tone (#F4ECD8) and black to
    the ink tone (#5B4636); photos stay recognisable with a warm tint;
  - dark: "invert lightness, keep hue". This is an inversion followed by a 180° hue
    rotation, remapped so paper becomes #1E1E1E and ink #E0E0E0. Colours keep their hue,
    so a red stays red and a blue sky stays blue.
  The filter wraps the whole viewer, so anything pdfrx paints, including search
  highlights, is recoloured too. Highlights are therefore painted inside the viewer in a
  colour pre-transformed by the inverse of the theme's matrix, so that after the filter
  they show as the intended highlight colour. Dark's matrix is invertible. Sepia's maps
  into a narrower range, so its highlight colour is picked from that range, a warm amber
  that sepia leaves almost unchanged.
- **Known limit**: a colour matrix cannot tell a photo from the page. In dark, colour
  photos keep their hues but their light and dark areas swap, and greyscale photos look
  inverted. FR-028 ("never shown as negatives") cannot be fully met this way.
- **Why not better now**: protecting photos needs PDFium's colour-scheme rendering
  (`FPDF_RenderPageBitmapWithColorScheme_Start`) or the page's image-object bounds.
  `pdfium.wasm` exports both, but pdfrx's web worker has a fixed command table without
  them, and pdfrx's native API does not expose them (the same gap as R1 in 001).
- **Follow-up**: ask pdfrx upstream for colour-scheme rendering, together with T077
  (needs approval: public). When available, swap the filter for it behind the same
  `ReaderTheme` setting.
- **Spec impact**: FR-028 and User Story 6 scenario 2 were reworded (2026-10-12) to
  "photographs keep recognisable colours", with full photo protection deferred.
- **Alternatives considered**: a fragment shader (`ImageFilter.shader`) that inverts only
  low-saturation pixels: protects colour photos better, but greyscale photos still
  invert, and shader image filters are not supported by the web renderer; forking pdfrx's
  worker (maintenance burden across native and WASM).

## R6. Search

- **Decision**: Our own `TextSearch` service over `ReaderDocument.loadPageText`, not
  pdfrx's `PdfTextSearcher`:
  - it folds the query and page text with 001's `text_fold` (case and accents, FR-030) and
    keeps a map from folded to original character indices;
  - it searches page by page from the current page, wrapping around, yielding results as
    a stream (FR-031), and checks a cancel token between pages (FR-033);
  - each result has the page, a snippet (about 40 characters each side, cut at word
    boundaries) and the matched character rects for highlighting.
  Highlights are drawn with pdfrx `pagePaintCallbacks`.
- **Rationale**: Principle III requires search to depend on the document abstraction
  (EPUB will reuse it). pdfrx's searcher is PDF-specific and matches case but not accents.
  The pure-Dart part (folding, index mapping, snippets) is unit tested first.
- **Scanned books (FR-034)**: when search opens, sample up to 20 pages spread through the
  book. If none has text, show "This book has no searchable text" with a "Search anyway"
  action, because text may exist on pages not sampled. If some do, search normally and
  skip textless pages. A full search that finds no text on any page shows the same
  message.

## R7. Table of contents and links

- **Decision**: `ReaderDocument.loadOutline()` (pdfrx `loadOutline`, mapped to
  `OutlineEntry {title, page, children}`) and `loadLinks(page)` (pdfrx `loadLinks`,
  mapped to `PageLink {rect, page}` or `WebLink {rect, uri}`). Links are loaded for
  visible pages and cached per page. The current chapter is the last entry whose page is
  at or before the current page.
- **Web links (FR-025)**: a dialog shows the full address and offers "Open" and
  "Cancel". Open uses `url_launcher` (`LaunchMode.externalApplication`; a new tab on the
  web). `url_launcher` is already in the build as a pdfrx dependency.

## R8. Jump back (FR-026)

- **Decision**: `JumpBack` holds one position. Every jump (contents, link, search
  result, Go to page, slider release, thumbnail) records the position before it. "Back to
  page N" shows as a chip above the bottom bar, and stays visible even when the controls
  hide, until it is used, replaced by another jump, or the book closes. Page turns and
  scrolling do not clear it.
- **Rationale**: one value and pure logic, so unit tests are trivial and the UI stays
  calm.

## R9. Keeping the screen on

- **Decision**: `wakelock_plus` **1.8.0** (BSD-3-Clause, fluttercommunity.dev, Android,
  iOS and web through the Screen Wake Lock API). Enable it when the reader is shown and
  the app is resumed; disable it on leaving the reader or on pause (FR-029). It sits
  behind a small `KeepAwake` interface so widget tests use a fake.
- **Version**: 1.8.1 (2026-09-29) is under two weeks old; 1.8.0 (2026-09-01) needs
  Flutter ≥ 3.44. Revisit after 2026-10-13.
- **Web**: the Wake Lock API needs a secure context (already required for OPFS) and is
  released by the browser when the tab is hidden; it is re-requested on resume.

## R10. Keyboard, system bars and focus

- **Decision**:
  - Keyboard: our own `Shortcuts` / `Actions` on a focus node that wraps the reader;
    pdfrx's `enableKeyboardNavigation` is off. Keys follow FR-008. Esc goes back. Ctrl
    / Cmd + `=` / `-` zoom on the web. Keys are ignored while a text field (search,
    Go to page) has focus.
  - System bars (FR-004): `SystemChrome.setEnabledSystemUIMode(immersiveSticky)` while
    controls are hidden and `edgeToEdge` while shown; restored on leaving the reader. No
    effect on the web.
  - Auto-hide (FR-003): a 3 s timer restarted on any interaction with the controls,
    paused while a panel is open, and off when `MediaQuery.accessibleNavigation` is true.

## R11. Thumbnails

- **Decision**: A `GridView.builder` sheet whose tiles render through
  `ReaderDocument.renderPageImage(page, width)`. That is a new interface method that
  returns a `ui.Image` with no PNG round trip. Tiles are at most 180 px wide × device
  pixel ratio, kept in an LRU cache of 200 images, and requests for tiles scrolled away
  are cancelled (SC-003 on a 2,000-page book).
- **Alternatives considered**: pdfrx `PdfPageView` (PDF-specific; Principle III).

## R12. Page slider and Go to page

- **Decision**: a Material `Slider` with `divisions = pageCount - 1` and a value label
  showing the page during the drag; it jumps on release only (FR-022). Go to page is a
  dialog with a numeric field validated by a pure `parsePageNumber(input, pageCount)`
  (FR-023), which is unit tested.

## R13. Replacing 001's basic page view

- **Decision**: `ReaderScreen` replaces `BasicPageView` in the same deferred library
  (`features/reader/reader.dart`), so the library screen and first web load stay as they
  are (constitution V, CLAUDE.md risk 3). The existing `reading_progress` rows are kept;
  schema v2 adds columns with defaults (data-model.md), so 001 positions open on their
  page (FR-014).

## R14. Performance checks

- **Decision**: extend the 001 device tests:
  - `reader_perf_test.dart` (profile, `flutter drive`): page turns in paged mode and
    continuous scrolling over 50 pages, measuring frame build and raster times, with at
    most 1% late frames (SC-003); time from a turn to a sharp page (SC-002) and from the
    end of a zoom to a sharp page (SC-004), using pdfrx's render-complete callbacks;
  - `reader_open_timing_test.dart`: open a previously opened 20-page and 2,000-page book
    and time until the saved page is painted (SC-001); time slider and contents jumps in
    the 2,000-page book (SC-006); time to the first search result in a 500-page book
    (SC-007).
  New fixtures from `tool/make_fixtures.py`: a 2,000-page book, a 500-page text book, a
  book with an outline and internal and web links, mixed page sizes (landscape fold-out),
  a scanned (image-only) book, and a page with a colour photo.

## Dependencies added

| Package | Version | Licence | Maintained | Platforms | Why |
|---|---|---|---|---|---|
| wakelock_plus | 1.8.0 | BSD-3-Clause | fluttercommunity, monthly releases | Android, iOS, web | FR-029 |
| url_launcher | ^6.3.2 (already transitive) | BSD-3-Clause | flutter.dev | Android, iOS, web | FR-025 web links |

No other new packages. Colour filters, slider, sheets, shortcuts and system UI are all
Flutter SDK.
