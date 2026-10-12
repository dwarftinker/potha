---

description: "Task list for feature 001: library and import"
---

# Tasks: Library and Import

**Input**: Design documents from `/specs/001-library-and-import/`

**Prerequisites**: plan.md, spec.md, research.md, data-model.md, contracts/, quickstart.md

**Tests**: Included. The constitution (Principle IV) requires unit tests written first,
and failing, for core logic, and at least one widget or integration test per user story.

**Organization**: Tasks are grouped by user story so each story can be built and tested
on its own.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies on incomplete tasks)
- **[Story]**: The user story the task belongs to (US1–US6 from spec.md)
- Paths are relative to the repository root (single Flutter project, see plan.md)

---

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Create the Flutter project and its tooling.

- [X] T001 Create the Flutter project at the repository root with `flutter create --project-name potha --org dev.potha --platforms android,ios,web .`; keep existing files (CLAUDE.md, specs/, .specify/), delete the generated counter app in lib/main.dart and test/widget_test.dart, and add Flutter entries (build/, .dart_tool/) to .gitignore, leaving generated `*.g.dart` files tracked
- [X] T002 Add dependencies to pubspec.yaml per research.md R15, each pinned to a release at least two weeks old: pdfrx, drift, drift_flutter, flutter_riverpod, file_picker, path_provider, receive_sharing_intent, desktop_drop, flutter_secure_storage, crypto, archive (4.3.x, not 4.4+), web; dev: drift_dev, build_runner, integration_test (sdk); then run `flutter pub get`
- [X] T003 [P] Configure analysis_options.yaml with flutter_lints plus `prefer_const_constructors`, `always_declare_return_types`, `avoid_print`; exclude `**/*.g.dart`
- [X] T004 [P] Copy drift's web assets into web/: `sqlite3.wasm` (matching the resolved sqlite3 package version) and `drift_worker.js` (from the drift release matching the resolved version), and document the update step in a comment at the top of lib/core/db/connection.dart
- [X] T005 [P] Create test fixture PDFs with a script tool/make_fixtures.py (Python 3 writes base PDFs by hand; Ghostscript 10.02+ adds compressed object streams with `-dWriteObjStms -dWriteXRefStm -dOmitXMP` and encryption with `-sUserPassword`) that writes to test/fixtures/: `with_metadata.pdf` (Title "The Brothers Karamazov", Author "Fyodor Dostoevsky"), `utf16_title.pdf` (UTF-16BE title "Crime and Punishment – Преступление"), `object_stream_metadata.pdf` (Info dict inside a compressed object stream + xref stream), `xmp_only.pdf` (title only in XMP dc:title), `no_metadata.pdf`, `encrypted.pdf` (user password "secret"), `truncated.pdf` (valid header, cut at 60%), `not_a_pdf.pdf` (plain text), `three_pages.pdf`; commit these small files. Also generate `large_20mb.pdf` (about 20 MB, image-heavy pages) into build/fixtures/ on demand, not committed; document required tools (python3, gs) at the top of the script
- [X] T006 [P] Set Android minSdk 24 in android/app/build.gradle(.kts) and iOS deployment target 13.0 in ios/Podfile and ios/Runner.xcodeproj

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Database, storage, document abstraction and app shell that every story uses.

**⚠️ CRITICAL**: No user story work can begin until this phase is complete.

