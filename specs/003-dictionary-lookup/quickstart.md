# Quickstart: Dictionary Lookup

How to run feature 003 and confirm it works. Details are in [data-model.md](data-model.md)
and [contracts/](contracts/).

## Prerequisites

As in 002 ([../002-pdf-reader/quickstart.md](../002-pdf-reader/quickstart.md)): Flutter
3.47, the Galaxy S24 (`RFCX80MJSBN`), desktop Chrome, and Chrome on the phone. Also:

- Python 3 with `wordfreq` in a venv (`python3 -m venv build/dictionary/venv &&
  build/dictionary/venv/bin/pip install wordfreq`), and about 4 GB of free disk for the
  first dictionary build (3.0 GB download; the build streams it, about 3 minutes).
- Fixtures: `python3 tool/make_fixtures.py --lookup` adds:
  - `lookup_prose.pdf`: the words used below, plus "exam-/ple" and "well-/known" split
    across line ends;
  - `lookup_garbled.pdf`: text in a font without a Unicode map.
  The 002 fixtures `scanned.pdf` and `text_500.pdf` are reused.

## Build the dictionary

```bash
build/dictionary/venv/bin/python tool/build_dictionary.py --download   # full: assets/dictionary/
build/dictionary/venv/bin/python tool/build_dictionary.py --sample     # tests: build/fixtures/
```

The full build prints the headword count, the size gzipped and the size on the device,
and fails above 25 MB / 90 MB (research R1). Record the result here:

| Build | N (top words) | Headwords | gzip | On device |
|---|---|---|---|---|
| 2026-10-13, dump 2026-09-02, rules as R1 | 200,000 | 215,353 | 39.6 MiB | 104.5 MiB (over) |
| 2026-10-13, + usage examples only, phrases ≤ 4 words in top 20k, names in top 50k | 200,000 | 176,582 | 24.8 MiB | 66.9 MiB (at the limit) |
| 2026-10-13, same rules (default) | 150,000 | 166,061 | 23.6 MiB | 64.0 MiB |

## Run

```bash
flutter pub get
dart run build_runner build
python3 tool/make_fixtures.py --reader --lookup
flutter test test/unit test/widget
flutter test test/eval                             # SC-001/3/4; needs the full dictionary
flutter test --platform chrome test/web
flutter run -d chrome --no-web-resources-cdn
flutter test integration_test -d RFCX80MJSBN
flutter drive --profile --no-dds --driver=test_driver/perf_driver.dart \
  --target=integration_test/lookup_timing_test.dart -d RFCX80MJSBN     # SC-002
```

Mobile web: `adb reverse tcp:8080 tcp:8080`, then `flutter run -d web-server --web-port
8080` and open `http://localhost:8080` on the phone.

## Validation scenarios

Run on Android and on the web (desktop Chrome, and Chrome on the phone). iOS is not
verified (constitution v2.0.0).

| # | Scenario | Expected | Spec |
|---|---|---|---|
| 1 | Open a book for the first time | One-time hint (long-press; double-click; tap-to-define setting). Gone after Got it, also after a restart | FR-006 |
| 2 | Long-press "melancholy" | Word highlighted; panel at the bottom ≤ 1/3 with IPA and numbered senses grouped by part of speech | US1, FR-001–005 |
| 3 | Close by a tap outside, a swipe down, Esc (desktop) and back (Android) | Panel closes, selection cleared | FR-004 |
| 4 | Long-press a word in the bottom third | Panel opens at the top; the word stays visible | FR-003 |
| 5 | Desktop Chrome: double-click a word | Lookup; the controls end as they were | FR-001 |
| 6 | Look up "running", "mice", "better", "studied", "building" | Base entries with notes; "building" (noun) first | US2, FR-012 |
| 7 | "exam-/ple" across a line; "well-/known"; “Hello,”; "reader's"; "don't" | example; well-known; hello; reader; don't | FR-007–009 |
| 8 | Long-press a number, a URL, an email | Nothing selected | FR-011 |
| 9 | Long-press on `scanned.pdf` | "This page has no selectable text" | FR-028 |
| 10 | Long-press on `lookup_garbled.pdf` | Extracted text with "No definition found"; no crash | FR-029 |
| 11 | Zoom to 3×; continuous mode; then look up | Works the same; the panel never covers the word | FR-030 |
| 12 | Airplane mode (Android) and offline (DevTools): 20 lookups | All work | US3, FR-013 |
| 13 | Turn on Tap to define; tap words, empty space, both edges; restart; turn off with the chip | Lookups at once; the controls toggle; pages turn; still on after restart; chip and setting agree | US4, FR-015–017 |
| 14 | Long-press "give", drag to "up"; then "in spite of"; then a made-up phrase | Phrase entries; the made-up phrase shows the first word under "No entry for …" | US5, FR-018–019 |
| 15 | Look up a word missing offline, online and offline | "Search online" → result marked "From Wiktionary online"; offline: "Online search isn't available offline" | US6, FR-020–021 |
| 16 | Copy; tap two words in a definition; Back twice | Clipboard holds the word; back at the first entry | US7, FR-023–024 |
| 17 | Look up words in two books (one word twice); open history; clear one book; remove the other book | One line per word with ×2; Clear empties that book; removed book's lines gone | US8, FR-025–027 |
| 18 | Ten long-presses in quick succession | The panel ends on the last word | SC-007, FR-014 |
| 19 | Library menu → About Potha → licences; panel footer → About | Wiktionary, CC BY-SA 4.0, dump date, links | FR-034 |
| 20 | TalkBack on: open history and a definition; 200% text | Headword, part of speech and each sense read; labels on every control; text scales; panel scrolls | FR-033 |
| 21 | Dark and sepia themes | Selection and panel readable, AA contrast | FR-033 |
| 22 | Web, fresh profile: load the app, check DevTools Network | No dictionary request on first load | FR-022 |
| 23 | Web: open a book, look up at once | "Downloading the dictionary… N%", then the definition; reload offline: lookups still work | FR-022 |
| 24 | Web, fresh profile, offline before the first download | "The dictionary needs an internet connection once to download." | FR-022 |
| 25 | Android, fresh install, airplane mode from the start | First lookup works (after "Preparing the dictionary…" at most once) | Clarification Q4 |
| 26 | Android: `adb shell` watch network traffic (`no_network_test` on host) during scenarios 2–18, except 15's online search | No requests | FR-032 |

## Measurements to record

| What | Target | Result |
|---|---|---|
| Gesture → definition shown, p95, 20 words, half on pages not cached (S24, profile) | ≤ 300 ms | |
| SC-001: prose tokens with a correct definition | ≥ 95% | |
| SC-003: inflected forms resolved | ≥ 95% | |
| SC-004: line-break hyphenation joined | ≥ 95%, no genuine hyphen wrongly joined | |
| Mobile unpack on first launch (S24) | measure | |
| Web: download and set-up time on Wi-Fi; peak memory in Chrome on the S24 | measure (research R2 risk) | |
| APK size before and after | measure | |
| SC-005: first-time users who look up a word in their first session (hands-on, 5 people) | ≥ 4 of 5 | |
