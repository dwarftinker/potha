---

description: "Task list for feature 003: dictionary lookup"
---

# Tasks: Dictionary Lookup

**Input**: Design documents from `/specs/003-dictionary-lookup/`

**Prerequisites**: plan.md, spec.md, research.md, data-model.md, contracts/, quickstart.md

**Tests**: Included. The constitution (Principle IV) requires unit tests written first,
and failing, for core logic (word extraction, normalisation, lookup), and at least one
widget or integration test per user story.

**Organization**: Tasks are grouped by user story so each story can be built and tested
on its own.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies on incomplete tasks)
- **[Story]**: The user story the task belongs to (US1–US8 from spec.md)
- Paths are relative to the repository root (single Flutter project, see plan.md)

---

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Dependencies, the dictionary build, fixtures, and the two spikes that decide
the web store and the interaction lock.

- [X] T001 Add to pubspec.yaml: `http: ^1.6.0` (already resolved through pdfrx; comment "used directly for online search, 003 R9"); `connectivity_plus` pinned to the newest release at least two weeks old (check pub.dev; comment with the date to revisit, as with the other pins); the asset `assets/dictionary/en.sqlite.gz` and `assets/dictionary/LICENSE.md`. Add `assets/dictionary/en.sqlite.gz` and `build/dictionary/` to .gitignore. Run `flutter pub get` and confirm that no other resolved versions change in pubspec.lock
- [X] T002 [P] Write the shared key-normalisation vectors in test/fixtures/dictionary/key_vectors.tsv (input → key): case ("Hello" → "hello"), NFC (decomposed "café" → composed), apostrophes ("don’t" → "don't"), whitespace runs ("give   up" → "give up"), hyphens kept ("well-known"), and leading/trailing spaces. Both the Python build and Dart's `lookupKey` are tested against this file (research R5)
- [X] T003 Write tool/build_dictionary.py (Python 3, standard library + `wordfreq`), per research R1 and data-model.md "Dictionary database":
  - `--download` fetches kaikki.org's `raw-wiktextract-data.jsonl.gz` (English edition) into build/dictionary/ (resumable), then builds.
  - `--input <jsonl[.gz]>` builds from a given file; `--sample` builds build/fixtures/dict_sample.sqlite from test/fixtures/dictionary/sample.jsonl.
  - `--top N` (default 200000).
  - Keeps only `lang_code == "en"`.
  - Writes the tables `meta`, `entries` (`key`, `headword`, `pos`, `ipa`, `senses` JSON `[{"g","t","x"}]` ≤ 12 per entry, archaic/obsolete last, ≤ 2 examples per sense, `rank`) and `forms` (`form_key`, `base_key`, `relation` one of `plural|past|past_participle|present_participle|third_person|comparative|superlative|form`, unique pair, most specific relation kept, base must exist in entries).
  - Creates indexes on `entries.key` and `forms.form_key`.
  - Applies the trimming rules 1–4 in R1.
  - `VACUUM`s, gzips to assets/dictionary/en.sqlite.gz, and writes assets/dictionary/LICENSE.md (Wiktionary, wiktextract / kaikki.org, dump date, CC BY-SA 4.0 with link).
  - Prints headwords, forms, size gzipped and size on disk; exits non-zero above 25 MB gzip or 90 MB on disk.
  - Has a self-test mode `--check` that verifies the key vectors from T002.
- [X] T004 Make the sample first, then the full build. The sample must not wait for the 2.8 GB download (analysis G2).
  - Add `--fetch-sample <words.txt>` to the script: for each word, fetch the per-word wiktextract JSONL that kaikki.org links from the word's page (English edition), keep the `lang_code == "en"` lines, and write them to test/fixtures/dictionary/sample.jsonl. Send no identifying data beyond a `User-Agent` of `Potha-build (https://github.com/dwarftinker/potha)`. If kaikki.org no longer serves per-word files, add `--extract-sample` instead and cut the lines from the full dump once it is downloaded.
  - The words, every word the tests use: melancholy, run, running, mouse, mice, good, better, study, studied, building, build, example, well-known, well, known, hello, reader, don't, give, give up, in, spite, in spite of, turkey, Turkey, serendipity, ephemeral, plus a few made-up control words that have no entry. Keep that word list in test/fixtures/dictionary/sample_words.txt.
  - Check that `--sample` builds; T013 can start from here.
  - Then run `python3 tool/build_dictionary.py --download` (in the background, alongside Phase 2). Record N, headwords, the gzip size and the on-disk size in the table in specs/003-dictionary-lookup/quickstart.md; lower `--top` if over budget.
- [X] T005 [P] Extend tool/make_fixtures.py with a `--lookup` flag writing test/fixtures/lookup_prose.pdf. It is 3 text pages:
  - page 1: "melancholy", "running", "mice", "better", "studied", "building", “Hello,”, "reader's", "don't", "give up", "in spite of", "Turkey", a number, a URL and an email address, each at known positions;
  - page 2: "exam-" / "ple" and "well-" / "known" split across line ends;
  - page 3: words in the bottom third, for top placement.
  Also write test/fixtures/lookup_garbled.pdf (text in a Type 3 font with no ToUnicode map, so extraction gives unmapped characters). Document both in the script header
- [ ] T006 Spike the web dictionary store (research R2) in the throwaway app ../potha_spike, on the S24 in Chrome over `adb reverse`:
  1. `fetch` the gzip asset with progress;
  2. `DecompressionStream('gzip')`;
  3. `driftDatabase(name: 'dictionary-en-test', web: DriftWebOptions(initializeDatabase: …))`;
  4. one query.
  Measure download and set-up time and peak memory (Chrome remote DevTools). Record the result, and whether the direct-to-OPFS fallback is needed, in specs/003-dictionary-lookup/research.md R2
