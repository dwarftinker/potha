# Research: Dictionary Lookup

**Feature**: 003-dictionary-lookup | **Date**: 2026-10-13

Sources were checked on 2026-10-13: kaikki.org's download pages, a live request to the
Wikimedia definition endpoint, and drift_flutter 0.3.1 in the pub cache. Sizes marked
"estimate" are measured by the build tool in the first task (R1). Each new package is
pinned to a release at least two weeks old.

## R1. Dictionary data: source, trimming and build

- **Decision**: build the dictionary from wiktextract's English-edition extract on
  kaikki.org. The raw file is `raw-wiktextract-data.jsonl.gz` (2.8 GB compressed, 23.9 GB
  raw, from the enwiktionary dump of 2026-09-02). Keep entries with `lang_code == "en"`.
  kaikki's per-language `kaikki.org-dictionary-English.jsonl` (3.1 GB) is marked
  deprecated, so we don't use it.
  - `tool/build_dictionary.py` (Python 3, standard library plus `wordfreq` at build time
    only) streams the file once and writes a SQLite file (data-model.md, "Dictionary
    database").
  - It keeps headword, part of speech, IPA pronunciation (the first General American or
    Received Pronunciation `sounds[].ipa`), glosses, up to two examples per sense, and
    tags such as "informal" or "archaic".
  - It drops etymology, translations, audio, descendants and non-English sections.
  - Form-of senses ("plural of mouse") and inflection tables (`forms`) become word-form
    rows, not entries (R5).
- **Trimming to the size budget**: the budget is ≤ 25 MB gzip (download and install
  size) and ≤ 90 MB on the device. The tool prints both sizes and fails above budget.
  Rules, applied in order until the budget is met:
  1. Drop senses whose only content is a form-of or alt-of link (they become word forms).
  2. Keep a single word if it ranks in `wordfreq`'s English top *N* (N = 150,000), or if
     a kept word is one of its forms. Keep a phrase (2–4 words) if every word in it ranks
     in the top 20,000.
  3. Keep proper nouns only within the top 50,000.
  4. Cap senses at 12 per part of speech, putting archaic and obsolete senses last.
  5. Keep usage examples only (at most two per sense, ≤ 200 characters); Wiktionary's
     dated quotations made up most of the file.
  **Measured (T004)**: the first build (N = 200,000, phrases of up to 8 words in the
  top 50,000, names in the top 100,000, quotations kept) was 39.6 MiB gzipped and
  104.5 MiB on disk, over budget. Rules 2, 3 and 5 as above give 166,061 headwords,
  23.6 MiB and 64.0 MiB.
  The chosen *N* and the measured sizes are recorded in quickstart.md. An estimate is
  150k–250k headwords.
- **Licence**: Wiktionary text is CC BY-SA 4.0. wiktextract's code is MIT, and we ship
  none of it. `wordfreq`'s data is CC BY-SA 4.0 and is used only to rank words; none of
  its data ships. The built file is a derived work under CC BY-SA 4.0. It ships with a
  `LICENSE` note naming Wiktionary, the dump date and the licence, and the build script
  is in the repository so anyone can rebuild it (clarification Q1, FR-034). kaikki.org
  asks to be cited; the attribution names it.
- **Where the built file lives**: it is not committed (tens of MB in git history).
  - Developers run `tool/build_dictionary.py --download` (about 3 GB of disk; estimate
    20–40 min).
  - Tests use a small dictionary built by the same script from a committed sample,
    `test/fixtures/dictionary/sample.jsonl`, of a few hundred real wiktextract lines.
  - Hosting a prebuilt file (for example as a GitHub release asset) would speed up setup
    and CI, but publishing it is an outward-facing step that needs the user's approval.
    It is listed as a follow-up.
- **Alternatives considered**:
  - WordNet: rejected in clarification Q1 (no pronunciations, few phrases).
  - kaikki's deprecated English file: it will be removed.
  - Parsing the Wiktionary XML dump ourselves: wiktextract already expands templates
    correctly, which is months of work.

## R2. Shipping the file: install on mobile, background download on the web

- **Decision**: one Flutter asset, `assets/dictionary/en.sqlite.gz`, serves every
  platform.
  - **Android and iOS** (clarification Q4): at app start, a background isolate unpacks it
    with `dart:io` `gzip` into the app support directory, as
    `dictionary/en-<version>.sqlite`. It writes to a temporary name and renames the file
    when done, so an interrupted unpack starts again next time. Older versions are
    deleted. Until the file is ready (estimate: a few seconds, once per install or
    upgrade), a lookup shows "Preparing the dictionary…" and then the result. It never
    needs the network. The database is opened read-only through
    `driftDatabase(native: DriftNativeOptions(databasePath: …))`.
  - **Web** (FR-022): nothing happens at app load. Flutter web fetches assets only on
    request, so the first load is unchanged (the quickstart checks this in DevTools). The
    download starts the first time the reader opens a book:
    1. `fetch` the asset URL;
    2. count bytes against `Content-Length` for progress;
    3. pipe through the browser's `DecompressionStream('gzip')`, so the main thread does
       no gzip work;
    4. hand the bytes to drift through `DriftWebOptions.initializeDatabase`, which stores
       the database in OPFS (or IndexedDB) under the name `dictionary-en-<version>`.
    drift calls `initializeDatabase` only when the database doesn't exist yet, so a failed
    or interrupted download is retried on the next book open, or when the reader tries a
    lookup again. After that, lookups work offline.
- **Risk**: `initializeDatabase` takes the whole file as one `Uint8List` (≤ 90 MB). The
  quickstart measures peak memory in Chrome on the S24. If that's too much, the fallback
  is to stream the decompressed bytes straight into drift's OPFS file for that name. That
  depends on drift's storage layout, so it's pinned to the drift version.
- **Why gzip in the asset**: the APK, the iOS bundle and web hosting all get the same
  small file. Web progress is then measured on a known size, without depending on the
  server compressing the response.
- **Alternatives considered**:
  - An uncompressed asset: smaller on the device only by skipping the unpack step, but
    the web download size would depend on the server's compression.
  - Downloading on mobile too: rejected in clarification Q4.
  - Opening the database straight from the APK: SQLite can't read compressed APK entries.

## R3. Query engine and schema shape

- **Decision**: a second, read-only drift database, `DictionaryDatabase`, separate from
  the app's database. A lookup is at most three indexed queries:
  1. exact entries by `key`;
  2. word forms by `form_key`;
  3. the base entries.
  Each entry row keeps its senses as a compact JSON blob, so one row gives the panel
  everything for one headword and part of speech.
- **Rationale**: a separate file can be swapped by version without migrations, and keeps
  user data small and separate (Principle VI). On native, drift's background isolate
  keeps queries off the UI thread; on the web, the drift worker does the same. Indexed
  lookups on a 90 MB file take milliseconds.
- **Alternatives considered**:
  - Normalised sense and example tables: more joins and no benefit, since the panel
    always shows a whole entry.
  - Full-text search: not needed for exact-key lookups.

## R4. From a gesture to a word (hit-testing and word rules)

- **Decision**: lookups use only `DocumentViewController.pagePointAt` and
  `ReaderDocument.loadPageText` (Principle III; no pdfrx text selection, CLAUDE.md risk
  5).
  1. `PageTextCache` keeps the last 8 pages' `PageText`. It loads the visible pages once
     the view settles (idle time), so a long-press rarely waits for extraction.
  2. **Hit test** (pure Dart): find the character whose rect contains the point. Failing
     that, take the nearest character on the same line within half a line height, and
     ignore whitespace. Nothing found means no lookup (edge case "empty space").
  3. **Word rules** (`WordExtractor`, pure Dart, FR-007 to FR-011):
     - A word is a run of letters, combining marks and digits, with inner apostrophes
       (' and ’ treated alike) and inner hyphens.
     - Leading and trailing punctuation and quotes are stripped.
     - A trailing `'s` / `’s` is removed for the lookup. Other contractions stay whole.
     - At a line end, a hyphen followed by a word on the next line (the next character's
       rect is lower and starts a line) gives two candidates: the joined word and the
       hyphenated word. The lookup tries them in that order (R5), so "exam-/ple" →
       "example", while "well-/known" falls back to "well-known".
     - A soft hyphen (U+00AD) is always joined.
     - **Measured (T005, pdfrx 2.6.5 / PDFium):** a normal line ends in `\r\n`; a
       line-end hyphen is replaced by U+0002 with no line break (`exam\u0002ple`,
       `well\u0002known`). So U+0002 between two letters is the line-break hyphen and
       gives both candidates (joined, then hyphenated); the "next line" case above is
       kept for other formats. A font without a Unicode map gives control characters
       (U+0001–U+0004 in `lookup_garbled.pdf`), which count as garbled.
     - The result is rejected if it has no letters, or if it is a number, a URL
       (scheme, `www.`, or a domain-like `a.b` with a known TLD) or an email address
       (FR-011).
     - Text with U+FFFD, private-use or control characters is "garbled". It is shown as
       extracted, with "No definition found" (FR-029).
  4. The selection is a character range on one page. It is drawn as a highlight of kind
     `selection` (contracts/lookup.md).
- **Phrases (FR-018, FR-019)**: handles move the start or end to word boundaries on the
  same page. The text between them is joined with single spaces, and line-break hyphens
  are handled as above. More than 8 words means the first word is looked up (edge case).
  A selection stops at the end of the page; a phrase that crosses pages is rare in
  practice and not supported (noted in contracts/lookup.md).
- **Alternatives considered**: pdfrx's `selectWord` (about 300 ms in the 2026-10-11
  spike; PDF-only API).

## R5. Inflections, phrases and ordering (the resolver)

- **Decision**: `LookupResolver` (pure Dart, over a `Lexicon` interface) turns candidates
  into an ordered result.
  1. For each candidate (R4), look up exact entries by `key`. The key is lowercase, NFC,
     with ’ → ' and runs of whitespace collapsed to one space.
  2. Look up word forms by key, giving base words and their relations ("plural of",
     "past tense of", "comparative of"…). Sources are wiktextract form-of senses and
     inflection tables.
  3. If neither gives anything, apply the rule fallback (`Lemmatiser`, pure Dart) and
     keep only candidate bases that exist as entries:
     - -s / -es / -ies;
     - -ed / -ied, including doubled consonants;
     - -ing, including restoring a final e;
     - -er / -est, including -ier / -iest.
  4. Order: exact entries first (FR-012: "building" the noun); then base entries, each
     with a note "running – form of run" built from the relation.
  5. Case (FR-010): the key is lowercase. When the selected word is capitalised and not
     at the start of a sentence, proper-noun entries come first; otherwise they come
     after common entries.
  6. Hyphenated words: whole word first; if it has no entry, its parts, each shown as a
     section (FR-009).
  7. Phrases: the phrase key first; if it has no entry, the first word's result under
     "No entry for "…"" (FR-019).
  **Measured (T042)**: with bases in the file's key order, SC-003 was 89.5% (dialect and
  abbreviation links such as "went → gan", "felt → FELT" came first). Two changes give
  99.5%: bases are ordered by frequency rank when queried, and the build drops form
  links tagged obsolete, archaic, dialectal, nonstandard, rare, misspelling, slang,
  abbreviation and similar.