- [X] T007 Define drift tables in lib/core/db/app_database.dart exactly as data-model.md: `books` (id text PK "Random UUID v4"; format text "`pdf` for now"; title text not null "never blank"; author text nullable; sortTitle text not null; searchKey text not null; originalFileName text not null; contentHash text not null unique "SHA-256 of the file, lower-case hex"; sizeBytes int not null; pageCount int not null "> 0"; isPasswordProtected bool not null; addedAt datetime not null UTC; lastOpenedAt datetime nullable UTC), `book_covers` (bookId text PK FK→books.id cascade delete; image blob not null "PNG, 360 px wide, page 1"), `reading_progress` (bookId text PK FK→books.id cascade delete; currentPage int not null "1 ≤ currentPage ≤ pageCount"; updatedAt datetime not null), `library_preferences` (id int PK "Always 1"; sortOrder text not null default `recentlyOpened`, values `recentlyOpened|recentlyAdded|title`; viewMode text not null default `grid`, values `grid|list`; webStorageNoticeShown bool not null default false); indexes on contentHash (unique), lastOpenedAt, addedAt, sortTitle; schemaVersion 1; enable `PRAGMA foreign_keys = ON` in `beforeOpen`; insert the preferences row in `onCreate`
- [X] T008 Implement the database connection in lib/core/db/connection.dart using `driftDatabase(name: 'potha', web: DriftWebOptions(sqlite3Wasm: Uri.parse('sqlite3.wasm'), driftWorker: Uri.parse('drift_worker.js')))`, expose `appDatabaseProvider` (Riverpod) and a `AppDatabase.forTesting(NativeDatabase.memory())` constructor; run `dart run build_runner build` and commit lib/core/db/app_database.g.dart
- [X] T009 [P] Write the drift schema test in test/unit/db/app_database_test.dart: preferences row exists after creation with defaults; contentHash uniqueness enforced; deleting a book cascades to book_covers and reading_progress
- [X] T010 [P] Set up drift schema snapshots for app-update safety (FR-024, SC-006): configure `databases` and `schema_dir: drift_schemas/` in build.yaml, run `dart run drift_dev make-migrations` to save the v1 schema to drift_schemas/, and add test/unit/db/migration_test.dart verifying the current schema matches the v1 snapshot; later schema versions add step-by-step migration tests here
- [X] T011 [P] Define the format-agnostic interfaces in lib/core/document/document_format.dart exactly per contracts/reader-document.md: `DocumentFormat` (id, sniff, open with knownPassword/askPassword), `ReaderDocument` (pageCount, usedPassword, readMetadata, renderPagePng, close), `DocumentMetadata {String? title, String? author}`, `DocumentViewFactory`, `DocumentOpenException` with kind `damaged | passwordCancelled | unsupported`, and `BookFileRef`
- [X] T012 [P] Define `BookFileStore`, `StagedFile`, `StorageFullException` in lib/core/storage/book_file_store.dart per contracts/storage-and-import.md, with a conditional export selecting book_file_store_io.dart or book_file_store_web.dart, and a `bookFileStoreProvider`
- [X] T013 [P] Write BookFileStore tests against the IO implementation using a temp directory in test/unit/storage/book_file_store_io_test.dart: stage streams bytes and reports progress; cancel deletes the staging file; commit moves to `books/<bookId>.pdf`; delete removes it; cleanUp empties staging and removes files whose id is not in knownBookIds
- [X] T014 [P] Write web BookFileStore tests in test/web/book_file_store_web_test.dart, run with `flutter test --platform chrome`: stage/commit/find/delete/cleanUp against OPFS; with `createWritable` unavailable (injected feature check) the IndexedDB fallback is used; a `QuotaExceededError` from the writer (injected) becomes `StorageFullException` and leaves no staging file
- [X] T015 Implement the IO BookFileStore in lib/core/storage/book_file_store_io.dart under `getApplicationSupportDirectory()/books` and `/staging` (research R3); map `FileSystemException` with ENOSPC (errno 28) to `StorageFullException`; make T013 pass
- [X] T016 Implement the web BookFileStore in lib/core/storage/book_file_store_web.dart with `package:web`: OPFS via `navigator.storage.getDirectory()`, `books/` and `staging/` directories, chunked `createWritable()` writes, IndexedDB Blob fallback when `createWritable` is unavailable, `QuotaExceededError` → `StorageFullException`, `requestPersistence()` calling `navigator.storage.persist()`; `find` returns a ref readable as bytes for pdfrx; make T014 pass
- [X] T017 [P] Implement `PasswordStore` in lib/core/secure/password_store.dart wrapping flutter_secure_storage with key `pdf-password:<bookId>`: `read`, `write`, `delete` (research R9), plus `passwordStoreProvider`
- [X] T018 Implement the base `LibraryRepository` in lib/features/library/data/library_repository.dart per contracts/storage-and-import.md: `watchBooks` (sorted by recentlyOpened only for now, no search), `cover(bookId)`, `findByHash`, `insertBook` (books + book_covers in one transaction), and `BookSummary {id, title, author?, progressLabel, hasCover}` built without cover bytes; `libraryRepositoryProvider`
- [X] T019 Create the app shell: lib/main.dart (ProviderScope, `WidgetsFlutterBinding.ensureInitialized()`, run startup cleanup = `BookFileStore.cleanUp(all book ids)` before showing the library) and lib/app.dart (MaterialApp titled "Potha", light and dark `ThemeData` from one seed colour with `ThemeMode.system`, home = LibraryScreen)
- [X] T020 Create a placeholder LibraryScreen in lib/features/library/ui/library_screen.dart: AppBar "Library" and a plain list of book titles from `watchBooks` (replaced by the grid in US2)

