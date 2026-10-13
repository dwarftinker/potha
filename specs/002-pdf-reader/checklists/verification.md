# Verification: PDF Reader (002)

## Android: Galaxy S24 (SM-S921B, Android 16), 2026-10-12

### Device tests

| Test | Mode | Result |
|---|---|---|
| `reader_flow_test.dart`: swipe and edge-tap turns, zoom buttons (zoom kept on the next page), contents jump and "Back to page N", page link, paged → continuous keeps the page, search with "Match X of Y", rotation, leave and reopen at the same page and place | debug | Pass |
| `reader_flow_test.dart`: 20 books resume on the right page and place (SC-005) | debug | Pass, 20 of 20 |
| `reader_flow_test.dart`: a damaged page doesn't stop the book (FR-037) | debug | Pass |
| `open_resume_test.dart` (001, updated for the new reader) | debug | Pass, reopen 313 ms |
| `import_test.dart`, `import_timing_test.dart` (001) | debug | Pass, 20 MB import 1,715 ms |

### Performance (profile mode, `flutter drive`)

| Criterion | Target | Measured |
|---|---|---|
| SC-001 reopen a previously opened book | < 2 s | 144 ms (20 pages), 495 ms (2,000 pages) |
| SC-002 a page drawn sharp at screen size | < 200 ms | p90 33 ms |
| SC-003 page turns (50 swipes) | ≤ 1% late frames | 0 of 310 |
| SC-003 continuous scrolling | ≤ 1% late frames | 0 of 315 |
| SC-004 sharp redraw at 2× zoom | < 500 ms | p90 87 ms |
| SC-006 jumps in a 2,000-page book | < 1 s | 2–15 ms to the page, plus rendering it |
| SC-007 first search result, 500 pages | < 2 s | 759 ms |
| SC-007 page turns while searching | ≤ 1% late frames | 1 of 173 (0.58%) |

SC-002 and SC-004 are measured as PDFium render time for a whole page at screen width
and at twice that, which is what the viewer redraws after a turn or a zoom.

### Bugs found on the device and fixed

1. **The library's "Book added" snackbar stayed over the reader's bottom bar** after
   opening a book, covering the zoom buttons and page label. The reader now clears
   snackbars when it opens (widget test added).
2. **Switching paged → continuous jumped to page 1.** pdfrx moves to its own guess of the
   current page after a layout change, with an animation that can finish after ours. The
   view now applies the reader's position again once that has settled.
3. **A crash (null check in pdfrx) while laying out a book**: the zoom limits asked pdfrx
   for the visible area before pdfrx had a view size. Position lookups now fall back to
   the last known position, and layout no longer asks pdfrx.

The paged-mode prototype (T003) was replaced by building paged mode directly. The device
tests and frame timings above confirm it works on the S24.

## Web: Chrome on the Galaxy S24, 2026-10-12

Release build (`tool/build_web.sh`) served from the computer over `adb reverse`
(`http://localhost:8080`). The user tried it by hand: "works good mostly".

- Dark and sepia change photo colours. This is the known limit in FR-028 (research R5).
  The user chose to keep the current behaviour and wait for pdfrx colour-scheme rendering
  (`upstream-request.md`, not yet posted) rather than gentler themes or detecting photos
  ourselves.
- Wake lock (FR-029, T075): with a 30 s screen timeout, the screen stayed on with a book
  open in Chrome. Pass.

## Still to do

- T076: walk through quickstart scenarios 1–33 by hand on the S24 and in Chrome (desktop
  and phone): feel of swipes and edge taps, themes on real books, TalkBack, 200% text,
  offline, and SC-009 (someone new finds the contents and dark theme).
- iOS is not verified (constitution v2.0.0).
