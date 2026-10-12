# Research: Library and Import

**Feature**: 001-library-and-import | **Date**: 2026-10-11

Package versions were checked on pub.dev on 2026-10-11. Pin each dependency to a release
that is at least two weeks old when it is added.

## R1. PDF title and author metadata

- **Decision**: Write a small pure-Dart, best-effort PDF metadata reader
  (`PdfMetadataReader`) that reads the document Info dictionary (`/Title`, `/Author`) and
  falls back to XMP (`dc:title`, `dc:creator`). It handles classic xref tables,
  cross-reference streams and compressed object streams (Flate), and decodes PDF text
  strings (PDFDocEncoding, UTF-16BE with BOM, escapes and hex strings). For encrypted PDFs
  it returns nothing, and the title falls back to the file name (FR-010). It never throws:
  any parse failure means "no metadata".
- **Rationale**: pdfrx 2.6.5 / pdfrx_engine 0.6.1 does not expose document metadata. The
  native `FPDF_DOCUMENT` handle is private, and the web worker (`pdfium_worker.js`) has a
  fixed command table with no metadata command, although `pdfium.wasm` contains
  `FPDF_GetMetaText`. A pure-Dart reader runs the same on all three platforms and is easy
  to unit-test with fixture PDFs (Principle IV).
- **Follow-up**: Open an issue or PR upstream asking pdfrx to expose `FPDF_GetMetaText`.
  When it ships, replace the reader's internals behind the same interface.
- **Alternatives considered**:
  - Fork pdfrx to add a metadata command: a maintenance burden across native and WASM.
  - Syncfusion PDF library for metadata only: a commercial licence and a large dependency
    for two strings (Principle VIII).
  - Skip metadata and always use the file name: contradicts the spec (User Story 2).

## R2. Local database

- **Decision**: drift (2.35.x) with `drift_flutter` (0.3.x) and `drift_dev` +
  `build_runner` for code generation. On the web, use `driftDatabase(web: …)` with
  `sqlite3.wasm` and `drift_worker.js` copied into `web/`. Drift picks OPFS or IndexedDB
  storage automatically. Use in-memory native databases in tests.
- **Rationale**: Already chosen in CLAUDE.md. Type-safe queries, migrations for app
  updates (FR-024), reactive streams so the library updates when an import finishes
  (FR-015), and the same code on mobile and web. MIT licence, actively maintained.
- **Alternatives considered**: sqflite (no web support); Hive or Isar (no relational
  queries, weaker migration story).

## R3. Book file storage

- **Decision**: A `BookFileStore` interface with two implementations chosen by
  conditional import:
  - Android and iOS: files under `<app support dir>/books/<bookId>.pdf` via
    `path_provider`, with a `staging/` folder for imports in progress.
  - Web: OPFS (`navigator.storage.getDirectory()`) via `package:web`, writing with
    `createWritable()` in chunks. If OPFS writing is unavailable, store the file as a Blob
    in IndexedDB. Call `navigator.storage.persist()` once on first import.
  The application support directory is used instead of the documents directory so books
  are not exposed in the iOS Files app or backed up as user documents.
- **Rationale**: Principle I permits platform code behind an interface for file storage.
  Writing in chunks keeps memory flat for 500 MB books on mobile and 100 MB on the web.
- **Alternatives considered**: Storing PDFs as BLOBs in SQLite (inflates the database,
  slow backups, memory pressure); a third-party web file-system package (none mature
  enough to justify the dependency).

## R4. Import pipeline and atomicity

- **Decision**: Each file goes through these steps:
  1. Check the size (web: reject over 100 MB, FR-008a).
  2. Stream it into `staging/<tmpId>.pdf`, computing SHA-256 while copying.
  3. Check for a duplicate by hash (FR-007); if found, delete the staged file.
  4. Open it with pdfrx, asking for the password if needed.
  5. Read the page count and metadata, and render the cover.
  6. In one database transaction, insert the book and its cover, then move the staged
     file to its final name.
  On startup, delete everything in `staging/` and any book file that has no database row.
  Cancelling stops the stream and deletes the staged file.