**Checkpoint**: The app launches on Android and in Chrome with an empty list; database, file store and interfaces are in place.

---

## Phase 3: User Story 1 - Import a PDF (Priority: P1) 🎯 MVP

**Goal**: Readers add PDFs through the file picker, Open with / Share to (Android, iOS) or drag and drop (web); the app keeps its own copy, rejects bad files, avoids duplicates, and never leaves partial data.

**Independent Test**: Import a PDF through each entry point, then move or delete the original file and confirm the book is still listed (quickstart scenarios 2–13, 15, 22, 23).

### Tests for User Story 1 (write first, confirm they fail) ⚠️

- [X] T021 [P] [US1] Unit-test the title resolver in test/unit/library/title_resolver_test.dart for FR-010: metadata title wins unless blank/whitespace; else file name without extension with underscores → spaces and repeated spaces collapsed (`my_great_book.pdf` → "my great book", `scan_0001.pdf` → "scan 0001"); a name with no letters (`0001.pdf`, `___.pdf`) → "Untitled book <local date>" using an injected date formatter
- [X] T022 [P] [US1] Unit-test text folding and sort keys in test/unit/library/text_fold_test.dart: `fold("Tolstoy")` == `fold("TOLSTÓY")` == "tolstoy"; Latin-1 and Latin Extended-A/B letters fold (é→e, ß→ss, Ø→o, Ł→l, Œ→oe); non-Latin scripts pass through lower-cased; `sortTitle("The Idiot")` == "idiot", `sortTitle("A Tale")` == "tale", `sortTitle("An Essay")` == "essay", `sortTitle("Theory")` == "theory"; `searchKey(title, author)` folds both joined by a space
- [X] T023 [P] [US1] Unit-test the PDF metadata reader in test/unit/document/pdf_metadata_reader_test.dart with the T005 fixtures: with_metadata → title and author; utf16_title → decoded UTF-16BE; object_stream_metadata → read from compressed object stream; xmp_only → XMP title; no_metadata → nulls; encrypted → nulls; truncated and not_a_pdf → nulls without throwing
- [X] T024 [P] [US1] Unit-test ImportService in test/unit/library/import_service_test.dart with fakes for DocumentFormat, BookFileStore, PasswordStore and an in-memory database: valid file → `added` and one row with cover; same bytes under another name → `alreadyInLibrary(existingId)` and staging discarded; sniff fails → `notAPdf`, nothing stored; open throws damaged → `damaged`; password cancelled → `passwordCancelled`; wrong then right password → added and password saved; web mode with size 104,857,601 → `tooLargeForWeb` before staging; StorageFullException → `storageFull` and staging discarded; cancel mid-copy → `cancelled`, staging discarded, remaining batch files skipped; batch of 5 with mixed outcomes → 5 results in order; file-move failure after insert → transaction rolled back
- [X] T025 [P] [US1] Widget-test import UI in test/widget/import_flow_test.dart with a fake ImportService: no progress bar for an import finishing in < 1 s; progress bar and Cancel button appear after 1 s (FR-008); password dialog shows and "Wrong password, try again" on retry; multi-file summary lists added / already in library / failed with reasons (FR-009); duplicate shows "Already in your library" with an Open action
- [X] T026 [P] [US1] Widget-test the web storage notice in test/widget/web_storage_notice_test.dart (FR-027): shown after the first successful import when running as web (injected platform flag), not shown again once `webStorageNoticeShown` is true, never shown on Android

### Implementation for User Story 1

