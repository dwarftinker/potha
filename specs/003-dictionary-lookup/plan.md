# Implementation Plan: Dictionary Lookup

**Branch**: `003-dictionary-lookup` | **Date**: 2026-10-13 | **Spec**: [spec.md](spec.md)

**Input**: Feature specification from `/specs/003-dictionary-lookup/spec.md`

## Summary

A long-press on a word (double-click with a mouse, or one tap in tap-to-define mode)
selects it and opens a definition panel over the page. The panel opens at the bottom, or
at the top when the word is low. The definition comes from an English dictionary built
from Wiktionary, which ships inside the app on Android and iOS. On the web it downloads
in the background the first time a book is opened. Inflected words resolve to their base
word, phrases can be selected, and a word missing offline can be searched on Wiktionary
online when the reader asks. Lookups are kept as one history line per word per book.

The approach reuses 002's pieces:
- Words come from `ReaderDocument.loadPageText` and
  `DocumentViewController.pagePointAt`, hit-tested by our own pure-Dart code, with page
  text cached. There is no pdfrx text selection (research R4).
- Gestures extend 002's raw-pointer `TapDetector` with long-press and mouse
  double-click (R6).
- The dictionary is a second, read-only drift database (R2, R3), produced by
  `tool/build_dictionary.py` from wiktextract's extract (R1).
- Word rules, lemmatisation and result ordering are pure Dart, tested first (R4, R5).

## Technical Context

**Language/Version**: Dart 3.13 / Flutter 3.47 (stable)

**Primary Dependencies**: pdfrx 2.6.5, drift 2.35 + drift_flutter 0.3, flutter_riverpod
3.4, url_launcher 6.3 (all from 001/002). New: `http` 1.6.0 (already transitive, made
direct), `connectivity_plus` (pinned at setup to a release ≥ 2 weeks old). Build-time
only: Python 3 + `wordfreq`. See research R13.

**Storage**:
- App database schema v3: `lookup_history`, plus two `reader_preferences` columns.
- Read-only dictionary database `en-<version>.sqlite`: unpacked from a gzip asset on
  mobile; downloaded into drift's web storage on the web (data-model.md).

**Testing**:
- flutter_test unit and widget tests, with fakes for `Lexicon`, `DictionaryStore`,
  `OnlineDictionary` and `NetworkStatus`.
- A sample dictionary built from committed wiktextract lines.
- `test/eval/` accuracy tests against the full dictionary (SC-001/3/4).
- integration_test and `flutter drive --profile` on the S24 (SC-002).
- Chrome tests for the web download path.

**Target Platform**: Android 7+ (API 24, compileSdk 37), iOS 15+ (built, not verified),
web (current Chrome, Edge, Firefox, Safari 16.4+ for `DecompressionStream`; secure
context).

**Project Type**: Cross-platform mobile and web app (single Flutter project)

**Performance Goals**:
- SC-002: definition shown ≤ 300 ms after the gesture, p95, on the S24 (budget in R8).
- 002's reader targets unchanged: no added work per frame; page-text prefetch runs when
  idle.
- Web first load unchanged (the dictionary is not fetched).

**Constraints**:
- Offline lookups. Nothing leaves the device except the word sent by "Search online".
- Dictionary ≤ 25 MB gzip, ≤ 90 MB on the device (R1).
- The reader and lookup code stay in the deferred reader library on the web.
- The tap path still never waits for a double tap.