- **Rationale**: Wiktionary's own form data covers irregular forms ("mice", "better",
  "went"). The small rule set covers regular forms missing from the trimmed data. Both
  are tested against SC-003's 200-word list.
- **Alternatives considered**: a Porter or Snowball stemmer (stems aren't words:
  "studi"); a lemma model (too heavy, not needed).

## R6. Gestures: long-press, mouse double-click, tap-to-define

- **Decision**: extend 002's `TapDetector`, which stays a raw `Listener` outside the
  gesture arena, rather than add a second detector.
  - **`onLongPress`**: one pointer held 500 ms within 18 px, with the view not moving.
    It fires while the pointer is still down. From then until pointer up, the view's
    panning and zooming are locked (`DocumentViewController.setInteractionLocked`).
    Flutter's `InteractiveViewer` reads `panEnabled` on every update, so the lock takes
    effect mid-gesture. Our `PagedDragHandler` ignores the pointer. Dragging on after
    the long-press moves the selection end (FR-018), as on Android.
  - **`onDoubleClick`** (mouse pointers only): a second click within 300 ms and 18 px.
    The single clicks still fire at once (spec assumption), so controls toggle twice and
    end as they were.
  - **Tap classification** with tap-to-define on (FR-016):
    1. link;
    2. edge zone;
    3. word (hit test, R4);
    4. show or hide the controls.
    With the panel open, a tap outside it closes it (FR-004), and a long-press selects a
    new word.
