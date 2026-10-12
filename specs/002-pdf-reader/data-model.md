# Data Model: PDF Reader

**Feature**: 002-pdf-reader | **Date**: 2026-10-12

Stored in the local drift database, which goes from schema version 1 (001) to version 2.
Everything stays on the device (FR-041, Principle VI).

## reading_progress (changed)

One row per opened book; no row means "New" (001).

| Column | Type | Rules |
|---|---|---|
| book_id | text, PK, FK → books.id, cascade delete | unchanged |
| current_page | int | 1 ≤ current_page ≤ pageCount; unchanged |
| page_offset | real, **new**, default 0 | 0 ≤ page_offset ≤ 1: the fraction of the page height at the top of the visible area (research R4) |
| page_mode | text enum `paged` / `continuous`, **new**, nullable | null means the default, `paged` (FR-009) |
| updated_at | datetime (UTC) | unchanged |

- The library's progress label still comes from `current_page` and the book's page count
  (001 FR-013). FR-013 in this feature needs no change.
- 001 rows get `page_offset = 0` and `page_mode = null`, so they open at the top of their
  saved page, in paged mode (FR-014).
- The page mode is saved in this row because a row always exists while a book is open:
  001 records the starting page on open. A separate per-book settings table would add a
  join for one field (Principle VIII).

## reader_preferences (new)

A single row (id = 1), created by the migration and by `onCreate`.

| Column | Type | Default | Rules |
|---|---|---|---|
| id | int, PK | 1 | always 1 |
| theme | text enum `light` / `dark` / `sepia` | `light` | FR-027 |
| fit | text enum `fitWidth` / `fitPage` | `fitWidth` | FR-021 |

These are separate from `library_preferences` so library and reader code do not share a
row. The reader's theme is not the app theme (spec assumption).

## Migration v1 → v2

1. `ALTER TABLE reading_progress ADD COLUMN page_offset REAL NOT NULL DEFAULT 0`, with a
   check `page_offset BETWEEN 0 AND 1`.
2. `ALTER TABLE reading_progress ADD COLUMN page_mode TEXT NULL`.
3. Create `reader_preferences` and insert row 1.

Steps: generate the schema snapshot with `drift_dev make-migrations`, then add a test that
migrates a v1 database containing progress rows and checks the values are kept
(CLAUDE.md, "After changing a drift table").

## In-memory types (not stored)

| Type | Fields | Notes |
|---|---|---|
| `ReadingPosition` | `page` (1-based), `offsetY` (0–1) | Value type; clamped on creation. Used for resume, jump-back and rotation (FR-015). |
| `JumpBack` | `ReadingPosition? previous` | One step only (FR-026, R8). Cleared when the book closes. |
| `OutlineEntry` | `title`, `page` (nullable when the destination is missing), `children` | From the document (FR-024). Entries without a page are shown but can't be chosen. |
| `DocumentLink` | `PageLink {rect, page}` or `WebLink {rect, uri}` | `rect` is in page coordinates, normalised 0–1 (FR-025). |
| `PageText` | `text`, `charRects` (normalised 0–1 per character) | An empty `text` means no text layer on that page (FR-034). |
| `SearchResult` | `page`, `snippet`, `matchStart`, `matchLength` (in the snippet), `rects` | Streamed; the "match X of Y" count grows while searching (FR-032). |
| `ReaderSession` | book, document, mode, current position, controls visible, open panel | UI state in a Riverpod notifier for the reader screen. |

## State transitions

```text
Reader screen:  opening → (password?) → reading ⇄ panel open (contents | search |
                thumbnails | settings | go to page)
                opening → failed (missing or unreadable file, password cancelled)
                  → message → library (FR-038)
Controls:       hidden ⇄ shown (centre tap; auto-hide after 3 s unless a control is
                in use, a panel is open, or a screen reader is on)
Position save:  changed → saved within 1 s; also saved on leaving the book and on
                app pause or hide
Jump back:      none → set (on jump) → replaced (next jump) | used | cleared (close)
Search:         idle → running (streaming results) → done | cancelled (new query,
                closed)
```
