---

description: "Task list for feature 002: PDF reader"
---

# Tasks: PDF Reader

**Input**: Design documents from `/specs/002-pdf-reader/`

**Prerequisites**: plan.md, spec.md, research.md, data-model.md, contracts/, quickstart.md

**Tests**: Included. The constitution (Principle IV) requires unit tests written first,
and failing, for core logic, and at least one widget or integration test per user story.

**Organization**: Tasks are grouped by user story so each story can be built and tested
on its own.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies on incomplete tasks)
- **[Story]**: The user story the task belongs to (US1–US8 from spec.md)
- Paths are relative to the repository root (single Flutter project, see plan.md)

---

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Dependencies, fixtures, and the spike that decides the paged-mode design.

- [X] T001 Add `wakelock_plus: 1.8.0` and `url_launcher: ^6.3.2` (already resolved transitively via pdfrx) to the dependencies in pubspec.yaml, with a comment that wakelock_plus 1.8.1 is under two weeks old (revisit after 2026-10-13); run `flutter pub get` and confirm no other resolved versions change in pubspec.lock
- [X] T002 [P] Extend tool/make_fixtures.py with a `--reader` flag that writes to test/fixtures/: `outline_links.pdf` (12 pages, nested outline of 3 chapters with 2 sections each, an internal link on page 1 to page 9, a web link to `https://example.org/potha` on page 2), `mixed_sizes.pdf` (A4 portrait, an A3 landscape fold-out as page 3, A5 portrait), `scanned.pdf` (5 image-only pages, no text layer), `photo.pdf` (1 page with a colour photo-like gradient image and a caption), `damaged_page.pdf` (5 pages, page 3 with broken content and an empty MediaBox; PDFium draws it blank, see research R1 note), `accents.pdf` (text containing "Café", "CAFE" and "naïve"), `text_500.pdf` (500 text pages, "whale" on known pages); and to build/fixtures/ (not committed): `long_2000.pdf` (2,000 text pages) and `short_20.pdf` (20 pages); document the files in the script header
- [ ] T003 Spike paged mode and instant taps (research R2, R3) in the throwaway app ../potha_spike: a `PdfViewer` with a horizontal one-page-per-slot `layoutPages`, `normalizeMatrix` clamping to the current page, snap-on-interaction-end turning (25% / fling), relative zoom kept across turns, and a `Listener`-based tap detector with `onGeneralTap` returning true; run it on the Galaxy S24 and in Chrome on the phone; record the result (works / fallback to `PageView` of single-page `PdfViewer`s) and any pdfrx quirks in specs/002-pdf-reader/research.md R2 and R3

**Checkpoint**: Dependencies resolve, fixtures exist, and the paged-mode approach is confirmed before the view is built.

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Schema v2, the extended document abstraction, position and preference storage, and the reader screen shell that replaces 001's basic page view.

**⚠️ CRITICAL**: No user story work can begin until this phase is complete.

