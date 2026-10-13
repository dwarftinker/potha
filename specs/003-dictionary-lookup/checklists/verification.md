# Verification: Dictionary Lookup (003)

## Android: Galaxy S24 (SM-S921B), 2026-10-13

Full dictionary (`20260902.1`, 178,136 headwords) built into the app.

### Device tests

| Test | Mode | Result |
|---|---|---|
| `lookup_flow_test.dart`: long-press "melancholy" → panel → tap "sadness" in a definition → Back → system back closes; "mice" shows "plural of mouse"; long-press drag "give" → "up" shows "give up"; tap-to-define on, tap a word, off with the chip; history lists the words; a page without text says so; at 3× zoom in paged and continuous modes the panel doesn't cover the selected word | debug | Pass |

### Performance (profile mode, `flutter drive`)

| Criterion | Target | Measured |
|---|---|---|
| SC-002 long-press → definition shown, 20 words, half on pages not yet cached | p95 ≤ 300 ms | p95 91 ms, p50 76 ms |
| First-launch dictionary unpack (T083) | measure | 437 ms to ready (64.7 MiB on disk) |
| APK size (T083) | measure | 82.0 → 109.6 MB universal release APK (+27.6 MB) |

## Chrome on the S24 (Chrome 154), 2026-10-13

Release build (`tool/build_web.sh`) served from the computer over `adb reverse`.

| Check | Result |
|---|---|
| First load requests nothing from the dictionary | Pass |
| Opening a book downloads it (24,987,815 bytes, 0.9 s over USB) and lookups work | Pass ("Brothers" → brother, "plural of brother") |
| Airplane mode: lookups work; a word not in the dictionary says "Online search isn't available offline." | Pass |
| Reload, open a book: the dictionary isn't downloaded again | Pass |
| Long-press drag across three words: selection grows, page stays still, phrase fallback shown | Pass |
| Peak memory during download and set-up | 712 MB renderer RSS (270 MB before, 407 MB after). Not a failure on the S24; see research R2 (decision pending) |

## Findings

1. **Web memory** (R2 risk, confirmed): drift uses its IndexedDB storage on Chrome for
   Android, which keeps the 65 MB database in memory, and set-up peaks at 712 MB for
   the tab. COOP/COEP headers alone didn't get drift to OPFS (its worker failed).
   Options: the streaming fallback in R2, or work out drift's OPFS mode with the hosting
   headers. Needs a decision.
2. **Offline reload of the web app** can't open a book: the reader's deferred code is
   fetched on first open, and without a service worker that fails offline, silently
   (the library stays on screen). Same gap as 001's offline-reload follow-up; the
   dictionary itself is kept.
3. **"the", first sense** starts "...because it has already been mentioned": the build
   took a Wiktionary sub-sense without its parent sentence. It is the only sense in the
   dictionary that starts with an ellipsis. Fix in `tool/build_dictionary.py` (prefix
   the parent gloss) at the next rebuild.
4. **Test fixes** (no app change): `lookup_timing_test.dart` now times from finger down,
   polling every frame (it had timed from the lock flag, 50 ms polls, and undercounted);
   `lookup_flow_test.dart` reads word positions from a copy of the book with `fullyLive`
   frames (waiting on the reader's own document hung) and pans the word into view at 3×;
   `perf_driver.dart` prints plain measurements instead of crashing on them.

## Still to do (T084)

Quickstart scenarios 1–26 by hand on the S24, in desktop Chrome and in Chrome on the
phone; SC-005 (five first-time users).
