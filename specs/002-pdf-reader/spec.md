# Feature Specification: PDF Reader

**Feature Branch**: `002-pdf-reader`

**Created**: 2026-10-12

**Status**: Draft

**Input**: User description: "Build the PDF reader: the screen where users actually read a
book. Read comfortably with minimal interface, move through the book (swipe, edge taps,
keys; paged or continuous), resume where I left off, zoom, jump to a place (slider, page
number, table of contents, links), reading themes (light, dark, sepia), search in the book,
and page thumbnails."

## Clarifications

### Session 2026-10-12

- Q: With double-tap gone, how should a phone user zoom if they can't pinch? → A: Zoom-in
  and zoom-out buttons in the controls on every platform, alongside pinch.
- Q: In continuous scroll mode, how far should an edge tap, Page Down or Space move the
  view? → A: One screen, keeping a small overlap (about one line); Home and End still go to
  the first and last page.
- Q: In paged mode, when the page is taller than the screen, what should an edge tap, Page
  Down or Space do? → A: Always turn the page; the reader drags to see the rest.
- Q: When you're zoomed in and turn to another page in paged mode, should the new page keep
  the same zoom? → A: Yes, the zoom level is kept until the book is closed; the new page is
  shown from its top-left corner.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Read comfortably (Priority: P1)

When a reader opens a book, the page fills the screen with almost no interface around it.
Tapping the centre of the screen shows or hides the controls: a top bar with Back and the
book's title, and a bottom bar with a page slider and the page number. The controls hide on
their own after a few seconds without interaction.

**Why this priority**: readers spend nearly all their time on this screen. If reading is
not comfortable, nothing else in the app matters.

**Independent Test**: open a book, confirm the page fills the screen with no controls
showing, tap the centre to show the controls, wait and confirm they hide again.

**Acceptance Scenarios**:

1. **Given** the library, **When** the reader opens a book, **Then** the page is shown
   filling the screen with the controls hidden.
2. **Given** the controls are hidden, **When** the reader taps the centre of the screen,
   **Then** the top bar (Back, title) and bottom bar (page slider, "Page N of M") appear.
3. **Given** the controls are showing, **When** the reader taps the centre again, **Then**
   they hide.
4. **Given** the controls are showing, **When** the reader does nothing for 3 seconds,
   **Then** the controls hide.
5. **Given** a screen reader is on, **When** the controls are shown, **Then** they stay
   until the reader hides them.

---

### User Story 2 - Move through the book (Priority: P1)

A reader moves between pages by swiping horizontally, tapping the left or right edge of the
screen, or with the arrow keys and Page Up / Page Down on a keyboard. They can choose
between paged mode (one page at a time) and continuous vertical scrolling, and the app
remembers the choice for each book.

**Why this priority**: turning pages is the most frequent action in a reader.

**Independent Test**: open a book in each mode and move forward and back with every input
method; reopen the book and confirm the mode was kept.

**Acceptance Scenarios**:

1. **Given** paged mode, **When** the reader swipes left, **Then** the next page is shown;
   swiping right shows the previous page.
2. **Given** paged mode, **When** the reader taps the right edge, **Then** the reader moves
   to the next page; tapping the left edge moves to the previous page. In continuous mode an
   edge tap scrolls forward or back by one screen, keeping about one line of overlap.
3. **Given** a keyboard in paged mode, **When** the reader presses Right Arrow, Page Down
   or Space, **Then** the reader moves forward one page (in continuous mode, one screen); Left Arrow or Page Up moves back one page;
   Home and End go to the first and last page.
4. **Given** continuous mode, **When** the reader scrolls vertically, **Then** pages follow
   one another with no break in scrolling, and Up / Down Arrow scroll by a small step.
5. **Given** the reader switched a book to continuous mode, **When** they reopen that book,
   **Then** it opens in continuous mode, while other books keep their own mode.
6. **Given** the first or last page, **When** the reader tries to go further, **Then**
   nothing moves and nothing breaks.

---

### User Story 3 - Resume where I left off (Priority: P1)

When a reader leaves a book and comes back, even after closing the app, they return to the
same page and the same position on that page. The progress shown in the library matches.

**Why this priority**: losing your place is the fastest way to lose trust in a reader.

**Independent Test**: read to the middle of a page partway through a book, leave the book,
close the app, reopen it, open the book, and confirm the same page and position.