- [X] T027 [P] [US1] Implement `resolveTitle` in lib/features/library/domain/title_resolver.dart to pass T021
- [X] T028 [P] [US1] Implement `fold`, `sortTitle` and `searchKey` in lib/features/library/domain/text_fold.dart with a hand-written fold table (research R12) to pass T022
- [X] T029 [P] [US1] Implement `PdfMetadataReader` in lib/core/document/pdf/pdf_metadata_reader.dart (research R1): locate `startxref`, parse classic xref tables and xref streams, follow `/Info` (including objects inside Flate-compressed object streams, inflated with package:archive), decode PDF strings (literal with escapes, hex, PDFDocEncoding, UTF-16BE with BOM), fall back to XMP `dc:title`/`dc:creator`; return nulls if `/Encrypt` is present; catch all errors; pass T023
- [X] T030 [US1] Implement `PdfDocumentFormat` in lib/core/document/pdf/pdf_document_format.dart using pdfrx: `sniff` = `%PDF-` within the first 1024 bytes; `open` via `PdfDocument.openFile`/`openData` with a `passwordProvider` that tries `knownPassword` first, then `askPassword(retry: …)`, mapping a null answer to `passwordCancelled` and other load failures to `damaged`; `readMetadata` delegates to PdfMetadataReader; `renderPagePng` renders at the requested width and encodes via `dart:ui` `Image.toByteData(format: ImageByteFormat.png)`, returning null on failure; register it in `documentFormatsProvider`
- [X] T031 [US1] Implement `ImportService` in lib/features/library/import/import_service.dart per contracts/storage-and-import.md (rules 1–5) and research R4/R5: per file, size check (web limit 104,857,600 bytes, also enforced while streaming when size is unknown) → sniff first bytes → `BookFileStore.stage` with SHA-256 computed via `crypto` chunked conversion during the copy → `findByHash` duplicate check → `open` (password flow through `ImportEvent.needsPassword`) → pageCount, metadata, cover at 360 px → build title (T027), sortTitle/searchKey (T028), UUID v4 id → one transaction inserting books + book_covers then `BookFileStore.commit`, rolling back on failure → save password via PasswordStore if one was used; emit `started`, `progress`, `needsPassword`, `finished(results)`; `cancel()` stops the current file and skips the rest; make T024 pass
- [X] T032 [P] [US1] Define `ImportSource {name, size?, openRead()}` and adapters in lib/features/library/import/import_source.dart: from file_picker `PlatformFile`/`XFile`, from desktop_drop `DropItem`, and from receive_sharing_intent `SharedMediaFile` (file path)
- [X] T033 [US1] Implement the import controller (Riverpod `Notifier`) in lib/features/library/import/import_controller.dart that runs ImportService, exposes import state to the UI, and on the web calls `BookFileStore.requestPersistence()` on the first import
- [X] T034 [P] [US1] Build the password dialog in lib/features/library/ui/password_dialog.dart: obscured field, "Wrong password, try again" on retry, Cancel and Open buttons, semantics labels
- [X] T035 [P] [US1] Build the import progress bar in lib/features/library/ui/import_progress.dart: hidden until the import has run 1 s (FR-008), shows file name, "n of m", determinate bar when size is known, and a Cancel button
- [X] T036 [P] [US1] Build the import summary in lib/features/library/ui/import_summary.dart: single file → snackbar ("Added <title>" / "Already in your library" with Open / error message); several files → sheet listing added, already in library and failed with a human-readable reason for each failureReason (`notAPdf`, `damaged`, `passwordCancelled`, `tooLargeForWeb` "Too large for the web version (max 100 MB). Open it in the Potha mobile app.", `storageFull`, `cancelled`, `unknown`)
- [X] T037 [US1] Add the "Add book" action to LibraryScreen (lib/features/library/ui/library_screen.dart): AppBar button and FAB that open file_picker with `type: FileType.custom, allowedExtensions: ['pdf']` and multiple selection, passing results to the import controller; wire progress, password dialog and summary (makes T025 pass)
- [X] T038 [P] [US1] Add web drag and drop in lib/features/library/ui/drop_zone.dart: desktop_drop `DropTarget` around the library body, visible drop overlay while dragging with semantics label "Drop PDF files to add them", non-PDF drops reported as `notAPdf`; enabled only when `kIsWeb`
- [X] T039 [US1] Handle incoming files in lib/features/library/import/incoming_files.dart: receive_sharing_intent `getInitialMedia()` at startup and `getMediaStream()` while running, filtered to PDFs, passed to the import controller; call `reset()` after handling
- [X] T040 [P] [US1] Declare Android intents in android/app/src/main/AndroidManifest.xml per contracts/platform-integration.md: `launchMode="singleTask"`; `ACTION_VIEW` (DEFAULT, BROWSABLE, schemes content and file, `application/pdf`); `ACTION_SEND` and `ACTION_SEND_MULTIPLE` with `application/pdf`
- [ ] T041 [P] [US1] Configure iOS per contracts/platform-integration.md (unverified; constitution v2.0.0): `CFBundleDocumentTypes` for `com.adobe.pdf` with `LSSupportsOpeningDocumentsInPlace = NO` in ios/Runner/Info.plist, and a Share Extension target with an App Group following the receive_sharing_intent README; note in the PR that iOS is unbuilt and untested. **Status (2026-10-12):** Info.plist document types done; the Share Extension target still needs Xcode on a Mac, so this task stays open
- [X] T042 [US1] Show the one-time web storage notice (FR-027) after the first successful web import in lib/features/library/ui/web_storage_notice.dart: dialog explaining that clearing the browser's site data removes the library; set `library_preferences.webStorageNoticeShown = true`; make T026 pass
- [X] T043 [US1] Write the US1 integration test in integration_test/import_test.dart: import `with_metadata.pdf` through the import controller (bypassing the system picker), assert it appears with its title; import it again, assert one book only; import `not_a_pdf.pdf`, assert nothing added
- [X] T044 [US1] Write a timed import test in integration_test/import_timing_test.dart (SC-002): import build/fixtures/large_20mb.pdf through the import controller on a device and fail if the book is not in the library within 3 s of starting

