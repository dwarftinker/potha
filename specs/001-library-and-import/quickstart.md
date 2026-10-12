# Quickstart: Library and Import

How to run feature 001 and confirm it works. See [data-model.md](data-model.md) and
[contracts/](contracts/) for the details referenced here.

## Prerequisites

- Flutter stable 3.47 (`~/develop/flutter/bin` on PATH).
- Android SDK with an Android phone or emulator (Android Studio or the command-line
  tools, then `flutter doctor --android-licenses`).
- Chrome on the desktop, and Chrome on an Android phone for the mobile web check.
- Test PDFs: `test/fixtures/` (generated for the tests) plus a few real books, including
  one over 100 MB, one password-protected PDF and one scanned PDF.

## Run

```bash
flutter pub get
dart run build_runner build        # drift code generation
flutter test                       # unit and widget tests
flutter run -d chrome              # web
flutter run -d <android-device>    # Android
flutter test integration_test -d <android-device>
```

**Mobile web**: OPFS only works in a secure context, so plain `http://<LAN-IP>` will not
work on a phone. Use one of:
- `adb reverse tcp:8080 tcp:8080`, then open `http://localhost:8080` in Chrome on the
  phone (connected by USB), with `flutter run -d web-server --web-port 8080`; or
- serve `build/web` over HTTPS.

## Validation scenarios

Run each on Android and on web (desktop Chrome plus Chrome on a phone). iOS is not
verified (constitution v2.0.0).

| # | Steps | Expected |
|---|---|---|
| 1 | Fresh install, open the app | Empty state with an explanation and an "Add book" action (FR-014) |
| 2 | Add a PDF with title and author metadata | Appears within 3 s for ~20 MB (SC-002), with cover, title, author and "New" |
| 3 | Add a PDF without metadata, named `my_great_book.pdf` | Title "my great book" (FR-010) |
| 4 | Add `scan_0001.pdf` without metadata | Title "scan 0001"; a name with no letters (e.g. `0001.pdf`) gives "Untitled book <date>" |
| 5 | Add the same file again, under another name | "Already in your library" with an Open action; no duplicate (FR-007) |
| 6 | Add a .txt renamed to .pdf, and a truncated PDF | Clear error; nothing added (FR-005) |
| 7 | Add a password-protected PDF; enter a wrong password, then the right one | Asks again after the wrong one; added after the right one. Reopening the book does not ask (FR-028) |
| 8 | Add a password-protected PDF and cancel | Nothing added (FR-006) |
| 9 | Pick 5 files: 3 valid, 1 duplicate, 1 invalid | 3 added; summary lists added, already there, failed with reason (FR-009) |
| 10 | Android: add a 500 MB PDF, cancel halfway | Progress and Cancel appear after 1 s; after cancel nothing is in the library and no file is left in storage (FR-008, SC-007) |
| 11 | Web: add a PDF over 100 MB (104,857,600 bytes) | "Too large for the web version" before any copying (FR-008a) |
| 12 | Android: share a PDF from Files or Gmail to the app, with the app closed, then open | App opens and the book is added (FR-002) |
| 13 | Web: drag two PDFs onto the library | Drop zone shows while dragging; both are added (FR-003) |
| 14 | Open a book, scroll to page 57, go back, kill and restart the app, open it again | Opens at page 57 and shows the page within 2 s of tapping on a mid-range phone (constitution V); library shows the right percentage (FR-016, FR-013) |
| 15 | Delete the original file from the device, then open the book | Still opens (FR-004) |
| 16 | Remove a book; cancel once, then confirm | Cancel changes nothing; confirm removes it, and re-importing shows "New" (FR-020/021) |
| 17 | Try each sort order; search "tolst" and an accented name | Orders match data-model.md; search ignores case and accents (FR-017/018) |
| 18 | Switch to list view, restart | Still list view and same sort order (FR-019) |
| 19 | Airplane mode, repeat 2, 14 and 17 | All work (SC-005) |
| 20 | Library with 500 books (seed script in tests), fling-scroll | No visible stutter (SC-003); search updates within 0.5 s (SC-004) |
| 21 | TalkBack on; system text size at maximum; dark theme | All controls announced; text scales without clipping; contrast passes (FR-025) |
| 22 | Web: first import | One-time notice that clearing site data removes the library (FR-027) |
| 23 | Kill the app during a large import, restart | No half-imported book; staging folder empty |