**Acceptance Scenarios**:

1. **Given** a book read to halfway down page 57, **When** the reader goes back to the
   library and opens the book again, **Then** page 57 is shown at the same position.
2. **Given** the same book, **When** the app is closed (or the system ends it) and opened
   again, **Then** the book still resumes on page 57 at the same position.
3. **Given** the reader left a book on page 57 of 100, **When** they view the library,
   **Then** the book shows 57% (the progress rule from feature 001, FR-013).
4. **Given** a reading position saved in feature 001's basic page view, **When** the
   reader opens the book in the new reader, **Then** it opens on that page.

---

### User Story 4 - Zoom (Priority: P1)

A reader pinches to zoom, uses the zoom-in and zoom-out buttons in the controls, or on the
web uses Ctrl / Cmd + scroll. The reader chooses whether pages normally fit the screen width or the whole page.
While zoomed in, they can pan around the page.

**Why this priority**: PDFs have fixed layouts, so on a phone many books are unreadable
without zoom.

**Independent Test**: open a book with small text on a phone; pinch in, pan, pinch
out; switch between fit width and fit page; confirm text stays sharp when zoomed.

**Acceptance Scenarios**:

1. **Given** a page at the normal view, **When** the reader pinches out, **Then** the page
   zooms in around the pinch point, and the text becomes sharp again within half a second
   after the pinch ends.
2. **Given** a zoomed page, **When** the reader pinches in past the normal view, **Then**
   the page settles back at the normal view.
3. **Given** a zoomed page, **When** the reader drags, **Then** the page pans; in paged
   mode a horizontal swipe turns the page only once the page edge is reached.
4. **Given** the controls are showing on any platform, **When** the reader uses the zoom-in
   or zoom-out button, **Then** the page zooms around the centre of the screen; on the web,
   holding Ctrl (Cmd on a Mac) and scrolling also zooms.
5. **Given** the reader chose "fit page", **When** they open any book, **Then** each page is
   shown whole; with "fit width", each page fills the screen width.

---

### User Story 5 - Jump to a place (Priority: P2)

A reader drags the page slider to any page, with the page number shown live while dragging.
They can type a page number to jump straight to it. If the book has a table of contents,
they can open it and jump to any chapter. Links inside the book that point to other pages
work.

**Why this priority**: long books need fast navigation, but readers mostly read forward.

**Independent Test**: in a book with a table of contents and internal links, jump with the
slider, by typed page number, from the contents, and by following a link.

**Acceptance Scenarios**:

1. **Given** the controls are showing, **When** the reader drags the slider, **Then** the
   target page number is shown while dragging, and releasing jumps to that page.
2. **Given** the reader opens "Go to page" and types 120 in a 300-page book, **When** they
   confirm, **Then** page 120 is shown; a number outside 1–300 is rejected with a message.
3. **Given** a book with a table of contents, **When** the reader opens it, **Then** the
   chapters are listed with their nesting and page numbers, and choosing one jumps there.
4. **Given** a book without a table of contents, **When** the reader looks for it, **Then**
   the app says this book has no table of contents.
5. **Given** a page with a link to another page in the book, **When** the reader taps the
   link, **Then** the reader jumps to the linked page.
6. **Given** the reader jumped with the contents, a link, search or "Go to page", **When**
   they choose "Back to page N", **Then** they return to where they were before the jump.
   Only the most recent jump can be undone; a second jump replaces the way back.

---

### User Story 6 - Reading themes (Priority: P2)

A reader chooses light, dark or sepia. In dark and sepia, page colours are adjusted so long
reading is comfortable, while pictures still look like themselves. The screen stays awake
while reading.

**Why this priority**: comfort for long and night-time sessions, after the core reading
experience works.

**Independent Test**: open a book with text and photos, switch between the three themes,
and leave the book open longer than the device's screen timeout.

**Acceptance Scenarios**:

1. **Given** the dark theme, **When** a page with black text on white is shown, **Then**
   the page appears as light text on a dark background.
2. **Given** the dark or sepia theme, **When** a page with a colour photo is shown, **Then**
   the photo keeps recognisable colours (it is not shown as a negative).
3. **Given** the sepia theme, **When** a page is shown, **Then** the background is a warm
   paper tone and the text dark brown-grey.
