/speckit.specify Build the library: the home screen where users bring their PDF books
into the app and choose what to read.

Why: before anyone can read, they need a simple, reliable way to get their own PDFs into
the app and find them again. The library should feel like a bookshelf, not a file manager.

User stories (in priority order):

P1 – Import a PDF. As a reader, I want to add a PDF from my device so I can read it in the
app. On mobile I pick a file from the device's file picker or receive one through the
system "Open with / Share to" action. On web I pick a file or drag and drop it onto the
library. After import, the book appears in my library immediately. The app keeps its own
copy, so the book stays available even if the original file is moved or deleted.

P1 – See my library. As a reader, I want to see all my books as a grid of covers with
titles so I can recognise them at a glance. The cover is the first page of the PDF. The
title comes from the PDF's metadata, falling back to the file name without extension. The
author is shown when present in metadata. Each book shows reading progress (e.g. "42%")
or "New" if never opened.

P1 – Open a book. Tapping a book opens it in the reader at the position where I last
stopped.

P2 – Sort and find. I can sort the library by recently opened (default), recently added,
or title. I can search the library by title or author, with results filtering as I type.

P2 – Remove a book. I can delete a book from the library after confirming. This removes
the app's copy, its reading progress and anything attached to it. The original file on my
device is never touched.

P3 – Grid or list view. I can switch between a cover grid and a compact list, and the app
remembers my choice.

Edge cases:
- Importing a file that is not a valid PDF shows a clear error and adds nothing.
- Password-protected PDFs ask for the password on import; if cancelled, nothing is added.
- Importing a book that's already in the library (same content) does not create a
  duplicate; the user is told it's already there and offered to open it.
- Very large PDFs (e.g. 500 MB, 2,000 pages) import with a visible progress indicator and
  can be cancelled.
- Importing several files at once is supported; failures for some files don't block the
  rest, and the user sees a summary.
- An empty library shows a friendly empty state explaining how to add a first book.
- If device storage is full, the import fails with a clear message and nothing partial is
  left behind.
- A PDF with no metadata title and a meaningless file name still gets a usable title.

Success criteria:
- A first-time user can import and open a book in under 30 seconds without instructions.
- A newly imported book appears in the library within 3 seconds for a typical 20 MB PDF.
- The library remains smooth to scroll with 500 books.
- Everything works with no network connection.
- Books and their data persist across app restarts and app updates on all three
  platforms.

Out of scope: EPUB and other formats, collections/shelves, cloud import (Google Drive,
Dropbox), sync between devices, editing metadata.
