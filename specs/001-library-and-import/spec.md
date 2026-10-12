# Feature Specification: Library and Import

**Feature Branch**: `001-library-and-import`

**Created**: 2026-10-11

**Status**: Draft

**Input**: User description: "Build the library: the home screen where users bring their PDF
books into the app and choose what to read. Import a PDF (file picker, Open with / Share to on
mobile, file picker or drag and drop on web), see the library as a grid of covers with title,
author and progress, open a book where I left off, sort and search, remove a book, and switch
between grid and list view."

## Clarifications

### Session 2026-10-11

- Q: What should tapping a book do in feature 001, given that the real reader is feature
  002? → A: 001 includes a basic page view (scroll through pages, no zoom or selection)
  and saves the last page, so resume works in 001.
- Q: How should the library work out a book's reading percentage? → A: Current page ÷
  total pages (the page where the reader last stopped; it can go down if they flip back).
- Q: On the web, should importing a 500 MB PDF be required to work, or can the web version
  have a lower size limit? → A: Web limit of 100 MB; larger files show a clear "too large
  for the web version" message.
- Q: How long should an import run before the app shows a progress bar and a Cancel
  button? → A: After 1 second.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Import a PDF (Priority: P1)

A reader adds a PDF from their device so they can read it in the app. On a phone or tablet
they pick a file with the system file picker, or send one to the app from another app with
"Open with" or "Share to". On the web they pick a file or drag and drop it onto the library.
The book appears in the library straight away. The app keeps its own copy, so the book stays
available even if the original file is moved or deleted.

**Why this priority**: nothing else in the app works until a book is in it. This is the
entry point for every reader.

**Independent Test**: import a PDF through each entry point on each platform, then move or
delete the original file and confirm the book is still in the library and still opens.

**Acceptance Scenarios**:

1. **Given** an empty library, **When** the reader picks a valid PDF with the file picker,
   **Then** the book appears in the library with its cover and title.
2. **Given** another app on a phone is showing a PDF, **When** the reader chooses "Open with"
   or "Share to" and selects the app, **Then** the app opens and the book is added to the
   library.
3. **Given** the library is open in a web browser, **When** the reader drags a PDF onto it,
   **Then** the book is added to the library.
4. **Given** a book was imported, **When** the original file is moved or deleted from the
   device, **Then** the book still appears in the library and still opens.
5. **Given** the reader picks several files at once, **When** some of them fail to import,
   **Then** the valid ones are added and the reader sees a summary of what was added, what
   was already there and what failed, with the reason for each failure.
6. **Given** the reader picks a file that is not a valid PDF, **When** the import runs,
   **Then** the reader sees a clear error and nothing is added.

---

### User Story 2 - See my library (Priority: P1)

A reader sees all their books as a grid of covers with titles, so they can recognise them at
a glance. The cover is the first page of the PDF. The title comes from the PDF's own
metadata, or from the file name without its extension when the metadata has no title. The
author is shown when the metadata includes one. Each book shows its reading progress (for
example "42%"), or "New" if it has never been opened.

**Why this priority**: the library is the home screen. It is how readers find their books
and decide what to read.

**Independent Test**: import PDFs with and without title and author metadata, open some of
them, and confirm the grid shows the right cover, title, author and progress label for each.

**Acceptance Scenarios**:

1. **Given** a PDF with a title and author in its metadata, **When** it is imported,
   **Then** its library entry shows the first page as the cover, that title and that author.
2. **Given** a PDF with no title in its metadata, **When** it is imported, **Then** its title
   is the file name without the extension.
3. **Given** a book that has never been opened, **When** the reader views the library,
   **Then** the book is labelled "New".
4. **Given** a book the reader has read partway, **When** the reader views the library,
   **Then** the book shows its progress as a whole percentage.
5. **Given** the library is empty, **When** the reader opens the app, **Then** they see a
   friendly empty state that explains how to add a first book and offers a way to do it.

---

### User Story 3 - Open a book (Priority: P1)