**Checkpoint**: Books can be imported on Android and web through every entry point and appear in the placeholder list.

---

## Phase 4: User Story 2 - See my library (Priority: P1)

**Goal**: The library shows a cover grid with title, author and progress ("New" or "NN%"), a placeholder cover when needed, and a friendly empty state.

**Independent Test**: Import PDFs with and without metadata and check the grid shows the correct cover, title, author and label for each (quickstart 1–4).

### Tests for User Story 2 (write first, confirm they fail) ⚠️

- [X] T045 [P] [US2] Unit-test the progress calculation in test/unit/library/progress_test.dart for FR-013: `percent = currentPage == pageCount ? 100 : floor(currentPage × 100 / pageCount)`; page 1 of 300 → 0; 150/300 → 50; 299/300 → 99; 300/300 → 100; 1/1 → 100; no progress row → label "New", else "NN%"
- [X] T046 [P] [US2] Widget-test the library in test/widget/library_screen_test.dart: empty library shows the empty state with explanation and an "Add book" button (FR-014); books show cover image or placeholder with title (FR-012); author shown only when present (FR-011); "New" vs "42%" labels; a newly inserted book appears without refresh (FR-015)

### Implementation for User Story 2

- [X] T047 [P] [US2] Implement `progressPercent` and `progressLabel` in lib/features/library/domain/progress.dart to pass T045, and use them when building `BookSummary.progressLabel` in lib/features/library/data/library_repository.dart (left join reading_progress)
- [X] T048 [P] [US2] Build the cover widget in lib/features/library/ui/book_cover.dart: loads bytes through a `coverProvider(bookId)` (`FutureProvider.family`, cached), decodes with `cacheWidth` sized to the tile, shows a placeholder (title on a tinted card) when there is no cover or decoding fails
- [X] T049 [P] [US2] Build the grid tile in lib/features/library/ui/book_tile.dart: cover (2:3 aspect), title (max 2 lines), author (1 line, omitted when null), progress label; one `Semantics` label "<title>, by <author>, <progress>"; respects text scaling without clipping
- [X] T050 [P] [US2] Build the empty state in lib/features/library/ui/empty_state.dart: short explanation ("Your library is empty. Add a PDF to start reading." plus "or drag a PDF here" on the web) and an "Add book" button using the US1 action
- [X] T051 [US2] Replace the placeholder list in lib/features/library/ui/library_screen.dart with a lazily built `GridView.builder` (responsive column count from screen width) of BookTiles, the empty state when there are no books, and the US1 drop zone and import UI kept in place (makes T046 pass)

**Checkpoint**: US1 + US2 give a working bookshelf on Android and web.

