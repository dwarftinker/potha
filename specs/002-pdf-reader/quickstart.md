# Quickstart: PDF Reader

How to run feature 002 and confirm it works. Details are in [data-model.md](data-model.md)
and [contracts/](contracts/).

## Prerequisites

As in 001 ([../001-library-and-import/quickstart.md](../001-library-and-import/quickstart.md)):
Flutter 3.47, the Android SDK and the Galaxy S24 (`RFCX80MJSBN`), desktop Chrome, and
Chrome on the phone.

- Fixtures: `python3 tool/make_fixtures.py --reader` adds `long_2000.pdf`,
  `text_500.pdf`, `outline_links.pdf` (outline, internal links and a web link),
  `mixed_sizes.pdf` (with a landscape fold-out), `scanned.pdf` (images only) and
  `photo.pdf` (a colour photo).
- Real books: one long novel, one textbook with a contents list, one scanned book.

## Run

```bash
flutter pub get
dart run build_runner build
python3 tool/make_fixtures.py --reader
flutter test test/unit test/widget
flutter run -d chrome --no-web-resources-cdn
flutter test integration_test -d RFCX80MJSBN
flutter drive --profile --no-dds --driver=test_driver/perf_driver.dart \
  --target=integration_test/reader_perf_test.dart -d RFCX80MJSBN      # SC-002/3/4
flutter drive --profile --no-dds --driver=test_driver/perf_driver.dart \
  --target=integration_test/reader_open_timing_test.dart -d RFCX80MJSBN  # SC-001/6/7
```

Mobile web: `adb reverse tcp:8080 tcp:8080`, then `flutter run -d web-server --web-port
8080` and open `http://localhost:8080` on the phone (secure context for OPFS and the
wake lock).

## Validation scenarios

Run on Android and on web (desktop Chrome and Chrome on the phone). iOS is not verified
(constitution v2.0.0).

| # | Steps | Expected |
|---|---|---|
| 1 | Open a book from the library | Page fills the screen; controls hidden (FR-001) |
| 2 | Tap the centre; wait 3 s | Bars appear (and system bars on Android); everything hides after 3 s (FR-002–004) |
| 3 | With TalkBack on, show the controls | They stay; "Page N of M" is announced on page change (FR-003, FR-040) |
| 4 | Paged: swipe left and right, tap both edges | One page per action; a short drag snaps back; no wait after a tap (FR-006, FR-007, FR-017) |
| 5 | Double-tap the page | Controls toggle twice; no zoom (FR-017) |
| 6 | Continuous: tap the right edge, press Space and Page Down | Scrolls one screen with about one line of overlap (FR-007, FR-008) |
| 7 | Desktop Chrome keys: arrows, Page Up / Down, Space, Shift + Space, Home, End, Esc | As in contracts/reader-ui.md (FR-008) |
| 8 | Switch a book to continuous, reopen it; open another book | First keeps continuous; a new book opens paged (FR-009) |
| 9 | Read halfway down page 57, kill the app, reopen the book | Page 57 at the same position; library shows 57% of 100 (FR-011–013, SC-005) |
| 10 | Open a book last read in 001's basic view (install the 001 build, read, upgrade) | Opens on its saved page (FR-014) |
| 11 | Rotate; resize the browser; switch mode, fit and theme | Same page and position each time (FR-015) |
| 12 | Pinch in on small text; wait | Sharp within 0.5 s; pan stops at page edges; a further swipe turns the page; the next page keeps the zoom and starts top-left (FR-016–021, SC-004) |
| 13 | Zoom in and out with the buttons on the phone, and with Ctrl + wheel on the web | Zooms around the centre or pointer; limit at 5× fit width (FR-016, FR-018) |
| 14 | Drag the slider; release | Live page label; jumps on release; "Back to page N" appears (FR-022, FR-026) |
| 15 | Go to page: 120, then 0, then 999 in a 300-page book | 120 opens; the others show the range message (FR-023) |
| 16 | `outline_links.pdf`: open Contents, choose a nested chapter | Jumps; the current chapter is marked; a book without one says so (FR-024) |
| 17 | Tap an internal link, then "Back to page N" | Jumps, then returns to the exact position; the chip is gone (FR-025, FR-026) |
| 18 | Tap the web link; Cancel; tap again; Open | Shows the full address; nothing opens on Cancel; the browser opens on Open (FR-025) |
| 19 | Themes: dark and sepia on `photo.pdf` and a text page | Text recoloured; photo keeps its hues (see research R5 for the dark limit) (FR-027, FR-028) |
| 20 | Leave a book open past the screen timeout; go to the library and wait | Screen stays on in the reader, then times out normally (FR-029) |
| 21 | Search "whale" in a novel; choose a result; Next and Previous | Results stream with page and snippet; match highlighted; "match X of Y" (FR-030–032) |
| 22 | Search "cafe" in a book containing "Café" | Found (FR-030) |
| 23 | Type a new query mid-search; close search | The old search stops (FR-033) |
| 24 | Search in `scanned.pdf` | "This book has no searchable text." (FR-034) |
| 25 | Thumbnails in `long_2000.pdf`: fling the grid | Smooth; tiles fill in; opens at the current page, which is marked; choosing jumps (FR-035) |
| 26 | `mixed_sizes.pdf` in both modes | The fold-out is shown whole, in landscape, uncropped (FR-036) |
| 27 | A book with a damaged page | That page shows a placeholder; others work (FR-037) |
| 28 | Delete a book's file from storage, then open it | Message, then back to the library (FR-038) |
| 29 | Airplane mode / offline in DevTools, scenarios 1–25 | All work (FR-039, SC-008) |
| 30 | Network log (DevTools, or proxy for Android) during a session | No requests, except the browser opening a confirmed web link (FR-041) |
| 31 | System text size 200%; TalkBack through the controls | Labels read; nothing clipped; contrast AA in all themes (FR-040) |
| 32 | Performance runs (commands above) | SC-001 < 2 s for 20 and 2,000 pages; SC-002 < 200 ms; SC-003 ≤ 1% late frames; SC-004 < 500 ms; SC-006 < 1 s; SC-007 < 2 s |
| 33 | Hands-on: someone new opens the contents and switches to dark without help | SC-009 |
