# Verification: Library and Import (001)

**Status**: Merged to main before the Android run (first feature). Android automated
checks pass on a Samsung Galaxy S24 (2026-10-12); hand-run Android and mobile-browser
scenarios are in progress. iOS is not verified.

## Automated (2026-10-12, Linux host)

| Suite | Result | Notes |
|---|---|---|
| `flutter test test/unit` | pass | Includes real PDFium import pipeline, pdfrx adapter and no-network tests (need `tool/fetch_test_pdfium.sh`) |
| `flutter test test/widget` | pass | Import UI, library grid/list, sort/search, remove, protected books, accessibility (light/dark, 2× text, contrast, tap targets) |
| `flutter test --platform chrome test/web` | pass | OPFS and IndexedDB book storage, quota errors |
| `integration_test/*` | pass on Android | See the Android section below |
| `test_driver/perf_driver.dart` (SC-003) | pass on Android | Profile mode; see below |

## Desktop Chrome, scripted via Chrome DevTools Protocol (release build)

| Quickstart # | Result |
|---|---|
| 1 Empty state | pass |
| 2 Import with metadata (cover, title, author, "New") | pass |
| 3 Title from file name (`three_pages.pdf` → "three pages") | pass |
| 14 Open, back, progress shown (33% on page 1 of 3) | pass (resume after restart not yet checked in the browser) |
| 22 One-time web storage notice | pass |
| No external network requests | pass (after bundling CanvasKit and fonts) |

## Android, Samsung Galaxy S24 (SM-S921B, Android 16), 2026-10-12

| Check | Result |
|---|---|
| `import_test` | pass (now also imports a real file through `XFile`, and taps Cancel on a running import) |
| `import_timing_test` (SC-002, under 3 s) | pass: 20 MB PDF in the library in 1.6–1.7 s (debug build) |
| `open_resume_test` (constitution V, under 2 s) | pass: reopened at the saved page in 0.3 s (debug build) |
| `scroll_perf_test` + `perf_driver` (SC-003, at most 1% of frames over 16 ms) | pass, three runs: grid 0–0.4%, list 0% |
| Search with 500 books (SC-004, under 0.5 s) | pass: 240–280 ms |

Hand-run on the release build (driven over adb, 2026-10-12):

| Quickstart # | Result |
|---|---|
| 1 Empty state | pass |
| 2 Metadata title and author, cover, "New" | pass |
| 3 `my_great_book.pdf` → "my great book" | pass |
| 4 `scan_0001.pdf` → "scan 0001"; `0001.pdf` → "Untitled book 2026-10-12" | pass |
| 5 Same file under another name → "Already in your library" + Open | pass |
| 6 Text file renamed .pdf → "not a PDF"; truncated PDF → "damaged" | pass |
| 7 Wrong then right password; reopening does not ask | pass |
| 8 Cancel the password → nothing added | pass |
| 10 500 MB PDF: progress bar and Cancel appear | pass; the copy takes about 3 s on the S24, so Cancel is checked by `import_test` instead |
| 12 Open with (VIEW) on a cold start | pass |
| 14 Page 57, kill, restart → 57% in the library, reopens on page 57 | pass |
| 15 Original file deleted → still opens | pass |
| 16 Remove after confirming | pass |
| 18 List view kept after restart | pass |

The S24 is a flagship, not a mid-range phone, so the timing margins will be smaller on
a mid-range device. Command for the perf run:
`flutter drive --profile --no-dds --driver=test_driver/perf_driver.dart --target=integration_test/scroll_perf_test.dart -d <device>`

## Still to verify

- [ ] All quickstart scenarios on an Android device (needs Android SDK)
- [ ] Mobile Chrome on an Android phone via `adb reverse` (OPFS needs a secure context)
- [x] Integration tests: `import_test`, `import_timing_test` (SC-002), `open_resume_test`
      (constitution V: under 2 s), `scroll_perf_test` with `perf_driver` (SC-003, SC-004)
- [x] Open with on Android, cold start (quickstart 12)
- [ ] Share to from a real app (My Files, Gmail) on Android
- [ ] Batch of 5 files (quickstart 9), airplane mode (19), TalkBack, maximum text size
      and dark theme (21), kill during a large import (23)
- [ ] iOS: not verified (no Mac); Share Extension target (T041) not created

## Found and fixed during verification

Android (2026-10-12):

- **Importing from the file picker hung forever on Android.** The picker (and Open with /
  Share to) gives a `Stream<Uint8List>`; transforming it with a `List<int>` transformer
  threw a type error at runtime, and the error escaped the import service, so the batch
  never finished and the spinner stayed. Tests used `List<int>` streams and missed it.
  The stream is now re-typed first, any unexpected error fails just that file, and unit
  and device tests cover both.
- Sharing a file the app may not read (the sender did not grant access) crashed the app:
  `receive_sharing_intent` opens it on the main thread without catching the
  `SecurityException`. `MainActivity` now drops unreadable files from the intent before
  the plugin sees it.

- The app did not build for Android: `receive_sharing_intent` 1.9 requires compiling
  against API 37, Flutter's default is 36. `compileSdk` is now 37 (`targetSdk` is still
  Flutter's default, so runtime behaviour is unchanged).
- Grid scrolling missed the frame budget (about 1.2% of frames over 16 ms; target 1%)
  each time a new row of tiles was built. Each tile had a full `PopupMenuButton` (tooltip,
  focus, theme and ink layers) and two `LayoutBuilder`s. The ⋮ button is now a light
  `InkResponse` with the same screen-reader label and 48 px target, and the grid passes
  the tile width down.
- The perf test itself was unrepresentative and is fixed: it seeded an in-memory
  database that ran SQLite on the UI thread (the app uses a background isolate), drew
  frames only every 100 ms (now `fullyLive`), kept semantics on (testWidgets default), and
  could not type into the search field on a device (test text input not registered by
  the integration binding). The import and resume tests now print their timings.

Web and host (before merge):

- pdfrx was never initialised in the app, so every import failed as "damaged" on all
  platforms (host tests initialised it themselves). Now initialised lazily on first use.
- `main()` waited for storage cleanup before showing anything; a slow browser storage
  call meant a blank screen. The library now renders first; imports wait for cleanup.
- An opened-but-not-scrolled book stayed "New" because the viewer only reports page
  changes. The starting page is now saved when a book opens.
- Snackbars with an Open action never dismissed (Flutter default); now 6 s.
- Grid tiles overflowed at 2× system text size; tile height now follows the text size.
- The web build fetched CanvasKit and Roboto from Google on every load (privacy and
  offline). Now bundled; use `tool/build_web.sh`.

## Follow-ups (not in this feature's tasks)

- `desktop_drop` applies the Kotlin Gradle Plugin; Flutter warns that future versions will
  refuse to build such plugins. Upgrade or replace it when a fixed version exists.
- `file_picker` copies each picked file into the app cache before handing it over, so a
  500 MB book briefly takes twice its size, and that copy shows no progress. Check
  whether the cache is cleared, and consider reading the content URI directly.
- The release APK is 80 MB because it bundles every ABI. Build per ABI
  (`--split-per-abi`) or an app bundle for distribution.

- Offline reload of the web app: there is no service worker, so the app shell is not
  cached. Spec SC-005 (airplane mode) holds for Android but not for a cold web reload.
- Non-Latin text on the web (for example Sinhala titles) makes Flutter download fallback
  fonts from fonts.gstatic.com. Bundling Noto Sans Sinhala (and others as needed) would
  avoid that.