4. **Given** a theme was chosen, **When** the reader opens any book, **Then** that theme is
   used.
5. **Given** a book is open and the reader is not touching the screen, **When** the
   device's normal screen timeout passes, **Then** the screen stays on.

---

### User Story 7 - Search in the book (Priority: P2)

A reader searches for a word or phrase and sees a list of results with page numbers and the
surrounding text. Choosing a result jumps to it with the match highlighted, and they can
step through the next and previous matches.

**Why this priority**: valuable for study and reference books, less so for straight
reading.

**Independent Test**: search a text book for a word that appears several times; check the
list, jump to a result, step forwards and backwards; search a scanned book.

**Acceptance Scenarios**:

1. **Given** a book with text, **When** the reader searches for "whale", **Then** results
   appear as they are found, each with its page number and a line of text around the match.
2. **Given** search results, **When** the reader chooses one, **Then** the reader jumps to
   that page with the match highlighted.
3. **Given** a highlighted match, **When** the reader chooses Next or Previous, **Then** the
   reader moves to the next or previous match, across pages, and shows "match X of Y".
4. **Given** a search with no matches, **When** it finishes, **Then** the reader is told
   nothing was found.
5. **Given** a scanned book with no text layer, **When** the reader opens search, **Then**
   they are told this book has no searchable text.
6. **Given** a search is running on a long book, **When** the reader closes search or types
   something else, **Then** the old search stops.

---

### User Story 8 - Page thumbnails (Priority: P3)

A reader opens a grid of small page images and jumps to any page.

**Why this priority**: useful for picture-heavy books and for finding a page by its look;
the slider and contents cover most needs.

**Independent Test**: open the thumbnail grid in a long book, scroll it, and choose a page.

**Acceptance Scenarios**:

1. **Given** a book, **When** the reader opens thumbnails, **Then** a grid of page images
   with page numbers is shown, scrolled to the current page, which is marked.
2. **Given** the grid, **When** the reader chooses a page, **Then** the reader jumps there.
3. **Given** a 2,000-page book, **When** the reader scrolls the grid quickly, **Then** it
   scrolls smoothly, and page images fill in as they become ready.

---

### Edge Cases

- **Mixed page sizes and orientations** (for example a landscape fold-out): each page is
  shown at its own size and orientation, scaled by the fit setting, without cropping.
- **Rotation**: rotating the device keeps the reader on the same page and the same content
  position.
- **Corrupted page**: a page that cannot be shown displays a placeholder saying so; the rest
  of the book stays readable and navigation still works.
- **Scanned PDFs**: books with only images read normally; search says the book has no
  searchable text.
- **Browser resize (web)**: resizing the window re-lays out the view without losing the
  reader's place.
- **Very long books (2,000+ pages)**: open as quickly as short ones; slider, contents,
  search and thumbnails stay responsive.
- **Back**: the back gesture, back button or Esc returns to the library and saves the
  position.
- **App sent to the background or killed**: the position is saved, at most one second's
  reading is lost.
- **Removed or unreadable book file**: opening it shows a clear message and returns to the
  library instead of an empty screen.
- **Password-protected books**: open with the password saved at import (feature 001,
  FR-028); if it no longer works, the reader is asked for it.
- **External links** (to web addresses) inside a PDF: tapping one shows the full address
  and asks for confirmation; only then does it open in the browser (FR-025). Offline, the
  browser handles the failure; the reader is unaffected.

## Requirements *(mandatory)*

### Functional Requirements

**Reading view and controls**

- **FR-001**: Opening a book MUST show its page filling the reading area, with the controls
  hidden.
- **FR-002**: Tapping the centre of the screen MUST show or hide the controls: a top bar
  with Back and the book title, and a bottom bar with a page slider and "Page N of M".
- **FR-003**: Shown controls MUST hide after 3 seconds without interaction, except while the
  reader is using a control, a panel (contents, search, thumbnails, settings) is open, or a
  screen reader is on.
- **FR-004**: On phones and tablets, the system status and navigation bars MUST hide and
  show together with the reader's controls.
- **FR-005**: The reading screen MUST offer the reader settings (page mode, fit, theme)
  from the controls.

**Moving through the book**

- **FR-006**: The reader MUST support two page modes: paged (one page at a time, moved by a
  horizontal swipe) and continuous (pages in one vertical scroll).