- **Rationale**: Gives "nothing partial is left behind" for cancel, failure, full storage
  and app kill (FR-008, SC-007) without a journal. The database row is the commit point.
- **Alternatives considered**: Hashing before copying (reads the file twice); writing the
  database row first and the file second (leaves rows without files after a crash).

## R5. Duplicate detection

- **Decision**: SHA-256 over the full file content using `package:crypto` in chunked mode,
  stored as a unique column.
- **Rationale**: The spec defines duplicates as byte-identical files. Chunked hashing runs
  during the copy, so it costs no extra read.
- **Alternatives considered**: Hashing only the first N MB plus the size (cheaper, but can
  collide); comparing pdfrx document IDs (not exposed).

## R6. Covers

- **Decision**: Render page 1 with pdfrx at 360 px wide, encode it as PNG with `dart:ui`
  (`Image.toByteData(format: png)`), and store it as a BLOB in a separate `book_covers`
  table written in the same transaction as the book. If rendering fails, store no cover and
  draw a placeholder showing the title (FR-012).
- **Rationale**: Keeping covers in the database makes them part of the atomic insert and
  delete. The library never needs PDFium to display covers, so the library screen loads
  without the PDF engine on the web (see R10). About 40–80 KB per cover is roughly 40 MB
  for 500 books, which is acceptable.
- **Alternatives considered**: Cover files next to the PDF (a second file to keep
  consistent); rendering covers on demand (needs PDFium on the library screen and makes
  scrolling slow).

## R7. Receiving files from other apps

- **Decision**: `receive_sharing_intent` (1.9.x, Apache-2.0, Android and iOS) for both
  "Share to" and "Open with", including files received when the app is not running.
  Android: intent filters for `ACTION_VIEW` and `ACTION_SEND`/`ACTION_SEND_MULTIPLE` with
  `application/pdf`. iOS: a Share Extension target plus `CFBundleDocumentTypes` for PDF.
- **Rationale**: One maintained package covers both platforms and both entry points.
- **Risk**: The iOS Share Extension needs Xcode project changes that cannot be built or
  verified without a Mac (constitution v2.0.0). Implement it as described in the package
  docs and mark it unverified.
- **Alternatives considered**: `share_handler` (last release 2025-07, less active);
  writing platform channels by hand (more native code to maintain).

## R8. Web drag and drop

- **Decision**: `desktop_drop` (0.8.x, Apache-2.0, supports the web): wrap the library
  in a `DropTarget` and show a visible drop zone while a file is dragged over it.
- **Rationale**: Small, maintained, and gives `XFile`s like the file picker, so both go
  through the same import pipeline.
- **Alternatives considered**: Raw DOM drag events via `package:web` (about 40 lines of
  interop, but more to test); `super_drag_and_drop` (heavier, native parts not needed).

## R9. Remembering passwords (FR-028)

- **Decision**: `flutter_secure_storage` (11.x, BSD-3) keyed by book ID. It uses the
  Android Keystore and the iOS Keychain. On the web it uses WebCrypto with a key kept in
  the browser, which protects only against casual inspection. Delete the entry when the
  book is removed. If opening fails with a stored password, ask again and replace it.
- **Rationale**: The platform-standard way to keep secrets on the device (Principle VI).
- **Alternatives considered**: Storing passwords in the drift database (plain text on
  disk).

## R10. Keeping the web first load small

- **Decision**: Load the reader screen with a Dart deferred import (`deferred as reader`)
  and load PDFium only when it is first needed (import or opening a book). The library
  screen reads only from the database, so it never needs PDFium.
- **Rationale**: The spike measured about 5–6 MB gzipped for a full first load, of which
  `pdfium.wasm` is 2.3 MB. Deferring it makes the library usable sooner (Principle V).
