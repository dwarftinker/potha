# Implementation Plan: Library and Import

**Branch**: `001-library-and-import` | **Date**: 2026-10-11 | **Spec**: [spec.md](spec.md)

**Input**: Feature specification from `/specs/001-library-and-import/spec.md`

## Summary

Build Potha's home screen: a library of the reader's PDFs, shown as a cover grid or list,
with sorting, search and removal. Books come in through the file picker, Open with /
Share to on Android and iOS, and drag and drop on the web. Each import is streamed into
app-owned storage, hashed for duplicate detection, inspected through a format-agnostic
document interface (page count, metadata, cover), and committed atomically. A basic page
view opens books and saves the current page, so resume and progress work in this feature;
the full reader (002) replaces that view later.

The app is a single Flutter codebase using Riverpod, drift and pdfrx. One finding from
research changes the original stack: pdfrx does not expose PDF title or author, so a small
pure-Dart metadata reader is added (research R1).

## Technical Context

**Language/Version**: Dart 3.13 / Flutter 3.47 (stable)

**Primary Dependencies**: pdfrx 2.6, drift 2.35 + drift_flutter 0.3, flutter_riverpod
3.4, file_picker 13, receive_sharing_intent 1.9, desktop_drop 0.8,
flutter_secure_storage 11, path_provider 2, crypto 3, archive 4, web 1 (see research R15)

**Storage**: drift/SQLite (WASM on web) for books, covers, progress and preferences;
book files in the app support directory (Android, iOS) or OPFS with an IndexedDB fallback
(web); passwords in platform secure storage

**Testing**: flutter_test (unit and widget), integration_test (Android device, Chrome),
fixture PDFs in `test/fixtures/`

**Target Platform**: Android 7+ (API 24), iOS 13+ (built but not verified), web (current
Chrome, Edge, Firefox, Safari; secure context required)

**Project Type**: Cross-platform mobile and web app (single Flutter project)

**Performance Goals**: book appears in under 3 s for a 20 MB PDF; smooth 60 fps scrolling
with 500 books; search updates within 0.5 s; previously opened book shows content in under
2 s (constitution V)

**Constraints**: fully offline; nothing leaves the device; web imports limited to 100 MB;
imports leave nothing partial behind; the library screen must not load PDFium on the web

**Scale/Scope**: up to about 500 books per device; 2 screens (library, basic page view),
plus dialogs for passwords, import summary and removal

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Principle | Status | How this plan complies |
|---|---|---|
| I. One codebase, three platforms | Pass | One Flutter project. Platform code only behind `BookFileStore` (file storage) and in the platform declarations for Open with / Share to (contracts/platform-integration.md). Verified on Android and web, including Chrome on a phone; iOS built but unverified, as v2.0.0 allows. |
| II. Offline-first | Pass | No network calls. Everything is local: database, files, covers, passwords. |
| III. Format-agnostic core | Pass | Library, import and progress use `DocumentFormat` / `ReaderDocument` (contracts/reader-document.md). `books.format` column; PDF is the only implementation. |
| IV. Test-first for core logic | Pass | Title resolver, search fold, sort key, progress calculation, metadata reader and import pipeline have unit tests written and failing first. Each user story has a widget or integration test for its main path. |
| V. Reading comes first | Pass | Covers are stored at import, so the library never renders PDFs. The reader route and PDFium are deferred on the web. List queries carry no image bytes. Targets are checked in quickstart scenarios 2, 14 and 20. |
| VI. Privacy by default | Pass | No analytics or uploads. Passwords in Keystore/Keychain (WebCrypto on the web, noted in R9). Books stored in app-private storage. |
| VII. Accessible and calm | Pass | Semantics labels on every control and the drop zone; text scales with the system setting; light and dark themes; contrast checked (quickstart 21). |
| VIII. Simplicity | Pass | Every dependency is justified in research R15. No routing package, no Riverpod codegen, no diacritics package. The metadata reader exists only because pdfrx lacks the API, and it will be replaced when pdfrx adds it. |

**Post-design re-check (after Phase 1)**: Pass. The data model, contracts and quickstart
add no new dependencies or platform code beyond the above. No exceptions are needed, so
Complexity Tracking is empty.

## Project Structure

### Documentation (this feature)

```text
specs/001-library-and-import/
├── plan.md              # This file
├── research.md          # Phase 0: decisions R1–R15
├── data-model.md        # Phase 1: tables, rules, state transitions
├── quickstart.md        # Phase 1: run and validation scenarios
├── contracts/
│   ├── reader-document.md       # DocumentFormat / ReaderDocument / view factory
│   ├── storage-and-import.md    # BookFileStore, ImportService, LibraryRepository
│   └── platform-integration.md  # Android, iOS and web declarations
├── checklists/requirements.md
└── tasks.md             # Phase 2 (/speckit-tasks)
```

### Source Code (repository root)

The Flutter project is created at the repository root (`flutter create --project-name
potha --org dev.potha --platforms android,ios,web .`).

```text
lib/
├── main.dart
├── app.dart                         # MaterialApp, themes, providers root
├── core/
│   ├── document/
│   │   ├── document_format.dart     # DocumentFormat, ReaderDocument, DocumentMetadata
│   │   └── pdf/
│   │       ├── pdf_document_format.dart   # pdfrx-backed implementation
│   │       └── pdf_metadata_reader.dart   # pure Dart Info/XMP reader (R1)
│   ├── storage/
│   │   ├── book_file_store.dart     # interface + conditional export
│   │   ├── book_file_store_io.dart  # Android, iOS
│   │   └── book_file_store_web.dart # OPFS / IndexedDB
│   ├── db/
│   │   ├── app_database.dart        # drift tables, migrations
│   │   └── connection.dart          # drift_flutter setup (native and web)
│   └── secure/password_store.dart
├── features/
│   ├── library/
│   │   ├── domain/                  # title_resolver, text_fold, sort_title, progress
│   │   ├── data/library_repository.dart
│   │   ├── import/                  # import_service, import_source, incoming_files
│   │   └── ui/                      # library_screen, book_tile, book_row, empty_state,
│   │                                # import_progress, import_summary, password_dialog,
│   │                                # remove_dialog, drop_zone
│   └── reader/
│       └── basic_page_view.dart     # deferred-loaded on web (R10)
web/
├── sqlite3.wasm
└── drift_worker.js
test/
├── fixtures/                        # PDFs for metadata and import tests
├── unit/                            # domain, metadata reader, import service (fakes)
└── widget/                          # library screen states, dialogs
integration_test/
└── library_flow_test.dart           # import → open → resume → remove
```

**Structure Decision**: A single Flutter app at the repository root, organised by
`core/` (shared, format-agnostic infrastructure) and `features/` (one folder per spec
feature). Later features (dictionary, highlights) add folders under `features/` and
depend on `core/document` only.

## Complexity Tracking

No constitution violations to justify.