---

## Phase 5: User Story 3 - Open a book (Priority: P1)

**Goal**: Tapping a book opens a basic page view at the last page reached (or page 1), and the page is saved for resume and progress.

**Independent Test**: Open a book, scroll to a later page, restart the app, open it again and confirm it resumes there; the library shows the matching percentage (quickstart 14, 15).

### Tests for User Story 3 (write first, confirm they fail) ⚠️

- [X] T052 [P] [US3] Unit-test progress saving in test/unit/library/progress_saver_test.dart: page changes are written at most once per second; the last page is flushed on dispose; `currentPage` is clamped to `1 ≤ currentPage ≤ pageCount`; `markOpened` sets `lastOpenedAt`
- [X] T053 [P] [US3] Write the US3 integration test in integration_test/open_resume_test.dart: import `three_pages.pdf`, open it, jump to page 3, close; assert the library shows 100% and reopening starts at page 3, with the first page rendered within 2 s of the tap (constitution V; measured with a `Stopwatch` until the page image is painted)
- [X] T054 [P] [US3] Widget-test opening a password-protected book in test/widget/open_protected_book_test.dart (FR-028): with a stored password the page view opens without asking; with a wrong stored password the password dialog appears and the new password replaces the stored one

### Implementation for User Story 3

- [X] T055 [US3] Add `markOpened`, `saveProgress` and `currentPage` to lib/features/library/data/library_repository.dart (upsert into reading_progress with `updatedAt`)
- [X] T056 [US3] Implement `ProgressSaver` in lib/features/reader/progress_saver.dart (debounce 1 s, flush on dispose, clamping) to pass T052
- [X] T057 [US3] Implement the PDF `DocumentViewFactory` in lib/core/document/pdf/pdf_document_view.dart: pdfrx `PdfViewer` with vertical page scroll, text selection disabled (`PdfTextSelectionParams(enabled: false)`), pinch zoom disabled (max/min scale 1), opening at `initialPage`, calling `onPageChanged` with the 1-based page
- [X] T058 [US3] Build the basic page view screen in lib/features/reader/basic_page_view.dart (FR-016a/b): finds the file through BookFileStore, opens it through DocumentFormat with the stored password (asking again via the password dialog if it fails, then replacing the stored one), shows a back button to the library and "page n of m", uses ProgressSaver, and shows a clear error if the file is missing; make T054 pass
- [X] T059 [US3] Open books from the library: tapping a BookTile calls `markOpened` and navigates to BasicPageView, imported with `deferred as reader` and `await reader.loadLibrary()` in lib/features/library/ui/library_screen.dart (research R10), showing a small progress indicator while the deferred library loads
- [X] T060 [US3] Make the US1 "Open" action (duplicate import and single-file snackbar) navigate to the same BasicPageView in lib/features/library/ui/import_summary.dart

**Checkpoint**: The P1 MVP is complete: import, see and open books with resume.

---

## Phase 6: User Story 4 - Sort and find (Priority: P2)

**Goal**: Sort by recently opened (default), recently added or title; search by title or author as the reader types; the sort order is remembered.

**Independent Test**: With ten or more books, change sort orders and search partial titles and authors with and without accents (quickstart 17, 18).

### Tests for User Story 4 (write first, confirm they fail) ⚠️

- [X] T061 [P] [US4] Unit-test sorting and search in test/unit/library/library_query_test.dart against the in-memory database: `recentlyOpened` = `lastOpenedAt IS NULL, lastOpenedAt DESC, addedAt DESC`; `recentlyAdded` = `addedAt DESC`; `title` = `sortTitle ASC, addedAt DESC` ("The Idiot" sorts under I); query "tolst" matches author "Tolstoy" and "TOLSTÓY"; empty query returns all; sort order saved to and read from library_preferences
- [X] T062 [P] [US4] Widget-test search and sort in test/widget/sort_search_test.dart: typing filters as you type; no-match message "No books match “…”" with a Clear search button; sort menu changes order

### Implementation for User Story 4

