# Verification: Library and Import (001)

**Status**: Partial. Android and mobile-browser runs are still needed before merging
(constitution v2.0.0, Principle I). iOS is not verified.

## Automated (2026-10-12, Linux host)

| Suite | Result | Notes |
|---|---|---|
| `flutter test test/unit` | pass | Includes real PDFium import pipeline, pdfrx adapter and no-network tests (need `tool/fetch_test_pdfium.sh`) |
| `flutter test test/widget` | pass | Import UI, library grid/list, sort/search, remove, protected books, accessibility (light/dark, 2× text, contrast, tap targets) |
| `flutter test --platform chrome test/web` | pass | OPFS and IndexedDB book storage, quota errors |
| `integration_test/*` | **not run** | Need an Android device or emulator (no Android SDK on this machine) |
| `test_driver/perf_driver.dart` (SC-003) | **not run** | Needs a mid-range Android phone in profile mode |

## Desktop Chrome, scripted via Chrome DevTools Protocol (release build)

| Quickstart # | Result |
|---|---|
| 1 Empty state | pass |
| 2 Import with metadata (cover, title, author, "New") | pass |
| 3 Title from file name (`three_pages.pdf` → "three pages") | pass |
| 14 Open, back, progress shown (33% on page 1 of 3) | pass (resume after restart not yet checked in the browser) |
| 22 One-time web storage notice | pass |
| No external network requests | pass (after bundling CanvasKit and fonts) |

## Still to verify

- [ ] All quickstart scenarios on an Android device (needs Android SDK)
- [ ] Mobile Chrome on an Android phone via `adb reverse` (OPFS needs a secure context)
- [ ] Integration tests: `import_test`, `import_timing_test` (SC-002), `open_resume_test`
      (constitution V: under 2 s), `scroll_perf_test` with `perf_driver` (SC-003, SC-004)
- [ ] Open with / Share to on Android (quickstart 12)
- [ ] iOS: not verified (no Mac); Share Extension target (T041) not created

## Found and fixed during verification

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

- Offline reload of the web app: there is no service worker, so the app shell is not
  cached. Spec SC-005 (airplane mode) holds for Android but not for a cold web reload.
- Non-Latin text on the web (for example Sinhala titles) makes Flutter download fallback
  fonts from fonts.gstatic.com. Bundling Noto Sans Sinhala (and others as needed) would
  avoid that.
