/speckit.specify Build the PDF reader: the screen where users actually read a book.

Why: this is where users spend nearly all their time. It must be fast, comfortable for
long sessions, and get out of the way, while making navigation easy when needed.

User stories (in priority order):

P1 – Read comfortably. When I open a book I see the page content filling the screen with
minimal interface. Tapping the centre of the screen shows or hides the controls (top bar
with back and title, bottom bar with page slider and page number). Controls hide
automatically after a few seconds of inactivity.

P1 – Move through the book. I can move between pages by swiping horizontally, tapping the
left or right edge of the screen, or with arrow keys / Page Up / Page Down on web and
devices with keyboards. I can choose between paged mode (one page at a time) and
continuous vertical scroll, and the app remembers my choice per book.

P1 – Resume where I left off. When I leave a book and come back, even after closing the
app, I return to the same page and scroll position. Reading progress shown in the library
updates to match.

P1 – Zoom. I can pinch to zoom (or ctrl/cmd + scroll and zoom buttons on web), double-tap
to zoom into a region, and double-tap again to return. I can choose "fit width" or "fit
page" as the default view. While zoomed, I can pan around the page.

P2 – Jump to a place. I can drag the page slider to any page with a live page-number
preview. I can type a page number to jump directly. If the PDF has a table of contents
(outline), I can open it and jump to any chapter. Links inside the PDF (to other pages)
work.

P2 – Reading themes. I can choose light, dark or sepia. In dark and sepia, page colours
are adjusted so long reading is comfortable while images remain recognisable. The screen
stays awake while reading.

P2 – Search in the book. I can search for a word or phrase and see a list of results
with page numbers and surrounding text. Selecting a result jumps to it with the match
highlighted, and I can step through next and previous matches.

P3 – Page thumbnails. I can open a thumbnail grid of pages and jump to any page.

Edge cases:
- Pages with mixed sizes or orientations (e.g. a landscape fold-out) display correctly.
- Rotating the device keeps me on the same page and content position.
- A corrupted page shows a placeholder for that page; the rest of the book stays
  readable.
- Scanned PDFs (images only, no text) can be read normally; search shows a message that
  this book has no searchable text.
- On web, resizing the browser window reflows the view without losing my place.
- Very long books (2,000+ pages) open as quickly as short ones and navigation stays
  responsive.
- Back gesture or back button returns to the library and saves position.

Success criteria:
- A previously opened book shows its last-read page in under 2 seconds on a mid-range
  phone.
- Turning a page shows sharp content in under 200 ms; scrolling has no visible stutter.
- Zoomed text is re-rendered sharply (not a blurry enlarged image) within 500 ms.
- After closing and reopening the app, 100% of books resume on the correct page.
- All reading features work offline on Android, iOS and mobile and desktop web browsers.

Out of scope: highlights and notes (separate feature), dictionary lookup (separate
feature), text reflow / font-size changes for PDFs, annotations or editing the PDF,
text-to-speech, EPUB.