Tapping (or clicking) a book opens it in the reader at the position where the reader last
stopped. A book that has never been opened starts at the first page.

**Why this priority**: the library exists to get readers back into their books quickly.

**Independent Test**: open a book, move to a later page, return to the library, close and
reopen the app, then open the same book and confirm it resumes at that page.

**Acceptance Scenarios**:

1. **Given** a book labelled "New", **When** the reader taps it, **Then** it opens at the
   first page.
2. **Given** a book last left on page 57, **When** the reader taps it, **Then** it opens at
   page 57, also after the app has been closed and reopened.

---

### User Story 4 - Sort and find (Priority: P2)

A reader sorts the library by recently opened (the default), recently added, or title. They
can search by title or author, and the results narrow as they type.

**Why this priority**: valuable once a library grows beyond a screenful, but a small library
works without it.

**Independent Test**: with at least ten books, change the sort order and confirm the order
of books; type part of a title or author and confirm only matching books remain.

**Acceptance Scenarios**:

1. **Given** a library with several books, **When** the reader opens the app for the first
   time, **Then** books are sorted by most recently opened, with never-opened books after
   opened ones, ordered by most recently added.
2. **Given** the reader selects "Title", **When** the library is shown, **Then** books are
   in alphabetical order by title, ignoring case and leading "The", "A" or "An".
3. **Given** the reader types "tolst" in search, **When** the library updates, **Then** only
   books whose title or author contains "tolst" (ignoring case and accents) are shown.
4. **Given** a search with no matches, **When** the library updates, **Then** the reader
   sees a "no books match" message with a way to clear the search.
5. **Given** the reader chose a sort order, **When** they reopen the app, **Then** the same
   sort order is used.

---

### User Story 5 - Remove a book (Priority: P2)

A reader deletes a book from the library after confirming. This removes the app's copy, its
reading progress and anything else attached to it. The original file on the device is never
touched.

**Why this priority**: readers need to tidy their library and free space, but it is not
needed for a first reading session.

**Independent Test**: delete a book, confirm it disappears, its storage is freed, and the
original file on the device is unchanged; re-import it and confirm it is labelled "New".

**Acceptance Scenarios**:

1. **Given** a book in the library, **When** the reader chooses to remove it, **Then** they
   are asked to confirm, and the confirmation names the book.
2. **Given** the confirmation is shown, **When** the reader cancels, **Then** nothing
   changes.
3. **Given** the reader confirms, **When** the removal completes, **Then** the book, its
   cover, its reading progress and any data attached to it are gone, and the original file
   on the device is unchanged.
4. **Given** a removed book, **When** the reader imports the same file again, **Then** it
   is treated as a new book with no progress.

---

### User Story 6 - Grid or list view (Priority: P3)

A reader switches between a cover grid and a compact list. The app remembers the choice.

**Why this priority**: a comfort feature; the grid alone meets the core need.

**Independent Test**: switch to list view, restart the app, and confirm the library is still
in list view.

**Acceptance Scenarios**:

1. **Given** the grid view, **When** the reader switches to list view, **Then** each book
   is shown as a row with a small cover, title, author and progress.
2. **Given** the reader chose list view, **When** they reopen the app, **Then** the library
   is in list view.

---

### Edge Cases

- A file that is not a valid PDF (or is damaged) shows a clear error, and nothing is added.
- A password-protected PDF asks for the password during import. A wrong password lets the
  reader try again. If the reader cancels, nothing is added.
- Importing a book already in the library (identical file content, whatever its name) does
  not create a duplicate. The reader is told it is already there and offered to open it.
- A very large PDF (for example 500 MB or 2,000 pages) imports on Android and iOS with a
  visible progress indicator and can be cancelled. Cancelling leaves nothing behind.
- On the web, a PDF larger than 100 MB is rejected before any copying starts, with a clear
  message that it is too large for the web version and can be read in the mobile app.
- When several files are imported at once, a failure in one does not stop the others, and
  the reader sees a summary at the end.