- **Rationale**: one place decides what a pointer means. The instant-tap guarantee from
  002 (no double-tap wait) is kept, which tap-to-define needs (FR-016).
- **Alternatives considered**: `LongPressGestureRecognizer` (joins the arena, so it would
  compete with pdfrx's pan recogniser and its timing would vary).

## R7. The panel

- **Decision**: the panel is an animated overlay inside the reader's `Stack`
  (`LookupPanel`), not a modal route. The page stays visible and can be read, and a new
  long-press can replace the lookup.
  - It opens at the bottom, or at the top when the selection's rect (from
    `DocumentViewController.pageRectToGlobal`) would be covered by a bottom panel of one
    third of the view (FR-003).
  - Its first height is ≤ 1/3 of the view; it can be dragged up to 85%. Inside, a
    `DraggableScrollableSheet` at the bottom and the same widget mirrored at the top.
  - It closes on a tap outside (via the tap classifier), a swipe toward its edge, Esc
    (reader shortcuts, panel first), the system back gesture (`PopScope`), or a page
    turn (position listener).
  - Content follows FR-005: headword, IPA, numbered senses grouped by part of speech,
    examples, and a source line ("Wiktionary · CC BY-SA 4.0 · About"). The panel takes
    the reader's theme colours (FR-033).
  - Every word in a definition is tappable (FR-024). Taps on words are hit-tested in
    the rich text and go through the same resolver, with a back stack in the panel.