- [X] T063 [US4] Extend `watchBooks(sort, query)` in lib/features/library/data/library_repository.dart with the three ORDER BY clauses from data-model.md and `searchKey LIKE '%' || fold(query) || '%'`; add `watchPreferences` and `updatePreferences` (pass T061)
- [X] T064 [US4] Add a sort menu (Recently opened, Recently added, Title) and a search field to the AppBar in lib/features/library/ui/library_screen.dart, with the query debounced by 150 ms, sort persisted through `updatePreferences`, and the no-match state with Clear search (pass T062)

**Checkpoint**: US4 works with 500 books within SC-004 (search updates in 0.5 s).

---

## Phase 7: User Story 5 - Remove a book (Priority: P2)

**Goal**: Remove a book after a confirmation that names it, deleting its copy, cover, progress and remembered password, never touching the original file.

**Independent Test**: Remove a book, confirm it disappears and its file is gone, re-import it and confirm it shows "New" (quickstart 16).

### Tests for User Story 5 (write first, confirm they fail) ⚠️

- [X] T065 [P] [US5] Unit-test removal in test/unit/library/remove_book_test.dart with fakes: deletes the books row (cover and progress cascade), then the stored file, then the password; if the file delete fails, the row is still gone and the next `cleanUp` removes the orphan
- [X] T066 [P] [US5] Widget-test the remove flow in test/widget/remove_book_test.dart: long-press (or the tile's overflow menu) → "Remove from library"; dialog text "Remove “<title>”? This deletes Potha's copy and your reading progress. The original file is not affected."; Cancel changes nothing; Remove removes the tile

### Implementation for User Story 5

- [X] T067 [US5] Implement `remove(bookId)` in lib/features/library/data/library_repository.dart (row delete, then `BookFileStore.delete`, then `PasswordStore.delete`) to pass T065
- [X] T068 [P] [US5] Build the confirmation dialog in lib/features/library/ui/remove_dialog.dart with the T066 wording, the destructive action styled with the theme's error colour, and semantics labels
- [X] T069 [US5] Add an overflow menu (and long-press) with "Remove from library" to BookTile in lib/features/library/ui/book_tile.dart, wired to the dialog and `remove` (pass T066)

**Checkpoint**: US5 works independently on Android and web.

---

## Phase 8: User Story 6 - Grid or list view (Priority: P3)

**Goal**: Switch between the cover grid and a compact list; the choice is remembered.

**Independent Test**: Switch to list view, restart, confirm it is still list view (quickstart 18).

### Tests for User Story 6 (write first, confirm they fail) ⚠️

- [X] T070 [P] [US6] Widget-test view mode in test/widget/view_mode_test.dart: toggle switches grid ↔ list; list rows show small cover, title, author and progress; the choice is read back from library_preferences on a fresh screen

### Implementation for User Story 6

- [X] T071 [P] [US6] Build the list row in lib/features/library/ui/book_row.dart: small cover (48 px wide), title, author, progress label, same semantics label and overflow menu as BookTile
- [X] T072 [US6] Add a grid/list toggle to the AppBar in lib/features/library/ui/library_screen.dart (icon button with tooltip "Show as list"/"Show as grid"), render `ListView.builder` of BookRows in list mode, and persist `viewMode` via `updatePreferences` (pass T070)

**Checkpoint**: All six user stories work independently.

---

## Phase 9: Polish & Cross-Cutting Concerns

**Purpose**: Accessibility, performance and verification across stories.

- [X] T073 [P] Add a seed script integration_test/seed_500_books.dart that inserts 500 books with covers into the database, and a performance test in integration_test/scroll_perf_test.dart using `traceAction` to fling-scroll the grid and list and fail if more than 1% of frames exceed 16 ms (SC-003), and to check search updates within 0.5 s (SC-004)
- [X] T074 [P] Accessibility pass on all library widgets under lib/features/library/ui/: every control has a semantics label or tooltip; text uses theme text styles so it scales with the system setting; verify at text scale 2.0 with no overflow in test/widget/accessibility_test.dart using `meetsGuideline(textContrastGuideline)`, `androidTapTargetGuideline` and `labeledTapTargetGuideline` in light and dark themes (FR-025)
- [X] T075 [P] Confirm no network access: add a test in test/unit/no_network_test.dart that runs an import and open under `HttpOverrides` throwing on any connection (FR-023, FR-026)
- [X] T076 [P] Measure the web build: `flutter build web --release`, record initial download size (gzipped) with and without the deferred reader in specs/001-library-and-import/quickstart.md, and confirm `pdfium.wasm` is not requested until import or open
- [ ] T077 [P] Open an upstream pdfrx issue (or PR) proposing a document metadata API backed by `FPDF_GetMetaText` on native and web, and link it from a TODO comment in lib/core/document/pdf/pdf_metadata_reader.dart (research R1)
- [X] T078 Run every quickstart.md validation scenario on an Android device and in Chrome (desktop and on an Android phone via `adb reverse`), and record the results in specs/001-library-and-import/checklists/verification.md; iOS is listed as not verified (constitution v2.0.0)
- [X] T079 Update CLAUDE.md: status (feature 001 implemented), how to run (build_runner, tests, mobile web via adb reverse), and the metadata-reader decision

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: none; start immediately.
- **Foundational (Phase 2)**: depends on Setup; blocks all user stories.
- **US1 (Phase 3)**: depends on Foundational. It is the only way books get into the app,
  so the other stories need it to have test data (their unit and widget tests use
  database seeding and do not need US1).
- **US2 (Phase 4)**: depends on Foundational; uses US1's import action for the empty state.
- **US3 (Phase 5)**: depends on Foundational; uses US2's tiles for tapping (can use the
  placeholder list if US2 is not done).