- [ ] T007 Spike the interaction lock (research R6) in ../potha_spike: a `Listener` long-press (500 ms) over `PdfViewer` that sets `panEnabled` / `scaleEnabled` false until pointer up, then drags without panning. Test it on the S24 and in Chrome on the phone, in paged and continuous layouts. Record the result in research.md R6 (works, or the alternative used)

**Checkpoint**: The dictionary builds within budget, the sample and fixtures exist, and both risky mechanisms are confirmed before the lookup code is built.

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Schema v3, lookup keys, the dictionary database and its platform stores, the view additions, page-text cache, the extended tap detector and test fakes.

**⚠️ CRITICAL**: No user story work can begin until this phase is complete.

- [X] T008 [P] Write the v2 → v3 migration test in test/unit/db/migration_test.dart. A v2 database with two `reading_progress` rows and `reader_preferences` row 1 (theme `dark`) migrates to v3:
  - the rows are kept;
  - `reader_preferences` has `tap_to_define` = false and `lookup_hint_shown` = false;
  - `lookup_history` exists with PK (book_id, word_key) and cascades on book delete;
  - `page` < 1 and `count` < 1 are rejected.
- [X] T009 Change lib/core/db/app_database.dart exactly as data-model.md:
  - new table `LookupHistory`: `book_id` text FK → books.id cascade delete; `word_key` text; PK (book_id, word_key); `word` text; `headword` text nullable "null if not found"; `source` textEnum `offline|online|none`; `page` int check ≥ 1; `looked_up_at` datetime UTC; `count` int default 1 check ≥ 1; index on `looked_up_at`.
  - `ReaderPreferences.tapToDefine` bool default false; `ReaderPreferences.lookupHintShown` bool default false.
  - `schemaVersion` 3 with `from2To3` in `stepByStep`.
  Then run `dart run build_runner build`, `dart run drift_dev make-migrations` and `dart run drift_dev schema generate drift_schemas/app_database/ test/unit/db/generated/`; make T008 pass
