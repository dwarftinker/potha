# Potha

Potha is a cross-platform reading app (Android, iOS, web), similar to Kindle. It is
PDF-first, and its key feature is instant dictionary lookup: select a word and see its
definition without leaving the page. Development follows spec-driven development (SDD)
with GitHub Spec Kit.

## Status

- Feature 001 (library and import) is merged and verified on Android (Galaxy S24) and
  mobile Chrome; 77 of 79 tasks done. Open: T041 (iOS Share Extension, needs a Mac),
  T077 (upstream pdfrx issue, needs approval). See
  `specs/001-library-and-import/checklists/verification.md`.
- Feature 002 (PDF reader) is implemented on branch `002-pdf-reader`. Device tests and
  every performance target pass on the Galaxy S24 (`specs/002-pdf-reader/checklists/
  verification.md`). Open: T076 (manual quickstart run on the phone and in browsers).
- Spec Kit is initialised. The constitution is ratified (v2.0.0) in
  `.specify/memory/constitution.md`.
- The root folder holds the prompts drafted for Spec Kit:
  - `Constitution.md` – input for `/speckit.constitution`
  - `001-library-and-import.md`, `002-pdf-reader.md`, `003-dictionary-lookup.md` – input
    for `/speckit.specify`, one per feature
- These files are prompts, not the generated specs. Spec Kit writes the real artifacts to
  `.specify/memory/constitution.md` and `specs/<NNN-feature>/`.
- The prompts call the app "Reader". The product name is **Potha**.

## Decisions made so far

| Area | Decision | Why |
|---|---|---|
| Framework | Flutter (one codebase for Android, iOS, web) | Best cross-platform PDF story. React Native would need a separate PDF.js viewer for web. |
| PDF engine | `pdfrx` (PDFium; WASM on web) | Rendering, text selection, character positions, search on every platform. Fallback: Syncfusion Flutter PDF Viewer (commercial, free community licence). |
| State | Riverpod | |
| Local DB | `drift` (SQLite; WASM on web) | Library, progress, highlights, lookup history. |
| File storage | App support dir on mobile (not documents, so books stay out of the iOS Files app and document backups); OPFS with IndexedDB fallback on web | The app keeps its own copy of imported books. See specs/001-library-and-import/research.md R3. |
| Dictionary | Bundled offline SQLite (WordNet plus a lemma table); optional online fallback | Offline-first, lookup under 300 ms. Wiktionary data is CC BY-SA and needs attribution. |
| Sync | Later (Supabase or Firebase) | Out of scope for v0.1. |

| PDF metadata | Own pure-Dart reader (`lib/core/document/pdf/pdf_metadata_reader.dart`) | pdfrx has no title/author API. Replace when pdfrx adds one (T077). |
| Reader view | pdfrx `PdfViewer` with our own page layouts: pages pre-scaled to the view, so zoom 1.0 is the normal view (fit width or fit page). Paged mode: one slot per page, pdfrx panning off, our `PagedDragHandler` slides and snaps (pdfrx has no paging) | specs/002-pdf-reader/research.md R2 |
| Taps | Our `TapDetector` (raw pointer `Listener`, no gesture arena) wraps the view; pdfrx's taps and link handling are off | pdfrx's page `GestureDetector` always waits for a double tap (up to 300 ms). 003's tap-to-define should use the same detector |
| Dark / sepia | Colour matrix over the page layer (dark: invert + hue-rotate 180°, keeps hues). Highlights are painted inside it in pre-inverted colours | pdfrx exposes no colour-scheme rendering; FR-028 reworded. Upstream request drafted in specs/002-pdf-reader/upstream-request.md (not posted) |
| Web resources | Bundle CanvasKit and the Roboto font; build with `tool/build_web.sh` (`--no-web-resources-cdn`) | Otherwise every web load calls Google's CDN (privacy, offline). |

Core abstraction: a format-agnostic `ReaderDocument` interface (pages, text at a position,
word at a point, search). PDF now and EPUB later implement it. Dictionary, highlights and
progress depend only on the interface.

## Known risks

