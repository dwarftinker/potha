# Implementation Plan: PDF Reader

**Branch**: `002-pdf-reader` | **Date**: 2026-10-12 | **Spec**: [spec.md](spec.md)

**Input**: Feature specification from `/specs/002-pdf-reader/spec.md`

## Summary

Replace 001's basic page view with the full reader. The page fills the screen, and
controls appear on a centre tap and hide after 3 s. The reader has:
- paged and continuous modes, turned by swipe, edge tap or keyboard;
- exact resume, down to the position within the page;
- pinch and button zoom with sharp re-rendering;
- slider, Go to page, table of contents, links and one "Back to page N" step;
- light, dark and sepia themes, with the screen kept on;
- streaming search and a thumbnail grid.

The stack is the same as 001: Flutter, Riverpod, drift and pdfrx. pdfrx's `PdfViewer`
stays the page view. On top of it the plan adds:
- a horizontal paged layout with our own snapping (research R2);
- a raw-pointer tap detector, so taps never wait for a double tap (R3); this also
  prepares for tap-to-define in 003;
- search, outline, links, page text and thumbnails through new `ReaderDocument` methods
  (Principle III).

Research found one gap. pdfrx exposes neither PDFium's colour-scheme rendering nor image
bounds. Dark mode therefore uses a hue-preserving colour matrix, which cannot fully keep
photos from looking inverted (R5). FR-028 was reworded to match; see Complexity Tracking.

## Technical Context

**Language/Version**: Dart 3.13 / Flutter 3.47 (stable)

**Primary Dependencies**: pdfrx 2.6.5, drift 2.35 + drift_flutter 0.3, flutter_riverpod
3.4 (all from 001). New: wakelock_plus 1.8.0. url_launcher 6.3 moves from transitive to
direct. See research, "Dependencies added".

**Storage**: drift schema v2: `reading_progress` gains `page_offset` and `page_mode`, and
there is a new `reader_preferences` table (data-model.md). No new files.

**Testing**: flutter_test for unit and widget tests (fake `ReaderDocument` and view);
host tests with real pdfrx via `tool/fetch_test_pdfium.sh`; integration_test on the
Galaxy S24 and Chrome; `flutter drive --profile` for frame timings.

**Target Platform**: Android 7+ (API 24, compileSdk 37), iOS 15+ (built, not verified),
web (current Chrome, Edge, Firefox and Safari; secure context).

**Project Type**: Cross-platform mobile and web app (single Flutter project)

**Performance Goals**:
- SC-001: last-read page in under 2 s, for 20 and 2,000 pages.
- SC-002: sharp page in under 200 ms after a turn.
- SC-003: at most 1% late frames at 60 fps.
- SC-004: sharp after zoom in under 500 ms.
- SC-006: jumps in under 1 s.
- SC-007: first search results in under 2 s on 500 pages.

**Constraints**:
- Fully offline. Nothing leaves the device except a web link the reader confirms.
- Taps act on pointer up, never waiting for a double tap.
- The reader remains a deferred library on the web.
- Positions saved by 001 must keep working.

**Scale/Scope**: books up to 2,000+ pages and 500 MB (Android) or 100 MB (web). One
screen (reader), with sheets for contents, search, thumbnails and settings, and dialogs
for Go to page and web links.

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Principle | Status | How this plan complies |
|---|---|---|
| I. One codebase, three platforms | Pass | One Flutter code path. Wake lock, system bars and URL launching go through plugins or SDK APIs that cover Android, iOS and web, and the wake lock sits behind `KeepAwake`. Verified on the S24 and in Chrome on desktop and phone (quickstart); iOS is built but not verified, as v2.0.0 allows. |
| II. Offline-first | Pass | No network use. A web link opens only after confirmation, and only in the browser (FR-025). |
| III. Format-agnostic core | Pass | Reader screen, search, contents, thumbnails, jump-back and progress use only `ReaderDocument`, `DocumentViewFactory` and `DocumentViewController` (contracts/reader-document.md). pdfrx stays inside `core/document/pdf/`. Search is ours, not pdfrx's (R6). |
| IV. Test-first for core logic | Pass | Unit tests are written first and fail first for: position maths, tap-zone classification, paged snap decision, search folding / index mapping / snippets, page-number parsing, jump-back, auto-hide timer, position saver, and the v1→v2 migration. Each user story has a widget or integration test (quickstart). |
| V. Reading comes first | Pass, with checks | pdfrx renders only visible pages on a worker; thumbnails are cached and cancellable; search is streamed and cancellable; 001's deferred loading is kept. Device perf tests cover every SC (R14). No target is relaxed. |
| VI. Privacy by default | Pass | Positions and preferences stay in the local database. No analytics. Search terms are not stored. |
| VII. Accessible and calm | Pass | Chrome hidden by default. Semantic labels and page-turn actions, "Page N of M" announcements, no auto-hide under a screen reader, text scaling, AA contrast in three themes (contracts/reader-ui.md). Zoom buttons are the single-pointer alternative to pinch. |
| VIII. Simplicity | Pass | One new package (wakelock_plus, justified in R9); url_launcher is already in the build. No routing package. The page mode is a column, not a new table. Paged mode reuses pdfrx's viewer instead of a second renderer. |