- [X] T004 [P] Write the v1 → v2 migration test in test/unit/db/migration_test.dart: a v1 database with two `reading_progress` rows (pages 5 and 57) migrates to v2 with `current_page` kept, `page_offset` = 0 and `page_mode` = null; `reader_preferences` has row 1 with theme `light` and fit `fitWidth`; `page_offset` outside 0–1 is rejected by the check constraint
- [X] T005 Change the schema in lib/core/db/app_database.dart exactly as data-model.md: `ReadingProgress.pageOffset` real not null default 0 with check "0 ≤ page_offset ≤ 1"; `ReadingProgress.pageMode` textEnum<PageMode> nullable ("null means the default, `paged`"); new table `ReaderPreferences` (id int PK "always 1"; theme textEnum `light|dark|sepia` default `light`; fit textEnum `fitWidth|fitPage` default `fitWidth`); `schemaVersion` 2 with a step migration (`addColumn` ×2, `createTable`, insert row 1) and row 1 inserted in `onCreate`; then run `dart run build_runner build`, `dart run drift_dev make-migrations` and `dart run drift_dev schema generate drift_schemas/app_database/ test/unit/db/generated/`; make T004 pass
- [X] T006 [P] Unit-test `ReadingPosition` in test/unit/document/reading_position_test.dart: values are clamped (page to 1..pageCount, offsetY to 0..1); `fromVisible(pageRect, visibleTop)` gives the fraction of the page height at the top of the view; `topFor(pageRect, position)` inverts it; the same position maps to the same content after the page rect is scaled (rotation, resize, fit change; FR-015); equality and `toString`
- [X] T007 [P] Implement `ReadingPosition` in lib/core/document/reading_position.dart; make T006 pass
- [X] T008 [P] Extend lib/core/document/document_format.dart per contracts/reader-document.md: `ReaderDocument.pageSize`, `loadOutline`, `loadLinks`, `loadPageText`, `renderPageImage`; value types `OutlineEntry {title, int? page, children}`, sealed `DocumentLink` (`PageLink {rect, page}`, `WebLink {rect, uri}`, rects normalised 0–1), `PageText {text, charRects}`, `PagePoint {page, Offset normalised}`, `PageHighlight {page, rects}`, enums `PageMode {paged, continuous}` and `PageFit {fitWidth, fitPage}`; replace `DocumentViewFactory.build` with the `controller` + `ReaderViewConfig` signature; add `DocumentViewController` and `ReaderTap`
- [X] T009 [P] Write real-pdfrx tests for the PDF additions in test/unit/document/pdf_reader_document_test.dart (PDFium from tool/fetch_test_pdfium.sh), using T002 fixtures: `loadOutline` on outline_links.pdf returns 3 chapters with 2 children each and correct pages, and [] for three_pages.pdf; `loadLinks(1)` has a `PageLink` to page 9 and `loadLinks(2)` a `WebLink` to https://example.org/potha, with rects inside 0–1; `loadPageText` returns text and one rect per character for a text page, and '' for scanned.pdf; `pageSize(3)` of mixed_sizes.pdf is landscape; `renderPageImage` returns an image of the requested width, and null for the damaged page without throwing
- [X] T010 Implement the additions in lib/core/document/pdf/pdf_document_format.dart (`PdfReaderDocument`): map pdfrx `loadOutline` / `PdfDest.pageNumber`, `page.loadLinks(compact: true)` (dest → `PageLink`, url → `WebLink`), `page.loadText()` (`fullText`, `charRects` normalised by page size), `page.render` → `createImage()` for `renderPageImage` with cancellation via `createCancellationToken`; all best effort, never throwing; make T009 pass
- [X] T011 [P] Unit-test `ReaderRepository` in test/unit/reader/reader_repository_test.dart with an in-memory database: `loadPosition` returns null for a new book and `ReadingPosition(page, offset)` after `savePosition`; `savePosition` updates `currentPage` (so the library's progress follows, FR-013) and `updatedAt`; `pageMode(bookId)` is `paged` by default and per book after `setPageMode` (FR-009); `watchPreferences` emits defaults then changes from `setTheme` / `setFit`
- [X] T012 Implement `ReaderRepository` and `readerRepositoryProvider` in lib/features/reader/data/reader_repository.dart; make T011 pass
- [X] T013 [P] Extend test/unit/library/progress_saver_test.dart for positions: saves at most once a second with the latest `ReadingPosition`; skips a write when only the offset changed by < 1% of the page; `flush()` writes immediately (used on lifecycle pause); `dispose` writes the last position
- [X] T014 Change lib/features/reader/progress_saver.dart to save `ReadingPosition` through `ReaderRepository.savePosition`, add `flush()`; make T013 pass
- [X] T015 [P] Create lib/core/platform/keep_awake.dart: a `KeepAwake` interface (`enable`, `disable`), the wakelock_plus implementation, and `keepAwakeProvider`; add a `FakeKeepAwake` recording calls in test/widget/test_app.dart
- [X] T016 [P] Add reader test helpers in test/widget/reader_test_app.dart: a `FakeReaderDocument` (configurable page count, sizes, outline, links, page texts, failing pages) and a `FakeDocumentView` + `FakeViewController` (records `goTo` / `next` / `previous` / `zoomIn` / `zoomOut`, lets tests emit positions and taps), registered through the view-factory provider
- [X] T017 Create the reader shell in lib/features/reader/reader.dart (deferred entry point, `buildReader(bookId)`) and lib/features/reader/ui/reader_screen.dart: move the open logic from basic_page_view.dart (find book, find file, stored password, password dialog, errors FR-038), load the saved position and page mode, build the view through `documentViewFactoriesProvider` with a `ReaderViewConfig`, save positions through `ProgressSaver`; switch lib/features/library/ui/library_screen.dart's deferred import to reader.dart; delete lib/features/reader/basic_page_view.dart; update test/widget/open_protected_book_test.dart to the new screen and keep it passing
- [X] T018 Implement `PdfDocumentViewFactory` for continuous mode in lib/core/document/pdf/pdf_document_view.dart and `PdfViewController` in lib/core/document/pdf/pdf_view_controller.dart: `PdfViewer` with `enableKeyboardNavigation: false`, text selection off, pdfrx link handling off, `onGeneralTap` returning true for every type (research R3), `initialPosition` applied with `goTo` once ready, `onPositionChanged` from the visible rect (contract row 5), a placeholder for pages that fail to render (FR-037, `errorBannerBuilder` / page paint callback), pages shown at their own aspect ratio (FR-036), `position`, `goTo`, `pagePointAt`

**Checkpoint**: Tapping a book opens the new reader in continuous mode on its saved page; 001's behaviour (open, password, resume, progress) still works; all 001 tests pass.

---

## Phase 3: User Story 1 - Read comfortably (Priority: P1) 🎯 MVP

**Goal**: The page fills the screen; a centre tap shows or hides the top and bottom bars; they hide after 3 s; taps act immediately.

**Independent Test**: Open a book, see no controls, tap the centre, wait 3 s, see them hide (quickstart 1–3, 5).

### Tests for User Story 1 (write first, confirm they fail) ⚠️

- [X] T019 [P] [US1] Unit-test the auto-hide logic in test/unit/reader/auto_hide_test.dart with fake time: hides 3 s after `shown`; `interacted` restarts the 3 s; `holdOpen` (panel open, slider dragging) suspends hiding until released; `screenReaderOn` never hides (FR-003)
- [X] T020 [P] [US1] Unit-test tap classification in test/unit/reader/tap_zones_test.dart: x < 20% of the width → `previous`, x > 80% → `next`, otherwise `toggleControls`; a tap inside a link rect on the tapped page wins over the zones and returns `link(PageLink | WebLink)`; boundaries exactly at 20% / 80%; works for any view width (FR-002, FR-007, FR-025)
- [X] T021 [P] [US1] Widget-test `TapDetector` in test/widget/tap_detector_test.dart: a tap fires on pointer up with no added delay (pump 0 ms after up); two taps 100 ms apart fire twice and never as a double tap (FR-017); a drag over 18 px, a hold over 300 ms, a second pointer, or a view-matrix change during the gesture fires nothing
- [X] T022 [P] [US1] Widget-test the reading screen in test/widget/reader_controls_test.dart with the fake document and view: opens with controls hidden (FR-001); a page the view reports as failed shows "This page can't be shown" (FR-037); a centre tap shows the top bar (Back, title) and the bottom bar (slider, "Page N of M") and another hides them (FR-002); they hide after 3 s and stay while a screen reader is on (`MediaQuery.accessibleNavigation`, FR-003); `SystemChrome` immersive / edge-to-edge calls follow the controls (FR-004, via a mocked platform channel); a page change is announced as "Page N of M" (checked through the semantics announcement, FR-040); Back returns to the library

### Implementation for User Story 1

- [X] T023 [P] [US1] Implement `AutoHide` in lib/features/reader/domain/auto_hide.dart (a `ChangeNotifier` with an injectable timer factory); make T019 pass
- [X] T024 [P] [US1] Implement `classifyTap` in lib/features/reader/domain/tap_zones.dart; make T020 pass
- [X] T025 [P] [US1] Implement `TapDetector` in lib/features/reader/ui/tap_detector.dart (a `Listener` with the rules in contracts/reader-ui.md, no gesture arena); make T021 pass
- [X] T026 [US1] Build lib/features/reader/ui/reader_bars.dart: the top bar (Back, title on one line with ellipsis, placeholders for Contents, Search, Thumbnails, Settings) and the bottom bar (page slider and "Page N of M"), sliding in and out, themed for readability over the page; semantics labels on every control
- [X] T027 [US1] Wire US1 into lib/features/reader/ui/reader_screen.dart: `TapDetector` over the view → `classifyTap` → toggle controls; `AutoHide`; system bars with `SystemChrome.setEnabledSystemUIMode` (immersiveSticky when hidden, edgeToEdge when shown), restored on leaving; announce "Page N of M" on page change (FR-040); make T022 pass

**Checkpoint**: The reader is calm and full-screen; controls toggle instantly and hide on their own.

---

## Phase 4: User Story 2 - Move through the book (Priority: P1)

**Goal**: Paged and continuous modes; swipes, edge taps and keys move one page (paged) or one screen (continuous); the mode is remembered per book.

**Independent Test**: In each mode, move forward and back with every input; reopen the book and see the same mode (quickstart 4, 6–8).

### Tests for User Story 2 (write first, confirm they fail) ⚠️

- [ ] T028 [P] [US2] Unit-test the paged snap decision in test/unit/reader/paged_snap_test.dart: drag past 25% of the view width → turn in the drag direction; a fling over the threshold velocity → turn; otherwise snap back; no turn past the first or last page (FR-010); while zoomed, a drag that starts with the visible area away from the page edge pans and never turns (FR-019); the continuous step is the view height minus 1/24 (one line of overlap, FR-007)
- [ ] T029 [P] [US2] Widget-test navigation in test/widget/reader_navigation_test.dart with the fake view: left and right edge taps call `previous` / `next` in both modes (FR-007); Right Arrow, Page Down and Space call `next`, Left Arrow, Page Up and Shift + Space call `previous`, Home and End go to the first and last page, Up / Down scroll a small step in continuous mode (FR-008); keys are ignored while a text field has focus; Esc goes back; a new book opens paged, switching a book to continuous in the settings sheet is saved and restored on reopening, and other books keep their own mode (FR-009); semantics actions "Next page" / "Previous page" exist on the page view (FR-040)

### Implementation for User Story 2

- [ ] T030 [P] [US2] Implement `pagedSnap` and `continuousStep` in lib/features/reader/domain/paged_snap.dart; make T028 pass
- [ ] T031 [US2] Implement paged mode in lib/core/document/pdf/pdf_paged_layout.dart per the T003 outcome: horizontal one-page-per-slot `layoutPages` relaid out on view size change, `normalizeMatrix` keeping the view inside the current page, snapping on interaction end through `pagedSnap`, and turns that keep the zoom relative to the normal view and show the new page from its top-left corner (FR-006, FR-019, FR-021); or the `PageView` fallback if the spike chose it
- [ ] T032 [US2] Implement `next` / `previous` in lib/core/document/pdf/pdf_view_controller.dart for both modes (contract rows 2 and 3) and switch the view factory between paged and continuous from `ReaderViewConfig.mode`, keeping the position (FR-015)
- [ ] T033 [P] [US2] Implement the keyboard map in lib/features/reader/ui/reader_shortcuts.dart (`Shortcuts` + `Actions` on the reader's focus node, contracts/reader-ui.md "Keys")
- [ ] T034 [US2] Create lib/features/reader/ui/settings_sheet.dart with the page-mode choice (Paged / Continuous, saved per book through `ReaderRepository.setPageMode`), open it from the Settings button (FR-005); wire edge-tap results, shortcuts and semantics actions in reader_screen.dart; make T029 pass

**Checkpoint**: Both modes work with every input; the mode is per book.

---

## Phase 5: User Story 3 - Resume where I left off (Priority: P1)

**Goal**: Reopening a book, even after the app was closed, returns to the same page and position; library progress matches.

**Independent Test**: Read to halfway down a page, leave, close the app, reopen the book (quickstart 9–11).

### Tests for User Story 3 (write first, confirm they fail) ⚠️

- [ ] T035 [P] [US3] Widget-test resume in test/widget/reader_resume_test.dart: a saved `(57, 0.5)` is passed as `initialPosition`; emitted positions are saved within 1 s; leaving the reader saves at once; `AppLifecycleState.paused` and `hidden` flush the saver (FR-011); a 001 row (page 12, offset 0, mode null) opens on page 12 in paged mode (FR-014); the library shows 57% for page 57 of 100 after leaving (FR-013)
- [ ] T036 [P] [US3] Widget-test position keeping in test/widget/reader_keep_position_test.dart: changing the view size (rotation, window resize), the mode, the fit or the theme calls `goTo` with the position held before the change (FR-015)

### Implementation for User Story 3

- [ ] T037 [US3] In lib/features/reader/ui/reader_screen.dart observe the app lifecycle (`AppLifecycleListener`) and flush the `ProgressSaver` on pause / hide; save on every route exit (back button, gesture, Esc, Back control); make T035 pass
- [ ] T038 [US3] Keep the position across view-size, mode, fit and theme changes: the reader screen holds the last `ReadingPosition` and re-applies it with `goTo(animate: false)` after the view rebuilds; in lib/core/document/pdf/pdf_document_view.dart re-apply on `onViewSizeChanged`; make T036 pass

**Checkpoint**: P1 stories US1–US3 done except zoom; resume is exact.

---

## Phase 6: User Story 4 - Zoom (Priority: P1)

**Goal**: Pinch, zoom buttons on every platform and Ctrl / Cmd + wheel on the web; fit width or fit page as the normal view; sharp text after zooming.

**Independent Test**: Pinch in on small text, pan, use the buttons, switch fit (quickstart 12–13).

### Tests for User Story 4 (write first, confirm they fail) ⚠️

- [ ] T039 [P] [US4] Unit-test zoom limits in test/unit/reader/zoom_range_test.dart: for a page size and view size, the minimum is the scale that fits the whole page and the maximum is 5× the fit-width scale (FR-018); `normalScale(fit)` is fit-width or fit-page; zoom buttons step by ×1.25 and clamp to the range
- [ ] T040 [P] [US4] Widget-test zoom controls in test/widget/reader_zoom_test.dart: the bottom bar has "Zoom in" and "Zoom out" buttons on Android and web (target platform overrides) that call the controller (FR-016); Ctrl + `=` / `-` zoom; choosing Fit page in settings applies to all books and is saved (FR-021); reopening a book starts at the normal view (zoom not restored)

### Implementation for User Story 4

- [ ] T041 [P] [US4] Implement `zoomRange`, `normalScale` and `zoomStep` in lib/features/reader/domain/zoom_range.dart; make T039 pass
- [ ] T042 [US4] In lib/core/document/pdf/pdf_document_view.dart and pdf_view_controller.dart set `minScale` / `maxScale` from `zoomRange`, compute the initial zoom from the fit (`calculateInitialZoom`), keep pinch and Ctrl / Cmd + wheel enabled, implement `zoomIn` / `zoomOut` around the view centre and the `zoom` getter (1.0 = normal view)
- [ ] T043 [US4] Add the zoom buttons to lib/features/reader/ui/reader_bars.dart, the zoom shortcuts to reader_shortcuts.dart, and the fit choice (Fit width / Fit page, for all books via `ReaderRepository.setFit`) to settings_sheet.dart; make T040 pass

**Checkpoint**: All P1 stories (US1–US4) are done: a releasable reader. Run quickstart 1–13 on the S24 and Chrome.

---

## Phase 7: User Story 5 - Jump to a place (Priority: P2)

**Goal**: Slider with a live page label, Go to page, table of contents, internal and web links, and one "Back to page N" step.

**Independent Test**: Jump with the slider, a typed page, the contents and a link, then go back (quickstart 14–18).

### Tests for User Story 5 (write first, confirm they fail) ⚠️

- [ ] T044 [P] [US5] Unit-test `parsePageNumber(input, pageCount)` in test/unit/reader/page_number_input_test.dart: "120" → 120 for 300 pages; " 7 " → 7; "0", "301", "-3", "abc", "" and "1.5" → an error carrying the range "1–300" (FR-023)
- [ ] T045 [P] [US5] Unit-test `JumpBack` in test/unit/reader/jump_back_test.dart: empty at start; `recordJump(from)` sets it; a second jump replaces it; `use()` returns the position and clears it; `clear()` empties it; page turns do not change it (FR-026)
- [ ] T046 [P] [US5] Unit-test `currentChapter(outline, page)` in test/unit/reader/outline_test.dart: the deepest entry whose page is at or before the current page; null before the first entry; entries without a page are skipped (FR-024)
- [ ] T047 [P] [US5] Widget-test jumping in test/widget/reader_jump_test.dart with the fake document: dragging the slider shows "Page N" live and calls `goTo` only on release (FR-022); Go to page accepts 120 and rejects 0 with "Enter a page from 1 to 300." (FR-023); Contents lists nested entries with page numbers, marks the current chapter and jumps; a book without one shows "This book has no table of contents." (FR-024); tapping a page link jumps (FR-025); tapping a web link shows the full address, Cancel opens nothing and Open calls the fake `LinkOpener` once (FR-025); after each jump "Back to page N" appears, returns to the exact earlier position and disappears (FR-026)

### Implementation for User Story 5

- [ ] T048 [P] [US5] Implement `parsePageNumber` in lib/features/reader/domain/page_number_input.dart; make T044 pass
- [ ] T049 [P] [US5] Implement `JumpBack` in lib/features/reader/domain/jump_back.dart; make T045 pass
- [ ] T050 [P] [US5] Implement `currentChapter` in lib/features/reader/domain/outline.dart; make T046 pass
- [ ] T051 [P] [US5] Create lib/features/reader/ui/go_to_page_dialog.dart (numeric field, range hint, error text) and open it from "Page N of M" in the bottom bar
- [ ] T052 [P] [US5] Create lib/features/reader/ui/contents_sheet.dart (nested, indented list with page numbers, current chapter marked, empty state, loaded once per open book through `loadOutline`)
- [ ] T053 [P] [US5] Create lib/features/reader/ui/web_link_dialog.dart (full address, Open / Cancel) and a `LinkOpener` interface with a url_launcher implementation (`LaunchMode.externalApplication`) and `linkOpenerProvider` in lib/core/platform/link_opener.dart
- [ ] T054 [P] [US5] Create lib/features/reader/ui/jump_back_chip.dart ("Back to page N", shown above the bottom bar whether or not the controls are visible)
- [ ] T055 [US5] Wire jumps in lib/features/reader/ui/reader_screen.dart and reader_bars.dart: the slider label and release jump; a per-page link cache filled for visible pages through `loadLinks` and passed to `classifyTap`; record `JumpBack` before every jump (slider, Go to page, contents, link, and later search and thumbnails); make T047 pass

**Checkpoint**: Every navigation path works and can be undone once.

---

## Phase 8: User Story 6 - Reading themes (Priority: P2)

**Goal**: Light, dark and sepia for all books; photos keep recognisable colours; the screen stays on while reading.

**Independent Test**: Switch themes on text and photo pages; leave the book open past the screen timeout (quickstart 19–20).

### Tests for User Story 6 (write first, confirm they fail) ⚠️

- [ ] T056 [P] [US6] Unit-test the theme colour matrices in test/unit/reader/reader_theme_test.dart by applying them to colours: light is null (no filter); sepia maps white to #F4ECD8 and black to #5B4636 (±2 per channel); dark maps white to #1E1E1E and black to #E0E0E0, and a saturated red, green and blue keep their hue within 15° (FR-028); the control colours of each theme meet WCAG AA contrast (4.5:1 text, 3:1 icons) (FR-040); for each theme, `highlightPaintColor` passed through that theme's matrix comes out within 10 per channel of the intended highlight colour (research R5)
- [ ] T057 [P] [US6] Widget-test themes and keep-awake in test/widget/reader_theme_test.dart: choosing Dark in settings saves it and applies to the next book opened (FR-027); the view receives the dark `pageFilter`; bars use the theme's colours; `FakeKeepAwake.enable` is called when the reader opens, `disable` on leaving and on `paused`, and `enable` again on `resumed` (FR-029)

### Implementation for User Story 6

- [ ] T058 [P] [US6] Implement `ReaderTheme` in lib/features/reader/domain/reader_theme.dart: the light / sepia / dark page colour matrices (research R5), control colour schemes, and `highlightPaintColor` (the intended highlight colour pre-transformed by the inverse matrix for dark, a warm amber within sepia's range); make T056 pass
- [ ] T059 [US6] Apply `ReaderViewConfig.pageFilter` in lib/core/document/pdf/pdf_document_view.dart with `ColorFiltered` around the viewer, painting the viewer background in the theme colour; anything pdfrx paints (including highlights) is filtered, so highlight colours come from `ReaderTheme.highlightPaintColor` (research R5)
- [ ] T060 [US6] Add the theme choice to lib/features/reader/ui/settings_sheet.dart (for all books via `ReaderRepository.setTheme`), theme the bars, sheets and dialogs from `ReaderTheme`, and enable / disable `KeepAwake` in reader_screen.dart on open, leave and lifecycle changes; make T057 pass

**Checkpoint**: Comfortable night reading; the screen stays on only in the reader.

---

## Phase 9: User Story 7 - Search in the book (Priority: P2)

**Goal**: Streaming search that ignores case and accents, with results, highlights, Next / Previous and a clear message for scanned books.

**Independent Test**: Search a novel for a repeated word, jump, step through; search a scanned book (quickstart 21–24).

### Tests for User Story 7 (write first, confirm they fail) ⚠️

- [ ] T061 [P] [US7] Unit-test `TextSearch` in test/unit/reader/text_search_test.dart with a fake document: "cafe" finds "Café" and "CAFE" (FR-030); matches map back to the original character indices and rects, including where folding changes length ("ß" → "ss"); snippets hold about 40 characters each side, cut at word boundaries, with the match position; results stream page by page starting at the current page and wrapping; several matches on one page come in order; cancelling stops before the next page (FR-033); a phrase across a line break matches; the scanned check samples at most 20 pages spread through the book and reports `noText` when all are empty; a full search that finds no text on any page also reports `noText` (FR-034)
- [ ] T062 [P] [US7] Widget-test the search panel in test/widget/reader_search_test.dart: typing a query streams results with page numbers and snippets (FR-031); choosing one jumps, records jump-back and highlights the match (`highlights` in the config); Next / Previous move across pages and show "match X of Y" with Y growing while running (FR-032); a new query cancels the old one and closing search stops it (FR-033); "No matches." on none; "This book has no searchable text." with a "Search anyway" action for a book whose sampled pages are textless, and choosing it runs the full search (FR-034)

### Implementation for User Story 7

- [ ] T063 [P] [US7] Implement `TextSearch` in lib/features/reader/domain/text_search.dart (fold with lib/features/library/domain/text_fold.dart, an index map, snippets, `Stream<SearchResult>`, cancel token, `checkHasText`); make T061 pass
- [ ] T064 [US7] Create lib/features/reader/ui/search_panel.dart (field, result list with the match in bold, progress while searching, "match X of Y", Next / Previous, empty and no-text states) and open it from the Search button; keep reading responsive by yielding between pages (SC-007)
- [ ] T065 [US7] Draw search highlights in lib/core/document/pdf/pdf_document_view.dart from `ReaderViewConfig.highlights` with a `pagePaintCallbacks` painter in `ReaderTheme.highlightPaintColor`, so the highlight looks right after the theme filter; make T062 pass

**Checkpoint**: Search works on text books and explains itself on scanned ones.

---

## Phase 10: User Story 8 - Page thumbnails (Priority: P3)

**Goal**: A grid of page images opened at the current page, which is marked; choosing one jumps there; smooth in long books.

**Independent Test**: Open thumbnails in the 2,000-page book, fling, choose a page (quickstart 25).

### Tests for User Story 8 (write first, confirm they fail) ⚠️

- [ ] T066 [P] [US8] Unit-test `ThumbnailCache` in test/unit/reader/thumbnail_cache_test.dart: an LRU of 200 images that disposes evicted images; a request for a page already loading shares the result; cancelling a request for a tile scrolled away cancels the render; a failed render is remembered as a placeholder
- [ ] T067 [P] [US8] Widget-test thumbnails in test/widget/reader_thumbnails_test.dart: the grid opens scrolled to the current page, which is marked, with page numbers (FR-035); choosing a page jumps and records jump-back; a failing page shows a placeholder tile

### Implementation for User Story 8

- [ ] T068 [P] [US8] Implement `ThumbnailCache` in lib/features/reader/data/thumbnail_cache.dart over `ReaderDocument.renderPageImage` (width = min(180, tile width) × device pixel ratio); make T066 pass
- [ ] T069 [US8] Create lib/features/reader/ui/thumbnails_sheet.dart (`GridView.builder`, aspect ratios from `pageSize`, scrolled to the current page) and open it from the Thumbnails button; make T067 pass

**Checkpoint**: All eight stories done.

---

## Phase 11: Polish & Cross-Cutting Concerns

**Purpose**: Device and browser verification, performance, accessibility and docs.

- [ ] T070 [P] Write integration_test/reader_flow_test.dart for the device and Chrome with real pdfrx and fixtures imported through `XFile` (as in 001): open → paged turns by swipe and edge tap → continuous → zoom with buttons → contents jump → link jump → Back to page N → search "whale" → leave → reopen on the same page and offset (SC-005 over 20 fixture positions), and rotation on Android; damaged_page.pdf opens, page 3 shows (blank) without errors, pages 2 and 4 render and navigation past page 3 works (FR-037; the placeholder itself is covered with the fake document in T022)
- [ ] T071 [P] Write integration_test/reader_perf_test.dart (profile, `flutter drive --no-dds`, `fullyLive`, semantics off as in scroll_perf_test.dart): 50 paged turns and continuous flings over 50 pages with `traceAction` (≤ 1% late frames, SC-003); time from a turn to a sharp page (< 200 ms, SC-002) and from the end of a zoom to a sharp re-render (< 500 ms, SC-004), printing the timings
- [ ] T072 [P] Write integration_test/reader_open_timing_test.dart: open previously opened short_20.pdf and long_2000.pdf to the saved page painted (< 2 s, SC-001); slider, Go to page, contents and thumbnail jumps in long_2000.pdf (< 1 s, SC-006); first search result in text_500.pdf (< 2 s, SC-007), then continuous-scroll flings while the search is still running with `traceAction` (≤ 1% late frames, SC-007 "reading stays responsive"); print the timings
- [ ] T073 [P] Extend test/widget/accessibility_test.dart for the reader: every control has a label; `meetsGuideline(androidTapTargetGuideline)` and `textContrastGuideline` in all three themes; at text scale 2.0 the bars do not overflow (FR-040)
- [ ] T074 [P] Extend test/unit/no_network_test.dart so the reader code paths (open, search, outline, links, thumbnails) make no HTTP requests; the only outbound action is `LinkOpener` after confirmation (FR-039, FR-041)
- [ ] T075 Check the web build: `tool/build_web.sh`, then confirm the first load is unchanged from 001 (about 3.9 MB gzipped; the reader and pdfium.wasm load only on first open) and the Wake Lock works in Chrome over `localhost`; record the sizes in specs/002-pdf-reader/quickstart.md
- [ ] T076 Run quickstart scenarios 1–33 on the Galaxy S24 and in desktop Chrome and Chrome on the phone; record results, bugs found and fixes in specs/002-pdf-reader/checklists/verification.md (the 001 format); fix or justify any performance miss in plan.md (Principle V)
- [ ] T077 Draft the upstream pdfrx request for PDFium colour-scheme rendering (`FPDF_RenderPageBitmapWithColorScheme_Start`) and image-object bounds for dark mode (research R5), combined with 001's T077 metadata request, in specs/002-pdf-reader/upstream-request.md; **needs the user's approval before posting** (public)
- [ ] T078 Update CLAUDE.md: status of 002, the reader's tap detector (relevant to 003's tap-to-define), the new perf commands, the FR-028 limitation, and the wakelock_plus pin to revisit

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: none. T003 (spike) must finish before T031 (paged mode).
- **Foundational (Phase 2)**: depends on Setup; blocks all stories.
- **US1 (Phase 3)**: depends on Foundational.
- **US2 (Phase 4)**: depends on US1's tap detector and classification (T024, T025) for edge taps.
- **US3 (Phase 5)**: depends on Foundational; T038 also covers mode and fit changes, so do it after US2 (mode) and finish it after US4 (fit).
- **US4 (Phase 6)**: depends on Foundational; the settings sheet from US2 (T034).
- **US5 (Phase 7)**: depends on US1 (bars, tap classification).
- **US6 (Phase 8)**: depends on the settings sheet (T034).
- **US7 (Phase 9)**: depends on Foundational (`loadPageText`) and US5's jump-back (T049).
- **US8 (Phase 10)**: depends on Foundational (`renderPageImage`) and US5's jump-back.
- **Polish (Phase 11)**: after the stories you intend to ship.

### Shared files (do not edit in parallel)

- lib/features/reader/ui/reader_screen.dart: T017, T027, T034, T037, T038, T055, T060
- lib/features/reader/ui/reader_bars.dart: T026, T043, T055
- lib/features/reader/ui/settings_sheet.dart: T034, T043, T060
- lib/core/document/pdf/pdf_document_view.dart: T018, T032, T038, T042, T059, T065
- lib/core/document/pdf/pdf_view_controller.dart: T018, T032, T042

### Within Each User Story

- Tests are written first and must fail before implementation (Principle IV).
- Domain → data → view → UI wiring.
- Commit after each task or logical group.

### Parallel Opportunities

- Setup: T002 alongside T001; T003 after T001.
- Foundational: T004, T006, T008, T011, T013, T015, T016 in parallel; then T005, T007, T009, T012, T014; then T010; T017 and T018 last.
- Each story's test tasks run in parallel, and so do its new-file domain tasks (T023–T025, T030 and T033, T041, T048–T054, T058, T063, T068).
- Polish: T070–T074 in parallel.

---

## Parallel Example: User Story 5

```bash
# Tests first, together:
Task: "Unit-test parsePageNumber in test/unit/reader/page_number_input_test.dart"
Task: "Unit-test JumpBack in test/unit/reader/jump_back_test.dart"
Task: "Unit-test currentChapter in test/unit/reader/outline_test.dart"
Task: "Widget-test jumping in test/widget/reader_jump_test.dart"

# Then the new files, together:
Task: "Implement parsePageNumber in lib/features/reader/domain/page_number_input.dart"
Task: "Implement JumpBack in lib/features/reader/domain/jump_back.dart"
Task: "Create lib/features/reader/ui/contents_sheet.dart"
Task: "Create lib/features/reader/ui/web_link_dialog.dart and lib/core/platform/link_opener.dart"
```

---

## Implementation Strategy

### MVP First (P1 stories: US1–US4)

1. Phase 1 Setup, including the spike → Phase 2 Foundational.
2. US1 read comfortably → US2 move → US3 resume → US4 zoom.
3. **Stop and validate** on the S24 and Chrome (quickstart 1–13, plus the perf runs
   T071–T072 early, since paged mode is the riskiest part). This is a reader that could
   ship.

### Incremental Delivery

4. US5 jump → validate (quickstart 14–18).
5. US6 themes → validate (19–20).
6. US7 search → validate (21–24).
7. US8 thumbnails → validate (25).
8. Polish → full quickstart run → merge (Android and web verified; iOS noted unverified).

---

## Notes

- [P] tasks touch different files and have no dependencies on incomplete tasks.
- [USn] labels map tasks to spec.md user stories for traceability.
- Device tests feed books through `XFile`, as on the platform (CLAUDE.md).
- T077 is outward-facing: draft only; post after the user approves.
