# Potha

Potha is a cross-platform reading app (Android, iOS, web), similar to Kindle. It is
PDF-first, and its key feature is instant dictionary lookup: select a word and see its
definition without leaving the page. Development follows spec-driven development (SDD)
with GitHub Spec Kit.

## Status

- Planning done. No app code yet.
- Spec Kit is initialised. The constitution is ratified (v2.0.0) in
  `.specify/memory/constitution.md`.
- The pdfrx spike is done (results below). Next: `/speckit.specify` for feature 001.
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

Core abstraction: a format-agnostic `ReaderDocument` interface (pages, text at a position,
word at a point, search). PDF now and EPUB later implement it. Dictionary, highlights and
progress depend only on the interface.

## Known risks

1. **Mobile web gestures.** pdfrx text selection has conflicted with pan and zoom on
   Flutter web in mobile browsers (pdfrx issue #180). Spike: no conflict in mobile Chrome
   (see below).
2. **Scanned PDFs** have no text layer. Detect this and tell the user. OCR comes later.
3. **Web bundle size.** PDFium WASM makes first load heavy. Lazy-load the reader route.
   Spike measured about 5–6 MB gzipped on first load (CanvasKit 2–2.8 MB, pdfium.wasm
   2.3 MB, main.dart.js 0.7 MB).
4. **PDFs are fixed layout.** No reflow or font resizing for PDFs; reflow comes with EPUB.
5. **Tap-to-word latency on web.** In the spike, a tap took about 300 ms to yield the word
   via pdfrx `selectWord` on mobile Chrome, which uses the whole lookup budget. The tap
   recogniser also waits for a possible double tap first. Address in the 003 plan: cache
   page text and hit-test characters ourselves, disable double-tap on the reader, and
   measure natively on Android.
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

1. Run `/speckit.specify` with `001-library-and-import.md`, then continue the workflow.
2. Install the Android SDK before implementing 001, so features can be verified on
   Android.
