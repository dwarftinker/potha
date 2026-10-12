# Data Model: Library and Import

**Feature**: 001-library-and-import | **Date**: 2026-10-11

Stored in the local drift database (schema version 1). Book files live in the
`BookFileStore` (see [contracts/storage-and-import.md](contracts/storage-and-import.md)),
not in the database.

## books

One row per imported book.

| Field | Type | Rules |
|---|---|---|
| id | text, primary key | Random UUID v4, created at import |
| format | text | `pdf` for now. Lets later formats (EPUB) share the table (Principle III) |
| title | text, not null | Resolved by the title rules (FR-010); never blank |
| author | text, nullable | From metadata; null when absent or blank |
| sortTitle | text, not null | Derived from title: lower-case, accents removed, leading "the"/"a"/"an" removed (R12) |
| searchKey | text, not null | Derived: folded `title + " " + author` (R12) |
| originalFileName | text, not null | Kept for display in error and summary messages |
| contentHash | text, not null, unique | SHA-256 of the file, lower-case hex (FR-007) |
| sizeBytes | integer, not null | Size of the stored copy |
| pageCount | integer, not null, > 0 | From the document at import |
| isPasswordProtected | boolean, not null | True if a password was needed to open it |
| addedAt | datetime, not null | UTC, set at import |
| lastOpenedAt | datetime, nullable | UTC; null until first opened |

Indexes: `contentHash` (unique), `lastOpenedAt`, `addedAt`, `sortTitle`.

## book_covers

Kept separate so library list queries don't load image bytes.

| Field | Type | Rules |
|---|---|---|
| bookId | text, primary key, FK → books.id, cascade delete | |
| image | blob, not null | PNG, 360 px wide, page 1 |

A book with no row here shows the placeholder cover (FR-012).

## reading_progress

| Field | Type | Rules |
|---|---|---|
| bookId | text, primary key, FK → books.id, cascade delete | |
| currentPage | integer, not null | 1-based, `1 ≤ currentPage ≤ pageCount` |
| updatedAt | datetime, not null | UTC |

No row means "New" (FR-013). The percentage is not stored:
`percent = currentPage == pageCount ? 100 : floor(currentPage × 100 / pageCount)`.

## library_preferences

A single row (id = 1).

| Field | Type | Rules |
|---|---|---|
| id | integer, primary key | Always 1 |
| sortOrder | text, not null | `recentlyOpened` (default), `recentlyAdded`, `title` |
| viewMode | text, not null | `grid` (default), `list` |
| webStorageNoticeShown | boolean, not null | Default false; set after the one-time notice (FR-027) |

## Outside the database

- **Remembered passwords**: platform secure storage, key `pdf-password:<bookId>` (FR-028).
  Deleted together with the book.
- **Import result** (in memory only, not stored): `{fileName, outcome: added |
  alreadyInLibrary | failed, bookId?, failureReason?}`. `failureReason` is one of
  `notAPdf`, `damaged`, `passwordCancelled`, `tooLargeForWeb`, `storageFull`, `cancelled`,
  `unknown`.

## Sort orders (FR-017)

| sortOrder | ORDER BY |
|---|---|
| recentlyOpened | `lastOpenedAt IS NULL, lastOpenedAt DESC, addedAt DESC` |
| recentlyAdded | `addedAt DESC` |
| title | `sortTitle ASC, addedAt DESC` |

## State transitions

```text
Import:   picked → staging (copy + hash) → [duplicate? → discarded, alreadyInLibrary]
                 → opened (password?) → inspected (pages, metadata, cover)
                 → committed (DB transaction + file moved)        = added
          any step → cancelled | failed → staging file deleted     = nothing kept
Book:     added (New) → opened (progress row created) → progress updated …
          → removed (row, cover, progress, password, file deleted)
```

## Lifecycle rules

- **Removal (FR-021)**: delete the database row first (the cover and progress go with it
  by cascade), then delete the stored file and the remembered password. If the app dies
  in between, the orphaned file is removed by the startup cleanup.
- **Startup cleanup**: empty `staging/`, and delete stored files with no `books` row.
- **Migrations**: every schema change bumps the drift schema version and ships a tested
  migration, so data survives app updates (FR-024).