**Post-design re-check (after Phase 1)**: Pass. The design adds no platform code beyond
plugins, and every new interface method has a caller in this feature (no speculative
API). The FR-028 gap is a spec-coverage issue, not a principle violation, and is listed
below.

## Project Structure

### Documentation (this feature)

```text
specs/002-pdf-reader/
├── plan.md              # This file
├── research.md          # Phase 0: R1–R14
├── data-model.md        # Phase 1: schema v2, in-memory types, transitions
├── quickstart.md        # Phase 1: run and validation scenarios
├── contracts/
│   ├── reader-document.md   # ReaderDocument additions, view factory and controller
│   └── reader-ui.md         # taps, keys, controls, panels, accessibility
├── checklists/requirements.md
└── tasks.md             # Phase 2 (/speckit-tasks)
```

### Source Code (repository root)

```text
lib/
├── core/
│   ├── db/app_database.dart              # schema v2: progress columns, reader_preferences
│   ├── document/
│   │   ├── document_format.dart          # + outline, links, page text, page image, view contract
│   │   └── pdf/
│   │       ├── pdf_document_format.dart  # + loadOutline/loadLinks/loadPageText/renderPageImage
│   │       ├── pdf_document_view.dart    # PdfViewer setup for both modes, filters, highlights
│   │       ├── pdf_view_controller.dart  # DocumentViewController over PdfViewerController
│   │       └── pdf_paged_layout.dart     # horizontal layout, normalizeMatrix, snapping (R2)
│   └── platform/keep_awake.dart          # KeepAwake interface + wakelock_plus implementation
└── features/
    ├── library/ui/library_screen.dart    # opens ReaderScreen (deferred) instead of BasicPageView
    └── reader/
        ├── reader.dart                   # deferred entry point (replaces basic_page_view.dart)
        ├── domain/                       # pure Dart, unit tested first
        │   ├── reading_position.dart
        │   ├── tap_zones.dart
        │   ├── paged_snap.dart
        │   ├── page_number_input.dart
        │   ├── jump_back.dart
        │   ├── auto_hide.dart
        │   ├── reader_theme.dart         # colour matrices (R5)
        │   └── text_search.dart          # folding, index map, snippets, streaming (R6)
        ├── data/reader_repository.dart   # position, page mode, preferences
        ├── progress_saver.dart           # now saves ReadingPosition
        └── ui/
            ├── reader_screen.dart        # session, lifecycle, wake lock, system bars
            ├── tap_detector.dart         # instant taps (R3)
            ├── reader_shortcuts.dart     # keys (R10)
            ├── reader_bars.dart          # top and bottom bars, slider, zoom buttons
            ├── jump_back_chip.dart
            ├── settings_sheet.dart
            ├── contents_sheet.dart
            ├── search_panel.dart
            ├── thumbnails_sheet.dart
            ├── go_to_page_dialog.dart
            └── web_link_dialog.dart
test/
├── fixtures/                             # + reader fixtures (quickstart)
├── unit/reader/                          # domain tests, repository, migration v1→v2
├── unit/document/                        # PDF outline/links/text with real pdfrx
└── widget/reader_*_test.dart             # per story, with a fake document and view
integration_test/
├── reader_flow_test.dart                 # open → turn → zoom → jump → back → resume
├── reader_perf_test.dart                 # SC-002, SC-003, SC-004
└── reader_open_timing_test.dart          # SC-001, SC-006, SC-007
tool/make_fixtures.py                     # --reader fixtures
```

**Structure Decision**: same layout as 001. PDF-specific code stays in
`core/document/pdf/`. The reader feature folder holds pure domain logic, its repository
and UI, and depends only on `core/document` interfaces. `basic_page_view.dart` is deleted
once `ReaderScreen` reaches parity (resume and progress).

## Implementation order and risks

1. **Spike first (R2, R3)**: paged layout with snapping, and instant taps over
   `PdfViewer`, on the S24 and mobile Chrome. If snapping fights pdfrx, switch to the
   `PageView` fallback before building the rest.
2. Foundation: schema v2 and migration, `ReaderDocument` additions, view contract,
   `ReadingPosition`, reader repository, deferred `reader.dart` entry.
3. Stories in priority order: US1–US4 (P1) give a releasable reader, then US5–US7 (P2),
   then US8 (P3).
4. Perf tests run on the S24 before merge; any miss is fixed or justified here
   (Principle V).

## Complexity Tracking

No constitution violations. One spec-coverage issue, resolved by rewording the spec:

| Issue | Why | Simpler alternative rejected because |
|---|---|---|
| FR-028 ("photos never shown as negatives") is only partly met in the dark theme: colour photos keep their hues, but their light and dark areas swap, and greyscale photos look inverted (research R5). | Keeping photos intact needs PDFium colour-scheme rendering or image bounds, which pdfrx 2.6.5 does not expose (native or web). | Forking pdfrx's web worker and native API: ongoing maintenance across two runtimes (Principle VIII). A fragment shader: still inverts greyscale photos, and the web renderer does not support shader image filters. |

Resolution (agreed 2026-10-12): FR-028 and User Story 6 scenario 2 now say
"photographs keep recognisable colours". Ask pdfrx upstream for colour-scheme rendering together with T077
(both need approval, being public), and adopt it when it ships.