- If the device (or the browser's storage allowance on the web) runs out of space, the
  import fails with a clear message and nothing partial is left behind.
- A PDF with no metadata title and an unhelpful file name (for example `scan_0001.pdf` or
  `download (3).pdf`) still gets a readable title (see FR-010).
- A PDF whose first page cannot be drawn still appears, with a plain placeholder cover
  showing its title.
- A PDF with no text layer (a scanned book) imports normally. Telling the reader that word
  lookup won't work for it is part of the reader and dictionary features.
- If the app is closed during an import, the next launch shows no half-imported book.
- On the web, books are kept in the browser's storage for this site. If the reader clears
  the browser's site data, the library is emptied. The app warns about this once, the first
  time a book is added on the web.

## Requirements *(mandatory)*

### Functional Requirements

**Import**

- **FR-001**: Readers MUST be able to import one or more PDF files at once with the system
  file picker on Android, iOS and web.
- **FR-002**: On Android and iOS, the app MUST accept PDFs sent from other apps via the
  system "Open with" and "Share to" actions, and add them to the library.
- **FR-003**: On the web, readers MUST be able to drag and drop one or more PDF files onto
  the library to import them.
- **FR-004**: The app MUST store its own copy of each imported book, so the book stays
  available after the original file is moved, renamed or deleted.
- **FR-005**: The app MUST check that each file is a readable PDF before adding it, and
  MUST show a clear, specific error for any file it rejects.
- **FR-006**: The app MUST ask for the password of a password-protected PDF during import,
  allow retries after a wrong password, and add nothing if the reader cancels.
- **FR-007**: The app MUST detect a file whose content is identical to a book already in the
  library, MUST NOT add a duplicate, and MUST offer to open the existing book.
- **FR-008**: When an import has been running for more than 1 second, the app MUST show
  its progress and a Cancel button. Faster imports show no progress indicator. Cancelled, failed or interrupted imports MUST leave no trace in the
  library or in storage.
- **FR-008a**: On the web, the app MUST reject PDFs larger than 100 MB (104,857,600
  bytes) before copying anything, with a message saying the file is too large for the web
  version. On Android and iOS there is no app-imposed size limit.
- **FR-009**: After a multi-file import, the app MUST show a summary listing which books
  were added, which were already in the library, and which failed and why.

**Library display**

- **FR-010**: The app MUST give each book a title: the PDF's metadata title if present and
  not blank; otherwise the file name without its extension, with underscores and repeated
  spaces tidied; and if that contains no letters, "Untitled book" followed by the date it
  was added.
- **FR-011**: The app MUST show the author from the PDF's metadata when present, and show
  nothing in its place when absent.
- **FR-012**: The app MUST use an image of the first page as each book's cover, and a
  placeholder cover showing the title when the first page cannot be drawn.
- **FR-013**: The app MUST label each book with its reading progress as a whole percentage,
  or "New" if it has never been opened. Progress is the current page (where the reader last
  stopped) divided by the total number of pages, rounded down, except that the last page
  shows 100%. Progress goes down if the reader moves back to an earlier page.
- **FR-014**: The app MUST show an empty state with a short explanation and an import action
  when the library has no books.
- **FR-015**: A newly imported book MUST appear in the library as soon as its import
  finishes, without the reader having to refresh.

**Opening**

- **FR-016**: Selecting a book MUST open it in the basic page view at the page where the
  reader last stopped, or at the first page if it has never been opened.
- **FR-016a**: This feature MUST provide a basic page view for opening books: pages shown
  in order, scrolling between them, and a way back to the library. Zoom, text selection and
  other reading tools are not part of this feature.
- **FR-016b**: The basic page view MUST save the page where the reader last stopped (the
  current page, which can go down if they move back), so the book resumes there and the
  library shows its progress.

**Sort and search**

- **FR-017**: Readers MUST be able to sort the library by recently opened (default),
  recently added, or title (A–Z, ignoring case and a leading "The", "A" or "An").
- **FR-018**: Readers MUST be able to search by title or author. Results MUST update as they
  type, and matching MUST ignore case and accents.
- **FR-019**: The app MUST remember the chosen sort order and view mode across restarts.

**Removal**

- **FR-020**: Readers MUST be able to remove a book after confirming in a prompt that names
  the book.
- **FR-021**: Removing a book MUST delete the app's copy, its cover, its reading progress and
  any other data attached to it (including a remembered password), and MUST NOT modify or delete the original file on the
  device.

**View mode**

- **FR-022**: Readers MUST be able to switch between a cover grid and a compact list.

**General**

- **FR-023**: All library features MUST work with no network connection.
- **FR-024**: Books and their data MUST persist across app restarts and app updates on
  Android, iOS and web.
- **FR-025**: All library controls MUST have screen-reader labels, and library text MUST
  respect the system text-size setting, in light and dark themes.
- **FR-026**: The app MUST NOT send books, their metadata or the library contents off the
  device.
- **FR-027**: On the web, the app MUST tell the reader once, the first time they add a book,
  that clearing the browser's site data removes their library.
- **FR-028**: For a password-protected book, the app MUST remember the password on this
  device after a successful import, kept in the platform's secure storage, so the book
  opens without asking again. The password MUST never leave the device and MUST be deleted
  when the book is removed. If the stored password stops working, the app MUST ask for it
  again.

### Key Entities

- **Book**: a PDF the reader has imported. Has a title, an optional author, a cover image,
  the date added, the date last opened (if any), its page count, a content fingerprint used
  to spot duplicates, and whether it is password-protected. Owns the app's stored copy of
  the file.
- **Reading progress**: where the reader is in a book. Belongs to one book. Holds the current
  page (where the reader last stopped); the percentage is derived from it and the page count. Absent for books never opened.
- **Library preferences**: the reader's chosen sort order and view mode. One per device.
- **Import result**: the outcome of importing one file in a batch: added, already in
  library, or failed with a reason. Shown in the import summary; not kept afterwards.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: A first-time reader can import a PDF and start reading it in under 30 seconds,
  without instructions.
- **SC-002**: A typical 20 MB PDF appears in the library within 3 seconds of the reader
  choosing it, on a mid-range phone.
- **SC-003**: With 500 books, scrolling the library shows no visible stutter on a mid-range
  phone.
- **SC-004**: Search results update within half a second of each keystroke with 500 books.
- **SC-005**: Every library feature works with the device in airplane mode.
- **SC-006**: After a restart and after an app update, 100% of books, their progress and the
  reader's preferences are still there on Android and web.
- **SC-007**: In testing, no cancelled, failed or interrupted import ever leaves a partial
  book in the library or orphaned data in storage.
- **SC-008**: Removing a book never changes the original file on the device.

## Assumptions

- "Same content" for duplicate detection means byte-identical files. Two different editions
  or scans of the same book are separate books.
- The full reader (zoom, navigation tools, text selection) is feature 002. It replaces the
  basic page view from this feature and keeps saving the last page in the same way.
- Reading position resumes on the same device only; cross-device sync is out of scope.
- On Android and iOS there is no size limit beyond the device's free space. On the web the
  limit is 100 MB per book (FR-008a), and the browser's storage allowance still applies. On the web, the app asks the browser to keep its storage persistent where the
  browser supports it.
- "Open with" and "Share to" apply to Android and iOS only; the web uses the file picker and
  drag and drop.
- Scanned PDFs import like any other PDF; detecting a missing text layer belongs to the
  reader and dictionary features.
- The "Untitled book" fallback uses the reader's local date format.
- iOS is a supported target but is not verified before merge (constitution v2.0.0,
  Principle I).

## Out of Scope

- EPUB and other formats
- Collections or shelves
- Importing from cloud storage (Google Drive, Dropbox)
- Sync between devices
- Editing book metadata (title, author, cover)