- **FR-007**: Tapping the left or right edge of the screen (the outer fifth on each side)
  MUST move back or forward: by one page in paged mode, and by one screen in continuous
  mode, keeping about one line of the previous screen visible. In paged mode this holds even
  when the page is taller than the screen (zoomed in, or fit width on a wide screen): the
  page turns, and the new page is shown from its top-left corner; the reader drags to see the rest of
  a tall page.
- **FR-008**: With a keyboard, Right Arrow, Page Down and Space MUST move forward and Left
  Arrow and Page Up back, by the same step as an edge tap (FR-007); Home and End go to the
  first and last page. In continuous mode Up and Down Arrow MUST scroll by a small step.
- **FR-009**: The page mode MUST be remembered per book. A book opened for the first time
  opens in paged mode.
- **FR-010**: Moving past the first or last page MUST do nothing.

**Resume**

- **FR-011**: The reader MUST save the current page and the position within that page while
  reading, at least once a second while the position changes, and when the reader leaves the
  book or the app goes to the background.
- **FR-012**: Opening a book MUST show the saved page at the saved position within the page,
  or the first page if the book has never been opened.
- **FR-013**: Progress in the library MUST follow the saved page using feature 001's rule
  (001 FR-013).
- **FR-014**: Positions saved by feature 001's basic page view MUST keep working: such a book
  opens on its saved page.
- **FR-015**: Rotating the device, resizing the window, switching page mode, changing the
  fit, or changing the theme MUST keep the reader on the same page and content position.

**Zoom**

- **FR-016**: Readers MUST be able to pinch to zoom on touch screens, use zoom-in and
  zoom-out buttons in the controls on every platform, and on the web zoom with Ctrl / Cmd +
  scroll. The buttons are the one-finger and screen-reader alternative to pinch.
- **FR-017**: Double-tap MUST NOT be a reader gesture. A single tap MUST act at once,
  without waiting to see whether a second tap follows.
- **FR-018**: Zoom MUST range from the whole page fitting the screen up to at least 5 times
  the fit-width size.
- **FR-019**: While zoomed, dragging MUST pan the page. In paged mode a horizontal swipe MUST
  turn the page only when the visible area is already at that edge of the page.
- **FR-020**: After zooming stops, the visible text MUST be redrawn sharply at the new size,
  not shown as an enlarged blurry image.
- **FR-021**: The reader MUST offer "fit width" and "fit page" as the normal view, chosen
  once for all books. While a book is open, the zoom level stays the same across page turns
  and jumps until the reader changes it. Reopening a book shows it at the normal view; zoom
  is not restored.

**Jumping**

- **FR-022**: Dragging the page slider MUST show the target page number live and jump to
  that page on release.
- **FR-023**: "Go to page" MUST accept a page number and jump to it; numbers outside the
  book's range MUST be rejected with a message.
- **FR-024**: If the book has a table of contents, the reader MUST show it with its nesting
  and page numbers, mark the current chapter, and jump to an entry when chosen. If it has
  none, the reader MUST say so.
- **FR-025**: Tapping a link to another page in the same book MUST jump to that page.
  Tapping a link to a web address MUST show the full address and open it in the browser
  only if the reader confirms; nothing leaves the device without that confirmation.
- **FR-026**: After a jump (contents, link, search, "Go to page", slider), the reader MUST
  offer "Back to page N" to return to the exact previous position. There is one step only:
  a new jump replaces it, and it goes away once used or when the book is closed.

**Themes and comfort**

- **FR-027**: The reader MUST offer light, dark and sepia themes, chosen once for all books.
  The reader's controls follow the chosen theme.
- **FR-028**: In dark and sepia, page backgrounds and text MUST be recoloured to the theme,
  while photographs and illustrations keep recognisable colours and are never shown as
  negatives.
- **FR-029**: The screen MUST stay on while a book is open in the foreground, with no idle
  limit, and return to the device's normal behaviour when the reader leaves the book or the
  app goes to the background.

**Search**

- **FR-030**: Readers MUST be able to search a book for a word or phrase. Matching ignores
  upper and lower case and accents.
- **FR-031**: Results MUST appear as they are found, each with its page number and the text
  around the match, without blocking reading.
- **FR-032**: Choosing a result MUST jump to it and highlight the match. Next and Previous
  MUST move between matches across pages and show "match X of Y" (Y may grow while the search
  is still running).
