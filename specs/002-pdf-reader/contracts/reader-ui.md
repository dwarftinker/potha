# Contract: Reader screen interaction

The user-facing contract of the reader screen: gestures, keys, controls and
announcements. Widget and integration tests check these rows.

## Taps (research R3)

Taps fire on pointer up with no double-tap wait. The first matching rule wins.

| Where | Paged mode | Continuous mode | Spec |
|---|---|---|---|
| On a link to a page | Jump to the page, record jump-back | Same | FR-025, FR-026 |
| On a link to a web address | Dialog: full address, "Open" / "Cancel" | Same | FR-025 |
| Outer fifth, left | Previous page | Back one screen | FR-007 |
| Outer fifth, right | Next page | Forward one screen | FR-007 |
| Anywhere else | Show or hide controls | Same | FR-002 |

A tap is one pointer, up within 300 ms and 18 logical pixels of the down point, with no
pan or zoom during the gesture. Double-tap has no meaning (FR-017).

## Swipes, pinch, wheel

| Input | Effect | Spec |
|---|---|---|
| Horizontal swipe (paged, normal view) | Turn the page if dragged past 25% of the width or flung; otherwise snap back | FR-006 |
| Drag while zoomed (paged) | Pan inside the page; a further swipe at the page edge turns the page | FR-019 |
| Vertical drag or wheel (continuous) | Scroll | FR-006 |
| Pinch | Zoom around the pinch point | FR-016 |
| Ctrl / Cmd + wheel (web) | Zoom around the pointer | FR-016 |

## Keys (focus on the reader, no text field focused)

| Key | Effect | Spec |
|---|---|---|
| Right Arrow, Page Down, Space | Forward one page (paged) or one screen (continuous) | FR-008 |
| Left Arrow, Page Up, Shift + Space | Back by the same step | FR-008 |
| Home / End | First / last page | FR-008 |
| Up / Down Arrow (continuous) | Scroll by 1/10 of the view height | FR-008 |
| Ctrl / Cmd + `=` / `-` | Zoom in / out | FR-016 |
| Esc | Close the open panel; with none open, back to the library | Edge cases |

## Controls

- **Top bar**: Back, book title (one line, ellipsis), Contents, Search, Thumbnails,
  Settings.
- **Bottom bar**: page slider with a live "Page N" label while dragging, then
  "Page N of M" (tap it for Go to page), zoom out, zoom in.
- **Jump-back chip** "Back to page N": just above the bottom bar, visible whether or not
  the controls are shown, while a jump-back exists (FR-026).
- **Settings sheet**: page mode (Paged / Continuous, per book), fit (Fit width / Fit
  page) and theme (Light / Dark / Sepia), both for all books.
- **Auto-hide**: 3 s after the last interaction with the controls; not while dragging
  the slider, while a sheet or dialog is open, or while a screen reader is on (FR-003).
- **System bars** hide and show with the controls on Android and iOS (FR-004).

## Panels

| Panel | Contents | Empty / failure state |
|---|---|---|
| Contents | Nested outline with page numbers; the current chapter marked; choose to jump | "This book has no table of contents." |
| Search | Field, streaming result list (page, snippet with the match in bold), "match X of Y", Next / Previous | "No matches." / "This book has no searchable text." |
| Thumbnails | Grid, scrolled to the current page, which is marked; choose to jump | Placeholder tile for a page that can't be rendered |
| Go to page | Number field with the range shown ("1–300") | "Enter a page from 1 to 300." |

## Accessibility (FR-040, Principle VII)

- Every control has a semantics label (for example "Back to library", "Table of
  contents", "Zoom in", "Next page" for the edge zones as custom semantic actions).
- The page view exposes "Page N of M" and actions for next and previous page, so screen
  reader users can turn pages without the edge zones.
- A page change is announced as "Page N of M".
- Control text scales with the system text size; bars wrap or scroll rather than clip
  at 200%.
- Contrast is WCAG AA for the controls in all three themes.

## Leaving the reader

Back button, back gesture, Esc or the Back control: save the position, release the
keep-awake, restore the system bars, return to the library.
