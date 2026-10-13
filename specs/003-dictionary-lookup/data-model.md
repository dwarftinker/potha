# Data Model: Dictionary Lookup

**Feature**: 003-dictionary-lookup | **Date**: 2026-10-13

There are two databases:
- the app database (drift, user data), which goes from schema v2 to v3;
- a new read-only dictionary database, built by `tool/build_dictionary.py` (research R1
  to R3).

User data stays on the device (FR-032, Principle VI).

## App database: schema v3

### lookup_history (new)

One row per word per book (clarification Q5).

| Column | Type | Rules |
|---|---|---|
| book_id | text, FK → books.id, cascade delete | part of the PK (FR-027) |
| word_key | text | part of the PK; the normalised lookup key (research R5) |
| word | text | as the reader saw it, from the latest lookup ("Running") |
| headword | text, nullable | the first entry shown ("run"); null if not found |
| source | text enum `offline` / `online` / `none` | where the shown entry came from |
| page | int | ≥ 1; page of the latest lookup |
| looked_up_at | datetime (UTC) | the latest lookup; history is ordered by this, newest first |
| count | int, default 1 | ≥ 1; incremented by each lookup of the same key in that book |

- An upsert on (book_id, word_key) runs after the panel is shown (research R10).
- Index `(looked_up_at DESC)` for the "All books" list.
- "Clear" deletes all rows for one book, or all rows.

### reader_preferences (changed)

| Column | Type | Default | Rules |
|---|---|---|---|
| tap_to_define | bool, **new** | false | Clarification Q2, FR-015 |
| lookup_hint_shown | bool, **new** | false | Set when the hint is dismissed or a lookup is made (FR-006) |

### Migration v2 → v3

1. Create `lookup_history` and its index.
2. `ALTER TABLE reader_preferences ADD COLUMN tap_to_define INTEGER NOT NULL DEFAULT 0`.
3. `ALTER TABLE reader_preferences ADD COLUMN lookup_hint_shown INTEGER NOT NULL DEFAULT 0`.

Steps (CLAUDE.md): bump `schemaVersion`, add `from2To3` to `stepByStep`, run
`drift_dev make-migrations` and `schema generate`, then write a test that migrates a v2
database with progress and preferences rows and checks they are kept.

## Dictionary database (read-only, one file per language and version)

File: `en-<version>.sqlite`, where `<version>` is the dump date plus a build number
(`20260902.1`). `meta` holds the attribution that FR-034 shows.

### meta

| Column | Type | Notes |
|---|---|---|
| key | text PK | `language` (`en`), `version`, `source` ("English Wiktionary via wiktextract / kaikki.org"), `dump_date`, `licence` ("CC BY-SA 4.0"), `licence_url`, `source_url`, `built_at`, `headwords` |
| value | text | |

### entries

One row per headword and part of speech.

| Column | Type | Notes |
|---|---|---|
| id | int PK | |
| key | text, indexed | Normalised: lowercase, NFC, ’ → ', single spaces (research R5) |
| headword | text | As written in Wiktionary ("Turkey", "give up") |
| pos | text | `noun`, `verb`, `adj`, `adv`, `name` (proper noun), `phrase`, `prep`, … |
| ipa | text, nullable | The first IPA transcription, US or UK |
| senses | text (JSON) | `[{"g": "gloss", "t": ["informal"], "x": ["example", …]}, …]`, in Wiktionary's order, at most 12 per entry |
| rank | int | Frequency rank from wordfreq (lower is more common), used to order entries |

### forms

| Column | Type | Notes |
|---|---|---|
| form_key | text, indexed | Normalised inflected form ("mice") |
| base_key | text | Normalised base word ("mouse"), which exists in `entries` |
| relation | text | `plural`, `past`, `past_participle`, `present_participle`, `third_person`, `comparative`, `superlative`, `form` (other) |

A pair (form_key, base_key) is unique and keeps one relation, the most specific.

## Platform storage of the dictionary file

| Platform | Where | Ready when |
|---|---|---|
| Android, iOS | `<app support>/dictionary/en-<version>.sqlite`, unpacked from the asset at app start | the file exists under its final name (renamed after unpacking) |
| Web | drift WASM database `dictionary-en-<version>` (OPFS, else IndexedDB) | drift reports the database as existing after `initializeDatabase` succeeds |

Old versions are deleted once the new one is ready.

## In-memory types (not stored)

| Type | Fields | Notes |
|---|---|---|
| `WordSelection` | page, `start`, `end` (character indices in that page's `PageText`), `text` as shown, `rects` | One page only (research R4) |
| `LookupQuery` | `candidates` (ordered keys: joined / hyphenated / parts), `display` word, `capitalisedMidSentence`, `isPhrase`, `garbled` | From `WordExtractor` |
| `DictionaryEntry` | headword, pos, ipa, senses (gloss, tags, examples) | From `entries` |
| `WordFormLink` | form, base, relation | From `forms`, or the rule fallback |
| `LookupResult` | `query`, sections: [`entry` + optional `note` ("running – form of run")], `phraseNotFound`, `source` (offline / online), or `notFound` | Ordered by research R5 |
| `LookupState` | `idle` · `preparing(progress?)` · `loading(id)` · `shown(id, result, backStack)` · `notFound(id, online: available / unavailable / searching / failed)` · `noText` | In `LookupController` |
| `DictionaryStatus` | `notStarted` · `downloading(bytes, total)` · `unpacking` · `ready` · `failed(offline / error)` | Web download and mobile unpack (FR-022) |

## State transitions

```text
Dictionary (web):     notStarted → downloading(progress) → ready
                      downloading → failed(offline | error) → (next book open or lookup) → downloading
Dictionary (mobile):  (app start) unpacking → ready        (only after install or upgrade)

Lookup panel:         idle → loading → shown | notFound | noText(brief message, no panel)
                      shown → (definition word) loading → shown [back stack +1] → (Back) shown [−1]
                      notFound(online available) → searching → shown(online) | notFound(failed)
                      any → (newer request) loading          [older results dropped: FR-014]
                      any open → idle on tap outside, swipe, Esc, back, page turn (FR-004)
                      dictionary not ready → preparing(progress) → loading → …

Selection:            none → word (long-press / double-click / tap-to-define)
                      → extended (handle or drag; looked up when the drag ends) → none (panel closes)
History line:         absent → created(count 1) → updated(count + 1, latest page and time)
                      → deleted (Clear, or the book is removed)
```