1. **Mobile web gestures.** pdfrx text selection has conflicted with pan and zoom on
   Flutter web in mobile browsers (pdfrx issue #180). Spike: no conflict in mobile Chrome
   (see below).
2. **Scanned PDFs** have no text layer. Detect this and tell the user. OCR comes later.
3. **Web bundle size.** First load is about 3.9 MB gzipped; pdfium.wasm (2.3 MB) and the
   deferred reader load only on first import or open (measured 2026-10-12, see
   `specs/001-library-and-import/quickstart.md`).
4. **PDFs are fixed layout.** No reflow or font resizing for PDFs; reflow comes with EPUB.
5. **Tap-to-word latency on web.** In the spike, a tap took about 300 ms to yield the word
   via pdfrx `selectWord` on mobile Chrome, which uses the whole lookup budget. 002 removed
   the double-tap wait (`TapDetector`) and added `ReaderDocument.loadPageText` with
   per-character rects. For 003: cache page text, hit-test characters ourselves with
   `DocumentViewController.pagePointAt`, and measure natively on Android.
6. **No iOS testing.** There is no Mac, iOS device or cloud CI, so iOS (and mobile Safari)
   is not verified. The constitution (v2.0.0) keeps iOS as a target but drops it from the
   merge gate.

### pdfrx spike (2026-10-11)

Throwaway app in `../potha_spike` (pdfrx 2.6.5, Flutter 3.47.7): opens a PDF, selects the
word on tap or long-press, shows it with timing. Result on mobile Chrome: selection works
on the sample and on real PDFs; pinch, pan and scroll work, also after a selection.
Not tested: mobile Safari, Android native (no Android SDK installed yet), iOS. Verdict:
the pdfrx plan holds.

Environment note: Flutter is at `~/develop/flutter/bin`, which is not on the PATH of
non-interactive shells.

## Running and testing

```bash
flutter pub get
dart run build_runner build          # drift code generation
python3 tool/make_fixtures.py        # test PDFs (python3 + Ghostscript); --large adds a 20 MB one
tool/fetch_test_pdfium.sh            # PDFium for host tests that use real pdfrx (Linux x64)
flutter test test/unit test/widget   # host tests
flutter test --platform chrome test/web
flutter run -d chrome --no-web-resources-cdn
tool/build_web.sh                    # release web build
flutter test integration_test -d <android-device>
flutter drive --profile --no-dds --driver=test_driver/perf_driver.dart \
  --target=integration_test/scroll_perf_test.dart -d <android-device>   # SC-003 frame budget
python3 tool/make_fixtures.py --reader     # 002 reader fixtures (+ build/fixtures/long_2000.pdf)
flutter drive --profile --no-dds --driver=test_driver/perf_driver.dart \
  --target=integration_test/reader_perf_test.dart -d <android-device>        # 002 SC-002/3/4
flutter drive --profile --no-dds --driver=test_driver/perf_driver.dart \
  --target=integration_test/reader_open_timing_test.dart -d <android-device> # 002 SC-001/6/7
```

- Mobile web needs a secure context for OPFS: `adb reverse tcp:8080 tcp:8080` and open
  `http://localhost:8080` on the phone, or serve over HTTPS.
- After changing a drift table: bump `schemaVersion`, write the migration, then run
  `dart run drift_dev make-migrations` and
  `dart run drift_dev schema generate drift_schemas/app_database/ test/unit/db/generated/`.
- Widget tests: drift work must run outside fake async (`tester.runAsync`); seed with one
  `batch`, and close the database with `tester.runAsync(db.close)` (see
  `test/widget/test_app.dart`).
- Android: Flutter is not on the PATH of non-interactive shells and neither is `adb`
  (`~/Android/Sdk/platform-tools/adb`). Integration tests need the phone unlocked;
  `adb shell svc power stayon usb` keeps it awake. `flutter test integration_test`
  uninstalls the app afterwards. `compileSdk` is 37 because `receive_sharing_intent`
  requires it.
- Device tests must feed imports the way the platform does (files through `XFile`,
  which gives `Stream<Uint8List>`), not only bytes in memory; that gap hid an
  Android-only import hang.
- Widget tests with real pdfrx (`test/widget/pdf_view_test.dart`): animated moves only
  advance while the test pumps, so start them with `unawaited(...)` and then pump.
- Reader widget tests use fakes from `test/widget/reader_test_app.dart`; popping the
  reader needs several 100 ms pumps before the screen is disposed (`leaveReader`).
- Formatting: `dart format -l 100` (the project's line width).
- Device tests: register the test text input before `enterText`
  (`useTestTextInput`), find books with the library search (new books sort last), and use
  `systemBack` (the reader has no app bar). The S24's 30 s screen timeout can lock the
  phone mid-run; raise it while testing
  (`adb shell settings put system screen_off_timeout 1800000`) and restore it (30000).
- Pinned on purpose: `package_info_plus` 10.2.1 (10.2.2 is under two weeks old; revisit
  after 2026-10-15) and `wakelock_plus` 1.8.0 (1.8.1 needs `dbus` ^0.8, which
  `desktop_drop` 0.8.x does not allow yet).
- Pinned on purpose: `archive` 4.3.0 and `image` 4.10.1 (image 4.11.0 needs archive 4.4+
  while declaring ^4.0.9). Revisit after 2026-10-25.

## Roadmap

- v0.1 (MVP): import PDFs, library, reader (zoom, navigation, resume), dictionary lookup
- v0.2: highlights and notes, in-book search, vocabulary list, dark and sepia themes
- v0.3: EPUB with reflowable text
- v0.4: accounts and cross-device sync, flashcards

Feature order for Spec Kit: 001 library and import, 002 PDF reader, 003 dictionary lookup,
004 highlights and notes, 005 vocabulary list, 006 EPUB.

## Workflow (Spec Kit)

Once per project: `/speckit.constitution`. Then, for each feature:
`/speckit.specify` → `/speckit.clarify` → `/speckit.plan` → `/speckit.tasks` →
`/speckit.analyze` → `/speckit.implement` (→ `/speckit.converge`).

- Keep `/speckit.specify` about what and why only. The tech stack goes in `/speckit.plan`.
- Each feature lives on its own branch (`001-…`) and is verified on Android and web
  (including a mobile browser) before merging. iOS is not verified (no way to test).
- Example plan input for 003: "Flutter with Riverpod. pdfrx for text and character
  positions. Dictionary is a bundled SQLite database (WordNet + lemma table) accessed via
  drift, with an optional online fallback. Lookup UI is a modal bottom sheet. Word
  extraction and lemmatisation are pure Dart services with unit tests."
- Open questions for `/speckit.clarify` on 003: the dictionary source and licence, and
  whether tap-to-define is on by default.

## Next steps

1. Finish verifying 002: quickstart scenarios 1–33 by hand on the S24 and in Chrome
   (T076); record them in
   `specs/002-pdf-reader/checklists/verification.md`.
2. Approve or edit the upstream pdfrx request (`specs/002-pdf-reader/upstream-request.md`,
   covers 001 T077 and 002 T077) before it is posted.
3. Decide on the web follow-ups in 001's `verification.md`: a service worker for offline
   reloads, and bundling Noto fonts for non-Latin titles.
4. Then feature 003 (dictionary lookup) with `/speckit.specify` and `003-dictionary-lookup.md`.