- **Alternatives considered**: `showModalBottomSheet` (a modal barrier, no top
  variant, and it hides the page behind a scrim).

## R8. Latency budget and the "latest wins" rule

- **Decision**: the budget from the gesture being recognised to the panel's first frame
  showing the entry is ≤ 300 ms at p95 on the S24 (SC-002):

  | Step | Budget |
  |---|---|
  | Page text (cached / not cached) | ≤ 5 ms / ≤ 120 ms |
  | Hit test and word rules | ≤ 2 ms |
  | Resolver queries (≤ 3) | ≤ 30 ms |
  | Panel build and first frame | ≤ 50 ms |

  `LookupController` (Riverpod) gives each request an increasing id. A result is shown
  only if its id is still the latest (FR-014, SC-007), and older work is cancelled where
  possible.
- **Measurement**: `integration_test/lookup_timing_test.dart` (profile mode) long-presses
  20 words on different pages, half with page text not yet cached, and reports p50 and
  p95 through the perf driver, as 002 did.

## R9. Online search (Wikimedia)

- **Decision**: `OnlineDictionary` calls
  `GET https://en.wiktionary.org/api/rest_v1/page/definition/{word}`, only when the
  reader chooses "Search online" (clarification Q3, FR-021, FR-032).
  - Checked on 2026-10-13: HTTP 200; `access-control-allow-origin: *` (it works from the
    browser); `api-user-agent` allowed in CORS; no `Deprecation` or `Sunset` header.
    Profile `definition/0.8.1`.
  - The response is grouped by language. We read `en` (part of speech, definitions,
    examples) and strip HTML to plain text. Link text is kept, and its words are
    tappable like any other definition words.
  - Native requests send `Api-User-Agent: Potha/<version>
    (https://github.com/dwarftinker/potha)`, as Wikimedia's policy asks. That names the
    app, not the user; no cookies or identifiers are sent. On the web, the browser sends
    its own user agent.
  - Timeout 8 s. Errors and 404s show "Nothing found online" or "Couldn't reach
    Wiktionary" (User Story 6, scenario 4).
  - Results are not cached on disk. The history line records that the entry came from
    the online source.
- **Knowing whether we're offline** (User Story 6, scenario 3): `connectivity_plus`
  reports whether any network is connected, on Android, iOS and web. With none, the panel
  says online search is unavailable. With one, it offers the button, and a failed request
  still ends in a clear message.
- **Risk**: RESTBase, the service behind `rest_v1`, is being phased out. The endpoint has
  no deprecation header today. If it goes, online search fails gracefully (the message
  above) and the client is swapped; nothing else depends on it.