- **Alternatives considered**: No deferral (heavier first load); a separate web entry
  point (more build complexity).

## R11. State management and navigation

- **Decision**: `flutter_riverpod` 3.x without code generation. `StreamProvider`s over
  drift queries for the library list, `Notifier`s for import progress and preferences.
  Navigation with the plain `Navigator` (two screens: library and basic page view).
- **Rationale**: Riverpod was chosen in CLAUDE.md. Skipping riverpod_generator avoids a
  second code generator. Two screens don't justify a routing package (Principle VIII).
- **Alternatives considered**: `go_router` (deep links aren't needed yet).

## R12. Search and sort keys

- **Decision**: Store two derived columns on each book:
  - `searchKey`: title and author, lower-cased with accents removed.
  - `sortTitle`: the title lower-cased with a leading "the", "a" or "an" removed.
  Use pure Dart functions with a hand-written fold table for Latin letters (Latin-1,
  Latin Extended-A and B), unit-tested first. Search uses `LIKE '%' || ? || '%'` on
  `searchKey`, with the query folded the same way. Filtering 500 rows is well within
  SC-004.
- **Rationale**: Deterministic, tested, and needs no dependency.
- **Alternatives considered**: The `diacritic` package (last release 2024-09);
  `unorm_dart` (full Unicode normalisation, more than needed); SQLite FTS (overkill for
  500 rows).

## R13. Basic page view and progress (FR-016a/b)

- **Decision**: The basic page view uses pdfrx's `PdfViewer` showing pages in a vertical
  scroll, with text selection and zoom turned off. `onPageChanged` updates
  `reading_progress.currentPage`, saving at most once per second and again when the
  screen closes. Progress % = `floor(currentPage / pageCount × 100)`, and the last page
  is 100% (FR-013). This is a pure function with unit tests.
- **Rationale**: Gives resume and progress now. Feature 002 replaces the screen but keeps
  the same progress record.

## R14. Testing

- **Decision**:
  - Unit tests (`flutter_test`): title resolver, search fold, sort key, progress
    calculation, metadata reader (with fixture PDFs), and the import pipeline with fake
    stores.
  - Widget tests: the library grid and list, the empty state, the import summary, the
    delete confirmation.
  - `integration_test`: import → open → resume on an Android device and in Chrome.
  - Fixture PDFs in `test/fixtures/`: with and without metadata, UTF-16 title,
    compressed object streams, encrypted, damaged, not a PDF.

## R15. Dependencies (Principle VIII)

| Package | Licence | Maintained | Platforms | Why |
|---|---|---|---|---|
| pdfrx | MIT | yes (2026) | Android, iOS, web | Page count, cover rendering, passwords, page view |
| drift, drift_flutter, drift_dev, build_runner | MIT / BSD | yes (2026) | all | Library database |
| flutter_riverpod | MIT | yes (2026) | all | State management |
| file_picker | MIT | yes (2026) | all | System file picker |
| path_provider | BSD-3 | yes (2026) | Android, iOS | App storage directory |
| receive_sharing_intent | Apache-2.0 | yes (2026) | Android, iOS | Open with / Share to |
| desktop_drop | Apache-2.0 | yes (2026) | web | Drag and drop |
| flutter_secure_storage | BSD-3 | yes (2026) | all | Remembered PDF passwords |
| crypto | BSD-3 | yes (2025) | all | SHA-256 for duplicates |
| archive | MIT | yes (2026) | all | Flate decoding for the metadata reader on web and mobile |
| web | BSD-3 | yes (Dart team) | web | OPFS and storage persistence interop |
| cross_file | BSD-3 | yes (Flutter team) | all | `XFile` for shared and dropped files (already a dependency of file_picker and desktop_drop) |

`archive` releases 4.4.0–4.5.1 are less than two weeks old; pin 4.3.0 or later-but-aged.