**Scale/Scope**: about 150k–250k headwords (estimate, R1); history is a few rows per book
per session. New UI: the panel, the selection handles, the hint, the indicator chip, the
history sheet, and the About entry in the library.

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Principle | Status | How this plan complies |
|---|---|---|
| I. One codebase, three platforms | Pass | One code path. The only platform difference is where the dictionary file comes from, behind `DictionaryStore`: unpack on io, download on web (R2). Verified on the S24 and in desktop and mobile Chrome (quickstart); iOS is built but not verified, as v2.0.0 allows. |
| II. Offline-first | Pass | Offline lookups everywhere. Mobile works from first launch (clarification Q4). The web needs one download, and then works offline (FR-022, the spec's agreed exception for web). Online search is optional and fails gracefully (R9). |
| III. Format-agnostic core | Pass | Lookup uses only `PageText`, `PagePoint` and two new `DocumentViewController` methods (`pageRectToGlobal`, `setInteractionLocked`), with no PDF types (contracts/lookup.md). The dictionary sits behind `Lexicon`, one instance per language. |
| IV. Test-first for core logic | Pass | Written first and failing first: `WordExtractor`, hit test, line-break joining, `Lemmatiser`, `LookupResolver`, key normalisation, latest-wins controller, panel placement, Wikimedia parser, history repository, v2→v3 migration (R14). Each story has a widget test; the main flow has a device test. |
| V. Reading comes first | Pass, with checks | 300 ms budget broken down and measured on the device (R8). Dictionary queries run off the UI thread (drift isolate or worker). Page-text prefetch only when idle. The web first load is unchanged. No 002 target is relaxed. |
| VI. Privacy by default | Pass | History and preferences stay in the local database. The online request carries only the word and an app identifier, and only on the reader's action (FR-032, R9). `no_network_test` covers lookups. |
| VII. Accessible and calm | Pass, one limitation | The panel and history are fully labelled and scale with text size, with AA contrast in three themes. The hint shows once; the indicator is small. Limitation: choosing a word on the page with a screen reader isn't possible, because the PDF page has no word-level semantics (as in 002). History and definitions are fully accessible. |
| VIII. Simplicity | Pass | Two runtime packages (`http` is already in the build; `connectivity_plus` for one state), each justified in R13. A second database is the simplest way to version and swap a large read-only file. The gesture code extends `TapDetector` rather than adding a recogniser. |
| Additional: bundled data licence | Pass | CC BY-SA 4.0. Attribution is in the panel, in About, and in the asset's LICENSE; the build script is public (R1, R12). |

**Post-design re-check (after Phase 1)**: Pass. Every new interface member has a caller in
this feature: `pageRectToGlobal` for the panel and handles, `setInteractionLocked` for
long-press and handle drags, `HighlightKind.selection` for FR-002. Platform code is
limited to the dictionary store's io and web halves. No principle needs an exception.

## Project Structure

### Documentation (this feature)

```text
specs/003-dictionary-lookup/
├── plan.md              # This file
├── research.md          # Phase 0: R1–R14
├── data-model.md        # Phase 1: schema v3, dictionary database, states
├── quickstart.md        # Phase 1: build, run, validation scenarios, measurements
├── contracts/
│   ├── lookup.md        # view additions, gestures, extractor, Lexicon, resolver, controller
│   └── lookup-ui.md     # gestures table, panel, controls, history, accessibility
├── checklists/requirements.md
└── tasks.md             # Phase 2 (/speckit-tasks)
```

### Source Code (repository root)

```text
assets/dictionary/
├── en.sqlite.gz                         # built, not committed (research R1)
└── LICENSE.md                           # Wiktionary, CC BY-SA 4.0, dump date
lib/
├── core/
│   ├── db/app_database.dart             # schema v3: lookup_history, preference columns
│   ├── document/
│   │   ├── document_format.dart         # + pageRectToGlobal, setInteractionLocked, HighlightKind
│   │   └── pdf/
│   │       ├── pdf_view_controller.dart # implements the two new members
│   │       └── pdf_document_view.dart   # selection highlight, interaction lock
│   ├── dictionary/
│   │   ├── lexicon.dart                 # Lexicon, DictionaryEntry, WordFormLink, DictionaryInfo,
│   │   │                                #   OnlineDictionary interface, OnlineResult
│   │   ├── lookup_key.dart              # normalisation (shared with the build script's rules)
│   │   ├── dictionary_database.dart     # read-only drift database over the built file
│   │   ├── dictionary_store.dart        # DictionaryStore, DictionaryStatus, provider
│   │   ├── dictionary_store_io.dart     # unpack the asset into app support (isolate)
│   │   ├── dictionary_store_web.dart    # fetch + DecompressionStream + initializeDatabase
│   │   ├── dictionary_warmup.dart       # startDictionaryUnpack(): conditional import, no-op on web
│   │   ├── dictionary_warmup_io.dart    # starts the io store's unpack after the first frame
│   │   └── online_dictionary.dart       # Wikimedia REST client and parser
│   └── platform/network_status.dart     # NetworkStatus over connectivity_plus
└── features/
    ├── library/ui/library_screen.dart   # menu: About Potha (licences)
    └── reader/
        ├── domain/
        │   ├── word_extractor.dart      # hit test, word rules, line-break joins, phrases
        │   ├── lemmatiser.dart          # rule fallback
        │   ├── lookup_resolver.dart     # ordering, notes, phrases, hyphen parts
        │   └── panel_placement.dart     # top or bottom, first height
        ├── data/
        │   ├── page_text_cache.dart     # LRU of 8 pages, idle prefetch
        │   └── history_repository.dart  # upsert, lists, clear
        ├── lookup_controller.dart       # Riverpod, latest-wins, back stack, online
        └── ui/
            ├── tap_detector.dart        # + long-press, long-press drag, mouse double-click
            ├── reader_screen.dart       # wires gestures, panel, hint, indicator, prefetch
            ├── lookup_panel.dart        # bottom / top sheet, entry view, not-found, progress
            ├── selection_handles.dart
            ├── lookup_hint.dart
            ├── tap_to_define_chip.dart
            ├── history_sheet.dart
            ├── dictionary_about.dart
            ├── settings_sheet.dart      # + Tap to define switch
            ├── reader_bars.dart         # + Lookup history button
            └── reader_shortcuts.dart    # Esc closes the panel first
test/
├── fixtures/dictionary/                 # sample.jsonl, prose_1000.txt, inflections_200.tsv,
│                                        # hyphenation.tsv, wikimedia_*.json
├── unit/dictionary/                     # lookup key, database over the sample, store, online parser
├── unit/reader/                         # extractor, lemmatiser, resolver, controller, history,
│                                        # placement, migration v2→v3
├── eval/                                # SC-001/3/4 against the full dictionary (skipped if absent)
├── web/                                 # web store: progress, retry, offline
└── widget/lookup_*_test.dart            # one or more per story
integration_test/
├── lookup_flow_test.dart
└── lookup_timing_test.dart              # SC-002
tool/
├── build_dictionary.py                  # --download / --sample; size budget check
└── make_fixtures.py                     # --lookup fixtures
```

**Structure Decision**: the same layout as 001 and 002.
- The dictionary goes in `core/dictionary/`, because it is shared infrastructure: 005's
  vocabulary feature will use it.
- `lookupKey` lives with the dictionary, because `core/` must not depend on a feature.
- The app starts the mobile unpack through `dictionary_warmup.dart`, whose web half is
  empty, so the web first-load bundle doesn't gain the dictionary store.
- Lookup logic and UI belong to the reader feature, which keeps them inside the deferred
  reader library on the web. `DictionaryStore.ensureStarted()` is called from the
  reader, so nothing runs at the web first load.
- Platform code sits only in the `_io` / `_web` halves of the dictionary store, chosen
  by conditional import, as with 001's `book_file_store`.

## Implementation order and risks

1. **Dictionary first (R1, R2)**:
   - Build the sample and the full dictionary, and record their sizes. If the full one is
     over budget, lower *N* before writing any UI.
   - Then spike the web store on the S24 in Chrome: download, `DecompressionStream`,
     `initializeDatabase`, peak memory. If memory is a problem, switch to the
     direct-to-OPFS fallback now.
2. **Foundation**:
   - schema v3 and its migration;
   - the view contract additions;
   - `Lexicon`, `DictionaryDatabase` and `DictionaryStore` (io and web);
   - the page-text cache;
   - `TapDetector` long-press;
   - the lookup key rules.
3. **Stories in priority order**:
   - US1–US3 (P1) give a releasable lookup;
   - then US4–US6 (P2);
   - then US7–US8 (P3).
4. **Measurements before merge**: the S24 timing test (SC-002), the eval suite
   (SC-001/3/4), the web download and offline checks. A miss is fixed or justified here
   (Principle V).

**Risks**:
- **Dictionary size versus coverage.** Trimming that is too aggressive could miss
  SC-001's 95%. The eval suite runs against each build, so *N* is tuned with numbers.
- **Web memory.** `initializeDatabase` takes the whole file at once (R2 has the
  fallback).
- **The Wikimedia endpoint** may be retired with RESTBase. Online search is isolated
  and degrades to a message (R9).
- **The interaction lock mid-gesture** (R6) is new pdfrx territory. Spike it with the
  long-press work, on the S24 and mobile Chrome.
- **First-launch unpack time on mobile** is unknown until measured. Lookups show
  "Preparing the dictionary…" in the meantime.

**Follow-ups needing the user's approval (outward-facing)**: publishing a prebuilt
dictionary file (for example as a GitHub release asset) for CI and faster setup (R1).

## Complexity Tracking

No constitution violations.

| Item | Why | Simpler alternative rejected because |
|---|---|---|
| A second database file (read-only dictionary) | A large, versioned, replaceable data set, separate from user data | Importing it into the app database: a 90 MB migration on every dictionary update, and user data mixed with reference data |
| `connectivity_plus` | User Story 6, scenario 3: say "unavailable offline" before the reader tries | Always offering the button and failing on tap: contradicts the acceptance scenario |