- **Alternatives considered**: dictionaryapi.dev (rejected in Q3); the MediaWiki action
  API's parsed HTML (heavier, and we'd have to parse it ourselves).

## R10. Lookup history

- **Decision**: drift schema v3 adds `lookup_history`, one row per (book, word key)
  (clarification Q5). The row is updated on every lookup the reader starts, including
  related words from inside the panel, not-found results and online results. The
  history sheet opens from the reader's top bar, with "This book" and "All books" tabs,
  newest first; "Clear" asks for confirmation. Removing a book cascades (FR-027).
- **Rationale**: an upsert by primary key is one statement per lookup. It runs after the
  panel is shown, so it is outside the 300 ms budget.

## R11. Preferences, hint and indicator

- **Decision**: `reader_preferences` (schema v3) gains `tap_to_define` (default false;
  clarification Q2) and `lookup_hint_shown` (default false).
  - The one-time hint (FR-006) is a dismissible banner the first time the reader opens.
    It explains long-press (double-click with a mouse) and mentions the setting.
  - The settings sheet gets a "Tap to define" switch.
  - The indicator (FR-017) is a small labelled chip ("Tap to define") in the top corner.
    It shows whether or not the controls are shown, and tapping it turns the mode off.

## R12. Attribution (FR-034)

- **Decision**:
  - The panel's source line opens "About this dictionary": source (Wiktionary, via
    wiktextract and kaikki.org), dump date, licence (CC BY-SA 4.0), and links to the
    licence and to the source. Links open after the same confirmation as 002's web
    links.
  - `LicenseRegistry.addLicense` adds the dictionary's licence to Flutter's licences page.
    The library's menu gets an "About Potha" item that opens it (there is no licences
    screen yet).
  - `assets/dictionary/LICENSE.md` ships with the file.

## R13. Dependencies added

| Package | Version | Licence | Maintenance | Platforms | Why |
|---|---|---|---|---|---|
| `http` | 1.6.0 (already resolved through pdfrx; made direct, as with url_launcher in 002) | BSD-3 | Dart team | all | Online search (R9) |
| `connectivity_plus` | latest release ≥ 2 weeks old, pinned at T001 | BSD-3 | Flutter Community Plus, active | Android, iOS, web | Offline state for the not-found panel (R9) |

Build-time only (not shipped): Python 3 and `wordfreq` (Apache-2.0 code, CC BY-SA 4.0
data) for `tool/build_dictionary.py`.

## R14. Testing strategy

- **Unit, written first and failing first** (Principle IV): `WordExtractor` (each rule in
  R4, with the spec's examples), hit test, line-break joining, `Lemmatiser`,
  `LookupResolver` ordering (against a fake `Lexicon`), key normalisation, the latest-wins
  controller, panel placement maths, Wikimedia response parsing (a recorded JSON
  fixture), the history repository, and the v2→v3 migration.
- **Dictionary file**: `DictionaryDatabase` queries against the sample dictionary built
  from `test/fixtures/dictionary/sample.jsonl`. The build script's own checks run on the
  same sample.
- **Accuracy (SC-001, SC-003, SC-004)**: `test/eval/` runs against the full built
  dictionary and is skipped when it is absent. The test sets live in
  `test/fixtures/dictionary/`:
  - `prose_1000.txt`: 1,000 tokens of public-domain prose, from Project Gutenberg;
  - `inflections_200.tsv`: form, expected base;
  - `hyphenation.tsv`: page-text snippets with line breaks, expected word.
  Each test reports its percentage and fails below 95%.
- **Widget tests** per story with the fakes from 002 plus a fake `Lexicon`: open and
  close (three ways), panel at the top, inflection note, tap-to-define, phrase
  selection, not found online and offline, copy, related words and back, history,
  rapid lookups (SC-007), screen-reader labels, and 200% text.
- **Device**: `integration_test/lookup_flow_test.dart` (long-press → panel → related →
  back → close; tap-to-define; history) and `lookup_timing_test.dart` (SC-002) on the
  S24. On the web: the background download, progress, then offline lookup in Chrome on
  the phone and on desktop (quickstart).
- **Privacy**: `no_network_test` gains a test that runs lookups, history and
  tap-to-define with network access forbidden. The online client is called only from
  the "Search online" action.