- **US4, US5, US6 (Phases 6–8)**: depend on Foundational and on the library screen from
  US2. Their behaviour is independent, but T064 (US4) and T072 (US6) both edit
  lib/features/library/ui/library_screen.dart, and T069 (US5) and T071 (US6) share the
  tile overflow menu, so build them one after another (US4 → US5 → US6) or coordinate
  edits to those files.
- **Polish (Phase 9)**: after the stories you intend to ship.

### Within Each User Story

- Tests are written first and must fail before implementation (Principle IV).
- Domain functions → data → services → UI → integration.
- Commit after each task or logical group.

### Parallel Opportunities

- Setup: T003–T006 in parallel after T001–T002.
- Foundational: T009, T010, T011, T012, T013, T014, T017 in parallel after T007–T008;
  T015 and T016 in parallel after T012.
- US1: tests T021–T026 in parallel; then T027, T028, T029, T032, T034, T035, T036, T038,
  T040, T041 in parallel.
- US2: T045–T046, then T047–T050 in parallel.
- Within US4, US5 and US6 the test tasks and new-file tasks (T062, T066, T068, T070, T071)
  can run in parallel; the library_screen.dart edits (T064, T072) cannot.
- Polish: T073–T077 in parallel.

---

## Parallel Example: User Story 1

```bash
# Tests first, together:
Task: "Unit-test the title resolver in test/unit/library/title_resolver_test.dart"
Task: "Unit-test text folding and sort keys in test/unit/library/text_fold_test.dart"
Task: "Unit-test the PDF metadata reader in test/unit/document/pdf_metadata_reader_test.dart"
Task: "Unit-test ImportService in test/unit/library/import_service_test.dart"

# Then the independent building blocks, together:
Task: "Implement resolveTitle in lib/features/library/domain/title_resolver.dart"
Task: "Implement fold, sortTitle and searchKey in lib/features/library/domain/text_fold.dart"
Task: "Implement PdfMetadataReader in lib/core/document/pdf/pdf_metadata_reader.dart"
Task: "Declare Android intents in android/app/src/main/AndroidManifest.xml"
```

---

## Implementation Strategy

### MVP First (P1 stories: US1 + US2 + US3)

1. Phase 1 Setup → Phase 2 Foundational.
2. US1 import → check books arrive in the placeholder list.
3. US2 library grid → check covers, titles and labels.
4. US3 open and resume → **stop and validate** on Android and web (quickstart 1–16, 19,
   23). This is the shippable MVP for 001.

### Incremental Delivery

5. US4 sort and search → validate.
6. US5 remove → validate.
7. US6 grid/list → validate.
8. Polish → full quickstart run → merge (Android and web verified; iOS noted unverified).

---

## Notes

- [P] tasks touch different files and have no dependencies on incomplete tasks.
- [USn] labels map tasks to spec.md user stories for traceability.
- The Android SDK must be installed before T040 can be verified and before T043, T044, T053,
  T073 and T078 can run on a device.
- Avoid cross-story coupling beyond what is listed in Dependencies.