- [X] T010 [P] Unit-test `lookupKey` in test/unit/dictionary/lookup_key_test.dart against test/fixtures/dictionary/key_vectors.tsv
- [X] T011 Implement `lookupKey` in lib/core/dictionary/lookup_key.dart (core, not the reader feature: the dictionary layer uses it, analysis F2); make T010 pass
- [X] T012 [P] Create lib/core/dictionary/lexicon.dart per contracts/lookup.md:
  - `Lexicon` (`language`, `info`, `entries(key)`, `formsOf(key)`, `hasEntry(key)`);
  - `DictionaryInfo` (source, licence, licenceUrl, sourceUrl, dumpDate, version);
  - `DictionaryEntry` (headword, pos, ipa, senses);
  - `Sense` (gloss, tags, examples);
  - `WordFormLink` (form, base, relation enum matching the build script's values);
  - `DictionaryStatus` sealed (`notStarted`, `downloading(bytes, total)`, `unpacking`, `ready`, `failed(offline | error)`);
  - the `OnlineDictionary` interface and `OnlineResult` sealed (`found(entries)`, `notFound`, `failed`); the Wikimedia client comes in T068.
  Also create lib/core/platform/network_status.dart: the `NetworkStatus` interface (`isOnline`, `changes`), its `connectivity_plus` implementation and `networkStatusProvider`. T018 and T026 need both interfaces in this phase (analysis F1).
- [X] T013 [P] Write test/unit/dictionary/dictionary_database_test.dart over build/fixtures/dict_sample.sqlite (skipped with a message if it is missing; the message gives the build command):
  - `entries('melancholy')` has a noun and an adjective with glosses and an IPA;
  - `formsOf('mice')` → mouse, plural;
  - `formsOf('better')` includes good, comparative;
  - `entries('give up')` exists;
  - `info` reads the `meta` table;
  - an unknown key gives [].
- [X] T014 Implement `DictionaryDatabase` (read-only drift database with `customSelect` queries, implementing `Lexicon`; JSON senses parsed once per row) in lib/core/dictionary/dictionary_database.dart; make T013 pass
- [X] T015 [P] Unit-test the io store in test/unit/dictionary/dictionary_store_io_test.dart with a temporary support directory and a small gzip asset:
  - status goes `unpacking` → `ready`;
  - the file is written under a temporary name and renamed;
  - an interrupted unpack (temp file left) is redone;
  - a second `ensureStarted` doesn't unpack again;
  - older `en-*.sqlite` files are deleted once ready;
  - `ready` completes with a working `Lexicon`.
- [X] T016 Create lib/core/dictionary/dictionary_store.dart (the `DictionaryStore` interface, `dictionaryStoreProvider` choosing io or web by conditional import) and lib/core/dictionary/dictionary_store_io.dart. The io store unpacks the asset in `Isolate.run` with `gzip` into `<app support>/dictionary/en-<version>.sqlite` and opens it read-only via `DriftNativeOptions(databasePath:)`. The version comes from a small `assets/dictionary/version` line written by T003 (add it to the assets list). Make T015 pass
- [X] T017 [P] Write test/web/dictionary_store_web_test.dart (`flutter test --platform chrome`). It serves a small gzip dictionary, and checks:
  - progress events rise to 100%, then `ready`;
  - a lookup works afterwards;
  - a fetch failure gives `failed(error)`, and the next `ensureStarted` retries;
  - with `navigator.onLine` false, it gives `failed(offline)`;
  - no request happens before `ensureStarted` (FR-022).
- [X] T018 Implement lib/core/dictionary/dictionary_store_web.dart: `fetch` with `Content-Length` progress, `DecompressionStream('gzip')` through `package:web`, and `DriftWebOptions.initializeDatabase` under the name `dictionary-en-<version>`, deleting older names. If T006 showed the fallback is needed, stream into OPFS instead and note it in the file header. Make T017 pass
- [X] T019 [P] Extend lib/core/document/document_format.dart per contracts/lookup.md:
  - `DocumentViewController.pageRectToGlobal(int page, Rect normalised)` and `setInteractionLocked(bool)`;
  - `enum HighlightKind { match, activeMatch, selection }` replacing `PageHighlight.active`;
  - `ReaderViewConfig.selectionColor`.
  Update the search code (lib/features/reader/ui/search_panel.dart, reader_screen.dart) and the fakes in test/widget/reader_test_app.dart to the new highlight kinds; all 002 tests must still pass
- [X] T020 Implement the additions in lib/core/document/pdf/pdf_view_controller.dart (page rect via the layout and `documentToGlobal`) and lib/core/document/pdf/pdf_document_view.dart:
  - the selection highlight is painted inside the theme filter in its pre-inverted colour, like 002's highlights;
  - the lock rebuilds `PdfViewerParams` with `panEnabled` / `scaleEnabled` false, and `PagedDragHandler` ignores pointers while locked, per T007's result.
  Add cases to test/widget/pdf_view_test.dart: `pageRectToGlobal` maps a known rect on three_pages.pdf in both modes and after zoom, and the lock blocks a drag
- [X] T021 [P] Unit-test `PageTextCache` in test/unit/reader/page_text_cache_test.dart with a fake document:
  - it keeps 8 pages (LRU);
  - concurrent requests for one page load it once;
  - `prefetch(pages)` loads only uncached pages;
  - a failed load isn't cached.
- [X] T022 Implement `PageTextCache` in lib/features/reader/data/page_text_cache.dart; make T021 pass
- [X] T023 [P] Extend test/widget/tap_detector_test.dart (fake time):
  - `onLongPress` fires at 500 ms while held, and not if the pointer moved over 18 px, a second pointer went down, or the view moved;
  - after a long-press, moves go to `onLongPressMove` and up to `onLongPressEnd`, with no `onTap`;
  - with a mouse, two clicks within 300 ms and 18 px fire `onTap` twice and `onDoubleClick` once;
  - a touch double tap fires no `onDoubleClick`;
  - taps still fire on pointer up with no wait.
- [X] T024 Extend lib/features/reader/ui/tap_detector.dart with `onLongPress`, `onLongPressMove`, `onLongPressEnd` and `onDoubleClick` (research R6, contracts/lookup.md table); make T023 pass
- [X] T025 [P] Extend `ReaderRepository` and its test (lib/features/reader/data/reader_repository.dart, test/unit/reader/reader_repository_test.dart): `watchPreferences` includes `tapToDefine` and `lookupHintShown`; add `setTapToDefine(bool)` and `markLookupHintShown()`
- [X] T026 [P] Add lookup fakes to test/widget/reader_test_app.dart:
  - `FakeLexicon` (entries and forms from a map);
  - `FakeDictionaryStore` (status controllable, `ready` completer);
  - `FakeOnlineDictionary` (scripted results, records calls);
  - `FakeNetworkStatus`.
  Register them through the providers; `FakeReaderDocument` page texts get per-character rects for word layouts (a helper that lays out lines of words)

**Checkpoint**: Schema v3 migrates; the sample dictionary opens through `Lexicon` on host, io and web; the view reports page rects and can be locked; long-press is detected; all 001 and 002 tests pass.

---

## Phase 3: User Story 1 - Look up a word by selecting it (Priority: P1) 🎯 MVP

**Goal**: Long-press (or double-click with a mouse) selects a word and opens its definition in a panel that never covers it; three ways to close; a one-time hint; attribution.

**Independent Test**: Quickstart 1–5, 8–11, 19: long-press "melancholy", read it, close it three ways; desktop double-click; scanned and garbled pages.

### Tests for User Story 1 (write first, confirm they fail) ⚠️

- [X] T027 [P] [US1] Unit-test `hitTest` and `WordExtractor.wordAt` / `queryFor` in test/unit/reader/word_extractor_test.dart, using page texts built from lines with character rects:
  - **Hit test**: the character under the point; the nearest character on the line within half a line height; whitespace and gaps give null.
  - **Word rules** (FR-007 to FR-011):
    - “Hello,” → hello;
    - "reader's" / "reader’s" → reader;
    - "don't" / "don’t" stay whole;
    - "exam-" + line break + "ple" → candidates [example, exam-ple];
    - "well-" + line break + "known" → [wellknown, well-known];
    - an inline "well-known" → [well-known, then parts];
    - a soft hyphen is always joined;
    - numbers, "https://x.org", "www.x.org", "potha.app" and "a@b.org" → null;
    - text with U+FFFD or private-use characters → `garbled`;
    - capitalised mid-sentence ("in Turkey") vs at the sentence start.
- [X] T028 [P] [US1] Unit-test `panelPlacement` in test/unit/reader/panel_placement_test.dart: a word in the top two thirds gives the bottom panel at ≤ 1/3 of the view height; a word whose rect would be covered gives the top; when even the top would cover it (a word filling the middle), the edge farther from it is used; the first height is never over 1/3 (FR-003)
- [X] T029 [P] [US1] Unit-test `LookupController` in test/unit/reader/lookup_controller_test.dart (fake lexicon, store and cache):
  - a long-press point resolves to `shown` with the selection;
  - an empty spot leaves `idle`;
  - a page without text gives `noText`;
  - garbled text gives `notFound` with the extracted text;
  - while the store isn't ready → `preparing(progress)`, then `shown` once ready;
  - **latest wins** (FR-014, SC-007): ten requests where earlier ones resolve later end showing the tenth;
  - `close()` clears the selection.
- [X] T030 [P] [US1] Widget-test the main flow in test/widget/lookup_panel_test.dart (fakes):
  - long-press a word → selection highlight + panel with headword, IPA, "Noun" / "Adjective" groups, numbered senses, examples (FR-005);
  - it closes on a tap outside, a swipe down, Esc, and system back (`handlePopRoute`), each clearing the selection;
  - a page turn closes it;
  - a word in the bottom third opens the panel at the top;
  - a mouse double-click looks up and leaves the controls as they were;
  - a long-press on a no-text page shows "This page has no selectable text";
  - the panel footer opens "About this dictionary" with source, licence and dump date (FR-034).
- [X] T031 [P] [US1] Widget-test the hint in test/widget/lookup_hint_test.dart: shown on the first reader open with the long-press, double-click and tap-to-define wording; Got it hides it and sets `lookupHintShown`; not shown on the next open (FR-006)

### Implementation for User Story 1

- [X] T032 [P] [US1] Implement `hitTest` and `WordExtractor` (`wordAt`, `queryFor`; `extendTo` comes in US5) in lib/features/reader/domain/word_extractor.dart, with `WordSelection` and `LookupQuery` per data-model.md; make T027 pass
- [X] T033 [P] [US1] Implement `panelPlacement` in lib/features/reader/domain/panel_placement.dart; make T028 pass
- [X] T034 [P] [US1] Test first, then implement a first `LookupResolver` (Principle IV; analysis C1):
  - Write test/unit/reader/lookup_resolver_test.dart (fake lexicon): an exact entry is returned; candidates are tried in order, so the joined line-break word ("example") wins over the hyphenated one ("exam-ple"); no entry gives `notFound`. Run it and see it fail.
  - Then implement lib/features/reader/domain/lookup_resolver.dart: exact entries for each candidate in order, else `notFound` (inflections come in US2), with `LookupResult` per data-model.md; make the test pass.
- [X] T035 [US1] Implement `LookupController` and its provider in lib/features/reader/lookup_controller.dart: request ids, `lookUpAt`, `close`, the `LookupState` states in data-model.md, and the store status mapped to `preparing`; make T029 pass
- [X] T036 [US1] Create lib/features/reader/ui/lookup_panel.dart, per contracts/lookup-ui.md "Panel":
  - an animated overlay, bottom or top from `panelPlacement`, with a draggable sheet (first height ≤ 1/3, max 85%);
  - the entry view: headword, IPA, sections by part of speech, numbered senses, tags, examples;
  - the not-found view and the preparing / downloading view;
  - a source footer;
  - reader theme colours;
  - a swipe toward its edge closes it.
- [X] T037 [P] [US1] Create lib/features/reader/ui/dictionary_about.dart (dialog: source, dump date, licence, links opened through 002's web-link confirmation and `LinkOpener`). Register the dictionary licence with `LicenseRegistry.addLicense` (reading assets/dictionary/LICENSE.md) in lib/main.dart. Add "About Potha" to the library menu in lib/features/library/ui/library_screen.dart, opening `showLicensePage` (FR-034)
- [X] T038 [P] [US1] Create lib/features/reader/ui/lookup_hint.dart (dismissible banner, FR-006)
- [X] T039 [US1] Wire lookup into lib/features/reader/ui/reader_screen.dart:
  - `TapDetector.onLongPress` / `onDoubleClick` → `LookupController.lookUpAt`, with the interaction lock from long-press until pointer up;
  - the selection as a `HighlightKind.selection` highlight;
  - the panel in the reader's `Stack`;
  - tap classification: with the panel open, a tap outside closes it;
  - close on a page change;
  - `PopScope` closes the panel first;
  - "no selectable text" snackbar;
  - the hint on first open;
  - `DictionaryStore.ensureStarted()` on open (FR-022).
  Update lib/features/reader/ui/reader_shortcuts.dart so Esc closes the panel first. Make T030 and T031 pass

**Checkpoint**: Long-press and double-click look up exact words from the dictionary in a panel that never covers the word; quickstart 1–5, 8–11 and 19 pass with the sample dictionary.

---

## Phase 4: User Story 2 - Get the right entry for inflected words (Priority: P1)

**Goal**: Inflected forms resolve to base words with a note; the exact form's own entry comes first; capitalisation and hyphenated words are ordered as research R5.

**Independent Test**: Quickstart 6–7: "running", "mice", "better", "studied", "building"; "well-known", "Turkey".

### Tests for User Story 2 (write first, confirm they fail) ⚠️

- [X] T040 [P] [US2] Unit-test `Lemmatiser` in test/unit/reader/lemmatiser_test.dart. Each rule gives candidate bases:
  - studies → study; studied → study; stopped → stop; running → run; making → make; boxes → box; happier → happy; biggest → big;
  - candidates are only kept if `hasEntry` is true (fake lexicon);
  - irregular forms are not invented ("mice" gives nothing from rules).
- [X] T041 [P] [US2] Extend test/unit/reader/lookup_resolver_test.dart (from T034) with inflection ordering (fake lexicon):
  - mice → mouse with "mice – plural of mouse";
  - better → better's own entries first, then good with "comparative of good";
  - building → noun building first, then build with "form of build";
  - studied → study via forms, or via rules when forms are missing;
  - "Turkey" mid-sentence → proper noun first; at the start of a sentence → common first (FR-010);
  - well-known whole, else its parts as sections (FR-009);
  - the joined line-break candidate wins over the hyphenated one when both exist;
  - no entry and no base → `notFound`.
- [X] T042 [P] [US2] Write test/eval/inflections_eval_test.dart and test/fixtures/dictionary/inflections_200.tsv (200 common inflected forms with the expected base: regular, irregular, comparatives, participles). Against the full dictionary (skipped if absent), it reports the share whose first base is correct and fails below 95% (SC-003)
- [X] T043 [P] [US2] Widget-test notes in test/widget/lookup_inflection_test.dart: looking up "mice" shows the "mouse" entry under "mice – plural of mouse"; "building" shows the noun first and then "build"

### Implementation for User Story 2

- [X] T044 [P] [US2] Implement `Lemmatiser` in lib/features/reader/domain/lemmatiser.dart; make T040 pass
- [X] T045 [US2] Extend `LookupResolver` with forms, the rule fallback, notes (relation → wording: "plural of", "past tense of", "past participle of", "present participle of", "third-person singular of", "comparative of", "superlative of", "form of"), capitalisation ordering and hyphen parts; make T041 pass
- [X] T046 [US2] Show notes and multiple entry sections in lib/features/reader/ui/lookup_panel.dart; make T043 pass; run T042 against the full dictionary and record the result in quickstart.md

**Checkpoint**: Inflected words resolve correctly; SC-003 measured.

---

## Phase 5: User Story 3 - Works offline (Priority: P1)

**Goal**: Lookups work with no network on every platform (bundled on mobile, downloaded once on the web) within 300 ms.

**Independent Test**: Quickstart 12, 22–25 and the timing run.

### Tests for User Story 3 (write first, confirm they fail) ⚠️

- [X] T047 [P] [US3] Widget-test dictionary readiness in test/widget/lookup_dictionary_status_test.dart (fake store):
  - **web**: `downloading` shows "Downloading the dictionary… 42%", then the definition on `ready`;
  - **web**: `failed(offline)` shows "The dictionary needs an internet connection once to download.";
  - **web**: a later lookup retries;
  - **mobile**: `unpacking` shows "Preparing the dictionary…", then the result.
- [X] T048 [P] [US3] Extend test/unit/no_network_test.dart: with HTTP forbidden, look up words via `LookupController` over the sample dictionary (exact, inflected, not found), record history, and toggle tap-to-define. Expect no HTTP attempts, and `OnlineDictionary` is never called (FR-032)
- [X] T049 [P] [US3] Write test/eval/coverage_eval_test.dart and test/fixtures/dictionary/prose_1000.txt (1,000 word tokens from public-domain Project Gutenberg prose, names, numbers and symbols removed, with the source cited in the file header). Each token runs through `WordExtractor` rules + `LookupResolver` on the full dictionary (skipped if absent); it reports the share with an entry and fails below 95% (SC-001)
- [ ] T050 [P] [US3] Write integration_test/lookup_timing_test.dart (profile, `flutter drive --no-dds`, as reader_perf_test.dart). Import lookup_prose.pdf and text_500.pdf, then long-press 20 words on different pages, half on pages whose text isn't cached yet. Measure from the long-press recognised to the panel's first frame showing the entry; report p50 and p95 through `test_driver/perf_driver.dart`. p95 ≤ 300 ms is the target (SC-002, research R8)

### Implementation for User Story 3

- [X] T051 [US3] Show the store states in lib/features/reader/ui/lookup_panel.dart (progress, offline message, preparing); make T047 pass
- [X] T052 [US3] Start the mobile unpack at app start through lib/core/dictionary/dictionary_warmup.dart: `startDictionaryUnpack()` by conditional import, which starts the io store's `ensureStarted` after the first frame (dictionary_warmup_io.dart) and does nothing on the web, so the web first-load bundle doesn't gain the store (analysis F3). lib/app.dart only calls `startDictionaryUnpack()`; the web stays on book open. In lib/features/reader/ui/reader_screen.dart, prefetch the visible pages' text into `PageTextCache` when the view settles (idle, after position changes stop for 300 ms)
- [ ] T053 [US3] Run T050 on the S24 and T049 against the full dictionary; record both in specs/003-dictionary-lookup/quickstart.md "Measurements". If p95 > 300 ms, profile and fix by the R8 breakdown before continuing (Principle V)

**Checkpoint**: P1 complete: a releasable offline lookup. Quickstart 1–12 and 22–25 pass on the S24 and in Chrome.

---

## Phase 6: User Story 4 - Tap-to-define mode (Priority: P2)

**Goal**: An off-by-default mode where one tap on a word looks it up, with an indicator; edge taps still turn pages.

**Independent Test**: Quickstart 13.

### Tests for User Story 4 (write first, confirm they fail) ⚠️

- [X] T054 [P] [US4] Extend test/unit/reader/tap_zones_test.dart for the classification order with tap-to-define on: link > edge zone > word > controls; with it off, a word gives controls (contracts/lookup-ui.md)
- [X] T055 [P] [US4] Widget-test in test/widget/lookup_tap_to_define_test.dart:
  - off by default (a tap on a word toggles the controls);
  - turned on from settings: a tap on a word opens the panel immediately (no 300 ms wait, using fake time); an edge tap on a word turns the page; a tap on empty space toggles the controls;
  - the chip "Tap to define" is visible with the controls hidden; tapping it asks to turn the mode off, and Turn off does so;
  - the setting persists across reader reopen (FR-015 to FR-017).

### Implementation for User Story 4

- [X] T056 [US4] Extend the tap classification in lib/features/reader/domain/tap_zones.dart with the word case; make T054 pass
- [X] T057 [P] [US4] Create lib/features/reader/ui/tap_to_define_chip.dart (small labelled chip with the turn-off confirmation)
- [X] T058 [US4] Add the "Tap to define" switch to lib/features/reader/ui/settings_sheet.dart. Wire the mode, the chip and word taps in lib/features/reader/ui/reader_screen.dart; make T055 pass

**Checkpoint**: Tap-to-define works and is visible; off by default.

---

## Phase 7: User Story 5 - Look up a phrase (Priority: P2)

**Goal**: The selection extends word by word (handles, long-press drag, mouse drag); phrases are looked up when the change ends.

**Independent Test**: Quickstart 14.

### Tests for User Story 5 (write first, confirm they fail) ⚠️

- [X] T059 [P] [US5] Unit-test `WordExtractor.extendTo` in test/unit/reader/word_extractor_test.dart:
  - growing and shrinking snaps to word boundaries in both directions;
  - a line break between words gives single spaces;
  - a line-break hyphen inside the phrase is joined;
  - the selection stops at the page end;
  - more than 8 words gives `isPhrase` false, so the first word is looked up.
- [X] T060 [P] [US5] Extend test/unit/reader/lookup_resolver_test.dart: "give up" → the phrase entry; "in spite of" → the phrase entry; an unknown phrase → the first word's result with `phraseNotFound` (FR-019)
- [X] T061 [P] [US5] Widget-test in test/widget/lookup_phrase_test.dart:
  - long-press "give" then drag to "up" → highlight grows, and the panel shows "give up" after lift;
  - dragging the end handle to "of" in "in spite of" → the phrase entry;
  - a made-up phrase → the "No entry for "…"" note with the first word's entry;
  - handles are ≥ 48 dp and labelled.

### Implementation for User Story 5

- [X] T062 [US5] Implement `extendTo` and phrase queries in lib/features/reader/domain/word_extractor.dart, and phrase handling in lookup_resolver.dart; make T059 and T060 pass
- [X] T063 [P] [US5] Create lib/features/reader/ui/selection_handles.dart. Handles are positioned with `pageRectToGlobal`; dragging uses a `Listener`, sets the interaction lock, and maps pointer positions with `pagePointAt` + `hitTest`
- [X] T064 [US5] Wire long-press drag (`onLongPressMove` / `onLongPressEnd`), mouse drag from the selection, and the handles into lib/features/reader/ui/reader_screen.dart and `LookupController.extendSelection` / `endExtend`. Show the phrase note in lookup_panel.dart; make T061 pass

**Checkpoint**: Phrases can be selected and looked up on touch and with a mouse.

---

## Phase 8: User Story 6 - Not found, and searching online (Priority: P2)

**Goal**: A clear not-found state; "Search online" via Wikimedia only when online and only on request.

**Independent Test**: Quickstart 15.

### Tests for User Story 6 (write first, confirm they fail) ⚠️

- [X] T065 [P] [US6] Record Wikimedia responses into test/fixtures/dictionary/: `wikimedia_serendipity.json` (found) and `wikimedia_404.json`, fetched with `curl` sending only `Api-User-Agent: Potha/dev (https://github.com/dwarftinker/potha)` and no personal data. Unit-test the parser and client in test/unit/dictionary/online_dictionary_test.dart with a `MockClient`:
  - the `en` section maps to entries, with HTML stripped and link text kept;
  - other languages are ignored;
  - 404 → `notFound`;
  - a timeout (8 s, fake) or error → `failed`;
  - the request URL encodes the word;
  - the `Api-User-Agent` header is present on io and holds no user data.
- [X] T066 [P] [US6] Extend test/unit/reader/lookup_controller_test.dart:
  - not found + online → `notFound(available)`; `searchOnline()` → `searching` → `shown(source: online)`, or `notFound(failed)`;
  - not found + offline → `notFound(unavailable)`, and `searchOnline` does nothing;
  - the online client is never called without `searchOnline()`.
- [X] T067 [P] [US6] Widget-test in test/widget/lookup_not_found_test.dart:
  - "No definition found for "word"" with the "Search online" button when online; the result is marked "From Wiktionary online";
  - "Nothing found online" and "Couldn't reach Wiktionary" messages;
  - offline: "Online search isn't available offline" and no button;
  - the panel closes normally afterwards (US6 scenarios 1–4).

### Implementation for User Story 6

- [X] T068 [P] [US6] Implement `OnlineDictionary` (http, Wikimedia REST definition endpoint, research R9) in lib/core/dictionary/online_dictionary.dart; make T065 pass
- [X] T069 [US6] Moved: `NetworkStatus` and its provider are created in T012 (analysis F1). Here, check that `networkStatusProvider` updates the panel live: going offline while "Search online" is shown replaces it with "Online search isn't available offline" (extend test/widget/lookup_not_found_test.dart)
- [X] T070 [US6] Add `searchOnline` and the online states to lib/features/reader/lookup_controller.dart, and the not-found and online views to lookup_panel.dart; make T066 and T067 pass

**Checkpoint**: Not-found is never a dead end online, and nothing leaves the device without the reader's action.

---

## Phase 9: User Story 7 - Copy and related words (Priority: P3)

**Goal**: Copy the word; tap words inside definitions to look them up, with Back.

**Independent Test**: Quickstart 16.

### Tests for User Story 7 (write first, confirm they fail) ⚠️

- [X] T071 [P] [US7] Extend test/unit/reader/lookup_controller_test.dart: `lookUpWord` pushes onto the back stack; `back()` pops it; a new page lookup clears the stack; latest-wins also applies to related lookups
- [X] T072 [P] [US7] Widget-test in test/widget/lookup_related_test.dart: Copy puts the headword on the clipboard (mock `SystemChannels.platform`) and shows "Copied"; tapping a word in a definition opens its entry with Back; two steps and Back twice return to the first word (FR-023, FR-024)

### Implementation for User Story 7

- [X] T073 [US7] Add `lookUpWord` / `back` to lib/features/reader/lookup_controller.dart. In lib/features/reader/ui/lookup_panel.dart: make definition and example words tappable (word spans with recognisers, using the extractor's word rules), and add Back and Copy (`Clipboard.setData` + snackbar). Make T071 and T072 pass

**Checkpoint**: Related-word browsing and copy work.

---

## Phase 10: User Story 8 - Lookup history (Priority: P3)

**Goal**: One line per word per book, viewable per book and for all books, reopenable, clearable.

**Independent Test**: Quickstart 17.

### Tests for User Story 8 (write first, confirm they fail) ⚠️

- [X] T074 [P] [US8] Unit-test `HistoryRepository` in test/unit/reader/history_repository_test.dart (in-memory database):
  - `record` creates a line with count 1, and a second lookup of the same key in the same book updates `word`, `headword`, `page`, `looked_up_at` and makes count 2;
  - the same word in another book is a separate line;
  - `watchBook` and `watchAll` are newest first, with book titles in `watchAll`;
  - `clearBook` / `clearAll`;
  - removing a book through `LibraryRepository` removes its lines (FR-025 to FR-027).
- [X] T075 [P] [US8] Widget-test in test/widget/lookup_history_test.dart:
  - after lookups in two books, the reader's "Lookup history" lists this book's words once each, with page, date and "×2";
  - "All books" shows titles;
  - choosing a row opens its definition;
  - Clear asks for confirmation and empties the chosen scope;
  - empty state text;
  - lookups are recorded only after the panel shows.

### Implementation for User Story 8

- [X] T076 [US8] Implement `HistoryRepository` and its provider in lib/features/reader/data/history_repository.dart (upsert on (book_id, word_key)); make T074 pass
- [X] T077 [P] [US8] Create lib/features/reader/ui/history_sheet.dart (tabs, rows, Clear with confirmation, empty state)
- [X] T078 [US8] Record each lookup the reader starts (including related, not-found and online) from lib/features/reader/lookup_controller.dart after the panel shows. Add the "Lookup history" button to lib/features/reader/ui/reader_bars.dart, and open the sheet and its lookups from reader_screen.dart; make T075 pass

**Checkpoint**: All stories done.

---

## Phase 11: Polish & Cross-Cutting Concerns

**Purpose**: Hyphenation accuracy, device and browser verification, accessibility and docs.

- [X] T079 [P] Write test/eval/hyphenation_eval_test.dart and test/fixtures/dictionary/hyphenation.tsv (at least 100 cases: line-break-split ordinary words, and genuine hyphenated compounds split at their hyphen). Run them through `WordExtractor` + `LookupResolver` on the full dictionary (skipped if absent); report the share joined correctly; fail below 95% or if any genuine compound is wrongly joined (SC-004). Record the result in quickstart.md
- [ ] T080 [P] Write integration_test/lookup_flow_test.dart for the S24 and Chrome, with lookup_prose.pdf imported through `XFile` (as in 001/002):
  - long-press "melancholy" → panel → tap a definition word → Back → close by system back;
  - "mice" note;
  - long-press drag "give" → "up";
  - tap-to-define on, tap a word, turn it off with the chip;
  - history shows the words;
  - scanned.pdf long-press message;
  - zoomed to 3× and in continuous mode: long-press a word, check the selection rect sits on the word and the panel doesn't cover it (FR-030, analysis G1).
- [X] T081 [P] Extend test/widget/accessibility_test.dart for lookup (written as test/widget/lookup_accessibility_test.dart, next to 002's reader_accessibility_test.dart):
  - the panel, handles, chip, hint, history sheet and About have labels;
  - the panel is announced, and each sense is a separate node (FR-033);
  - `androidTapTargetGuideline` and `textContrastGuideline` pass in the light, dark and sepia themes;
  - at text scale 2.0 the panel keeps its first size, scrolls, and doesn't overflow.
- [ ] T082 Check the web build: run `tool/build_web.sh` and serve it.
  - The first load makes no dictionary request and its size is unchanged from 002 (record it); `main.dart.js` contains no dictionary-store code (T052's warm-up is a no-op on the web).
  - Opening a book downloads the dictionary with progress, and lookups work offline after a reload.
  - Peak memory in Chrome on the S24 is recorded.
  Record the results in specs/003-dictionary-lookup/quickstart.md (FR-022, research R2)
- [ ] T083 Measure on the S24: the first-launch unpack time after a fresh install, and the APK size before and after (`flutter build apk --release --analyze-size` or the APK file sizes). Record them in quickstart.md "Measurements"
- [ ] T084 Run quickstart scenarios 1–26 on the Galaxy S24 and in desktop Chrome and Chrome on the phone. Record results, bugs found and fixes in specs/003-dictionary-lookup/checklists/verification.md (the 002 format). Fix or justify any performance miss in plan.md (Principle V). SC-005 (five first-time users) is recorded when the user runs it
- [ ] T085 Update CLAUDE.md:
  - 003 status;
  - the dictionary build command and its disk needs;
  - that `assets/dictionary/en.sqlite.gz` is built, not committed;
  - the new test commands (`test/eval`, lookup timing);
  - the new pins;
  - the open follow-up: publishing a prebuilt dictionary needs the user's approval.

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: none. T003 → T004 (needs the script), and T004's sample step → T013 (the full build in T004 only gates T042, T049, T053 and T079). T006 must finish before T018, and T007 before T020.
- **Foundational (Phase 2)**: depends on Setup; blocks all stories.
- **US1 (Phase 3)**: depends on Foundational.
- **US2 (Phase 4)**: depends on US1's resolver (T034) and panel (T036).
- **US3 (Phase 5)**: depends on US1 (panel, controller) and US2 for the coverage eval (T049).
- **US4 (Phase 6)**: depends on US1 (controller, panel wiring).
- **US5 (Phase 7)**: depends on US1 (extractor, wiring) and the interaction lock (T020).
- **US6 (Phase 8)**: depends on US1 (controller, panel).
- **US7 (Phase 9)**: depends on US1; better after US2 (notes in related entries).
- **US8 (Phase 10)**: depends on US1 (controller) and schema v3 (T009).
- **Polish (Phase 11)**: after the stories you intend to ship.

### Shared files (do not edit in parallel)

- lib/features/reader/ui/reader_screen.dart: T019, T039, T052, T058, T064, T078
- lib/features/reader/ui/lookup_panel.dart: T036, T046, T051, T064, T070, T073
- lib/features/reader/lookup_controller.dart: T035, T064, T070, T073, T078
- lib/features/reader/domain/word_extractor.dart: T032, T062
- lib/features/reader/domain/lookup_resolver.dart: T034, T045, T062
- test/unit/reader/lookup_resolver_test.dart: T034, T041
- test/widget/lookup_not_found_test.dart: T067, T069
- test/unit/reader/lookup_controller_test.dart: T029, T066, T071
- test/widget/reader_test_app.dart: T019, T026

### Within Each User Story

- Tests are written first and must fail before implementation (Principle IV).
- Domain → data → controller → UI wiring.
- Commit after each task or logical group.

### Parallel Opportunities

- Setup: T002 and T005 alongside T003; T006 and T007 in parallel after T001.
- Foundational: T008, T010, T012, T015, T017, T019, T021, T023, T025 and T026 in parallel. Then T009, T011, T013/T014, T016, T018, T020, T022 and T024.
- Each story's test tasks run in parallel, and so do its new-file tasks (T032–T034, T037, T038, T044, T057, T063, T068, T077).
- After US1, the P2 stories US4, US5 and US6 touch different domain files and can be developed in parallel, but their shared UI files (above) are edited in sequence.
- Polish: T079–T081 in parallel.

---

## Parallel Example: User Story 1

```bash
# Tests first, together:
Task: "Unit-test hitTest and WordExtractor in test/unit/reader/word_extractor_test.dart"
Task: "Unit-test panelPlacement in test/unit/reader/panel_placement_test.dart"
Task: "Unit-test LookupController in test/unit/reader/lookup_controller_test.dart"
Task: "Widget-test the main flow in test/widget/lookup_panel_test.dart"
Task: "Widget-test the hint in test/widget/lookup_hint_test.dart"

# Then the new files, together:
Task: "Implement WordExtractor in lib/features/reader/domain/word_extractor.dart"
Task: "Implement panelPlacement in lib/features/reader/domain/panel_placement.dart"
Task: "Implement a first LookupResolver in lib/features/reader/domain/lookup_resolver.dart"
Task: "Create dictionary_about.dart and the About Potha menu item"
Task: "Create lookup_hint.dart"
```

---

## Implementation Strategy

### MVP First (P1 stories: US1–US3)

1. Phase 1 Setup, including the full dictionary build and both spikes, then Phase 2
   Foundational.
2. US1 select and look up → US2 inflections → US3 offline and timing.
3. **Stop and validate** on the S24 and in Chrome (quickstart 1–12 and 22–25, the timing
   run T050, the eval runs T042 and T049). This is a lookup feature that could ship.

### Incremental Delivery

4. US4 tap-to-define → validate (quickstart 13).
5. US5 phrases → validate (14).
6. US6 not found and online → validate (15).
7. US7 copy and related → validate (16).
8. US8 history → validate (17).
9. Polish → full quickstart run → merge (Android and web verified; iOS noted as not
   verified).

---

## Notes

- [P] tasks touch different files and have no dependencies on incomplete tasks.
- [USn] labels map tasks to spec.md user stories for traceability.
- The full dictionary isn't committed. Tests that need it are under `test/eval/` and
  skip with a message when it is missing; everything else uses the committed sample.
- Online requests in tests and fixtures carry only the app identifier (the repository
  URL), never personal data.
- Publishing a prebuilt dictionary file is outward-facing and needs the user's approval;
  it's not a task here.