- **FR-033**: Starting a new search or closing search MUST stop the previous search.
- **FR-034**: If no page in the book has text, search MUST say the book has no searchable
  text instead of searching.

**Thumbnails**

- **FR-035**: The reader MUST offer a grid of page thumbnails with page numbers, opened at
  the current page with that page marked; choosing one MUST jump to it.

**Robustness**

- **FR-036**: Pages of different sizes and orientations MUST each be shown at their own
  aspect ratio, uncropped.
- **FR-037**: A page that fails to render MUST show a placeholder saying the page cannot be
  shown; other pages and navigation MUST keep working.
- **FR-038**: If the book's file is missing or cannot be opened, the reader MUST show a
  clear message and return to the library.

**Platforms, accessibility and privacy**

- **FR-039**: All reader features MUST work offline on Android, iOS, and desktop and mobile
  web browsers.
- **FR-040**: All reader controls MUST have screen-reader labels; the current page MUST be
  announced as "Page N of M" when it changes; control text MUST respect the system text
  size and meet WCAG AA contrast in every theme.
- **FR-041**: The reader MUST NOT send the book, its text, search terms or reading
  position off the device.

### Key Entities

- **Reading position**: per book. The current page, the position within that page, and when
  it was last saved. Extends feature 001's saved page; the library's progress label is
  derived from it.
- **Book reading settings**: per book. The page mode (paged or continuous).
- **Reader preferences**: one set for the app. Theme (light, dark, sepia) and normal view
  (fit width or fit page).
- **Table of contents entry**: read from the book. A title, its target page, and nested
  entries.
- **Search result**: temporary. Page number, the text around the match, and where on the
  page the match is, for highlighting.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: A previously opened book shows its last-read page in under 2 seconds on a
  mid-range phone, for a 20-page book and a 2,000-page book alike.
- **SC-002**: Turning a page shows sharp content in under 200 ms.
- **SC-003**: Scrolling and page turns show no visible stutter: at most 1 frame in 100 is
  late on a mid-range phone at 60 frames per second.
- **SC-004**: After a zoom gesture ends, the visible text is sharp within 500 ms.
- **SC-005**: Across a test set of 20 books left at varied positions, 100% resume on the
  correct page and position after the app is closed and reopened, and after the device is
  rotated.
- **SC-006**: Jumping by slider, page number, contents entry or thumbnail shows the target
  page in under 1 second, including in a 2,000-page book.
- **SC-007**: In a 500-page book with text, the first search results appear within 2
  seconds, and reading stays responsive while the search runs.
- **SC-008**: Every reader feature works with no network connection on Android, iOS, and a
  desktop and a mobile web browser.
- **SC-009**: In a hands-on test, a first-time reader can open the table of contents and
  jump to a chapter, and switch to dark theme, without help.

## Assumptions

- This reader replaces feature 001's basic page view; tapping a book in the library opens
  it here.
- Reading position, page mode, theme and fit are stored on this device only; cross-device
  sync is out of scope.
- Theme and fit apply to all books; only the page mode is per book. The reader's theme is
  separate from the app's light and dark theme, which follows the system.
- Pages are shown one at a time in paged mode, also in landscape; two-page spreads are out
  of scope.
- Books are read left to right; right-to-left page order is out of scope.
- The position within a page is kept as a proportion of the page, so it survives rotation,
  window resizing and a change of fit.
- Zoom level is not restored when a book is reopened; the page opens at the normal view.
- There is no double-tap zoom, so single taps (and tap-to-define in feature 003) never wait
  for a possible second tap. Zoom is by pinch, the zoom buttons, and Ctrl / Cmd + scroll
  on the web.
- Text selection is not part of this feature; it arrives with dictionary lookup (003) and
  highlights (004).
- "Mid-range phone" is the same reference as in feature 001. iOS is a supported target but
  is not verified before merge (constitution v2.0.0, Principle I).

## Out of Scope

- Highlights and notes (feature 004)
- Dictionary lookup and text selection (feature 003)
- Text reflow or font-size changes for PDFs
- Annotating or editing PDFs
- Text-to-speech
- EPUB (feature 006)
- Two-page spreads and right-to-left reading
- Printing and sharing pages
- Double-tap to zoom (FR-017)
- A full back and forward history of jumps (only one "Back to page N" step, FR-026)
