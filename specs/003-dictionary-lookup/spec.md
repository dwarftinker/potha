# Feature Specification: Dictionary Lookup

**Feature Branch**: `003-dictionary-lookup`

**Created**: 2026-10-13

**Status**: Draft

**Input**: User description: "Build in-book dictionary lookup: when a reader selects a
word, show its definition instantly without leaving the page. Long-press (or double-click
on the web) a word to see its definition in a panel; inflected words resolve to their base
word; works offline in under 300 ms; optional tap-to-define mode; phrase lookup; a clear
not-found state with an optional online search; copy and related words; lookup history."

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Look up a word by selecting it (Priority: P1)

A reader long-presses a word on the page. The word is marked as selected and a definition
panel slides up, covering no more than about a third of the screen so the surrounding
text stays visible. On the web with a mouse, double-clicking a word does the same. The
panel shows the word, its pronunciation (phonetic spelling) when known, and numbered
definitions grouped by part of speech, with an example sentence where one exists. Tapping
outside the panel, swiping it down or pressing Escape closes it and clears the selection.

**Why this priority**: this is the app's core differentiator; without it Potha is just a
PDF reader.

**Independent Test**: open a book with text, long-press "melancholy", read the definition,
close the panel each of the three ways; on desktop web, double-click a word.

**Acceptance Scenarios**:

1. **Given** a page with text, **When** the reader long-presses a word, **Then** the word
   is marked as selected and the definition panel opens with that word's entry.
2. **Given** the web with a mouse, **When** the reader double-clicks a word, **Then** the
   same happens.
3. **Given** an entry with several parts of speech, **When** the panel shows it, **Then**
   definitions are numbered and grouped under each part of speech, with the pronunciation
   at the top when known and examples under the definitions that have one.
4. **Given** the panel is open, **When** the reader taps outside it, swipes it down or
   presses Escape, **Then** it closes and the selection is cleared.
5. **Given** the selected word is in the lower part of the screen, **When** the panel
   opens, **Then** the word is still visible (the panel opens at the top instead).
6. **Given** a long entry, **When** the panel opens, **Then** it first covers at most a
   third of the screen, scrolls inside, and can be dragged up to read more.
7. **Given** the reader opens the reader for the first time, **When** the page appears,
   **Then** a one-time hint says how to look up a word (long-press; double-click on the
   web with a mouse).

---

### User Story 2 - Get the right entry for inflected words (Priority: P1)

When the selected word is an inflected form ("running", "mice", "better", "studied"), the
panel shows the base word's entry ("run", "mouse", "good", "study") with a note such as
"running – form of run". If the exact form has its own entry (for example "building" as a
noun), that entry comes first, followed by the base word's.

**Why this priority**: most words in running text are inflected; without this, lookup
fails or misleads on a large share of taps.

**Independent Test**: look up "running", "mice", "better", "studied" and "building" and
check the entry and the note for each.

**Acceptance Scenarios**:

1. **Given** "mice", **When** looked up, **Then** the entry for "mouse" is shown with
   "mice – plural of mouse".
2. **Given** "better", **When** looked up, **Then** entries for "better" (if any) come
   first, then "good" with "better – comparative of good".
3. **Given** "building", **When** looked up, **Then** the noun "building" comes first, then
   "build" with "building – form of build".
4. **Given** a word with no entry and no known base form, **When** looked up, **Then** the
   not-found state is shown (User Story 6).

---

### User Story 3 - Works offline (Priority: P1)

Lookup works with no network connection, using an English dictionary that comes with the
app, and the definition appears in under 300 ms.

**Why this priority**: reading happens on planes and trains (constitution, Principle II),
and slowness breaks concentration (Principle V).

**Independent Test**: turn on airplane mode, look up twenty words on different pages and
time each one.

**Acceptance Scenarios**:

1. **Given** no network, **When** the reader looks up a word in the dictionary, **Then**
   its definition appears.
2. **Given** a mid-range phone, **When** the reader long-presses a word, **Then** the
   definition is shown within 300 ms of the gesture being recognised.

---

### User Story 4 - Tap-to-define mode (Priority: P2)

The reader can turn on a mode where a single tap on a word shows its definition. While it
is on, a small indicator is visible so taps behaving differently is never a surprise.
Tapping the page edges still turns pages, and tapping where there is no word still shows
or hides the controls.

**Why this priority**: faster for heavy lookup use (language learners), but long-press
covers the need.

**Independent Test**: turn the mode on, tap words, tap empty space and both edges, then
turn it off.

**Acceptance Scenarios**:

1. **Given** the mode is on, **When** the reader taps a word in the middle area of the
   page, **Then** its definition opens at once, with no wait for a possible second tap.
2. **Given** the mode is on, **When** the reader taps an edge zone, **Then** the page
   turns, even if a word is there.
3. **Given** the mode is on, **When** the reader taps where there is no word, **Then** the
   controls are shown or hidden.
4. **Given** the mode is on, **When** the page is shown, **Then** a small indicator shows
   the mode is on, and it can be turned off from the controls.
5. **Given** the mode was turned on, **When** the reader opens any book later, **Then** it
   is still on.

---

### User Story 5 - Look up a phrase (Priority: P2)

After selecting a word, the reader extends the selection to several words ("give up", "in
spite of"). The app looks up the phrase. If the dictionary has no entry for it, the panel
shows the first word's definition and says the phrase wasn't found.

**Why this priority**: phrasal verbs and idioms are common stumbling blocks, but less
frequent than single words.

**Independent Test**: select "give up" and "in spite of", then a made-up phrase.

**Acceptance Scenarios**:

1. **Given** a selected word, **When** the reader drags the selection handles (or, with a
   mouse, drags across words), **Then** the selection grows word by word and the panel
   updates when the drag ends.
2. **Given** a phrase in the dictionary, **When** it is selected, **Then** its entry is
   shown.
3. **Given** a phrase not in the dictionary, **When** it is selected, **Then** the first
   word's entry is shown under a note "No entry for "…"".
4. **Given** a selection that crosses a line break, **When** it is looked up, **Then** the
   words are joined with single spaces.

---

### User Story 6 - Not found, and searching online (Priority: P2)

When a word isn't in the offline dictionary, the panel says so clearly. If the device is
online, it offers "Search online", which looks the word up with an online dictionary and
shows the result in the same panel. When offline, the panel says online search isn't
available right now.

**Why this priority**: rare words and new coinages will always exist; a dead end is
frustrating, but it doesn't block the main use.

**Independent Test**: look up a word missing from the offline dictionary online and
offline.

**Acceptance Scenarios**:

1. **Given** a word with no offline entry, **When** looked up, **Then** the panel shows
   the word and "No definition found".
2. **Given** that state and a network connection, **When** the reader chooses "Search
   online", **Then** the online result appears in the same panel, marked with its source.
3. **Given** no network, **When** the not-found state shows, **Then** it says online
   search is unavailable instead of offering it.
4. **Given** the online search fails or finds nothing, **When** it finishes, **Then** the
   panel says so and the reader can close it as usual.
5. **Given** any lookup, **When** the reader has not chosen "Search online", **Then**
   nothing about the word leaves the device.

---

### User Story 7 - Copy and related words (Priority: P3)

From the panel the reader can copy the word, and tap a word inside a definition to look
that word up, with Back returning to the previous definition.

**Why this priority**: convenient, not essential.

**Independent Test**: copy a word and paste it elsewhere; follow two definition words,
then go back twice.

**Acceptance Scenarios**:

1. **Given** an open entry, **When** the reader chooses Copy, **Then** the word is on the
   clipboard and a brief confirmation shows.
2. **Given** an entry, **When** the reader taps a word inside a definition, **Then** that
   word is looked up in the same panel and a Back control appears.
3. **Given** two such steps, **When** the reader chooses Back twice, **Then** the panel
   returns to the original word.

---

### User Story 8 - Lookup history (Priority: P3)

The app keeps a list of the words the reader looked up, for each book and overall, with
the date and page. The reader can open the list, look a word up again from it, and clear
the history at any time.

**Why this priority**: useful for review; the vocabulary feature (005) builds on it.

**Independent Test**: look up words in two books, open the history for one book and for
all books, then clear it.

**Acceptance Scenarios**:

1. **Given** lookups in two books, **When** the reader opens history from a book, **Then**
   that book's lookups are listed newest first with date and page; an "All books" view
   lists every lookup with the book's title.
2. **Given** the history, **When** the reader chooses an entry, **Then** its definition
   opens.
3. **Given** the history, **When** the reader chooses Clear and confirms, **Then** it is
   emptied (for that book, or all books, as chosen).
4. **Given** a book is removed from the library, **When** the history is viewed, **Then**
   that book's lookups are gone too.

---

### Edge Cases

- **Scanned pages** (no text): a long-press shows a brief message that this page has no
  selectable text.
- **Garbled text** (broken fonts in the PDF): the panel shows the characters that were
  extracted and says no definition was found; nothing crashes.
- **Zoomed in or continuous mode**: lookup works the same as in paged mode at the normal
  view.
- **Rapid lookups**: the panel always ends up showing the most recent word; an older
  lookup finishing later never replaces it.
- **Long-press on empty space or between words**: nothing is selected and no panel opens.
- **Long-press on a link**: the word is looked up; following links stays a tap.
- **Numbers, symbols, URLs and email addresses**: no lookup; nothing is selected.
- **Very long selections**: selections longer than 8 words are not looked up as phrases;
  the panel shows the first word.
- **Panel open and the reader turns the page**: the panel closes and the selection clears.
- **Web, dictionary not downloaded yet**: a lookup shows the download's progress and then
  the definition; offline, it says the dictionary needs a connection once (FR-022).
- **Capitalised words**: looked up regardless of case; a capitalised word that also has a
  proper-noun entry ("Turkey") may show both, proper noun first when capitalised
  mid-sentence.

## Requirements *(mandatory)*

### Functional Requirements

**Selecting and looking up**

- **FR-001**: A long-press on a word MUST select that word and open its definition.
  With a mouse, a double-click MUST do the same.
- **FR-002**: The selected word MUST be marked on the page while the panel is open.
- **FR-003**: The panel MUST open covering at most a third of the screen, MUST NOT cover
  the selected word (it opens at the top when the word is in the lower part of the
  screen), MUST scroll its content, and MAY be dragged to a taller size.
- **FR-004**: The panel MUST close, clearing the selection, on a tap outside it, a swipe
  down (or up, when it opened at the top), Escape, or a page turn.
- **FR-005**: The panel MUST show the headword, the pronunciation when known, definitions
  numbered and grouped by part of speech, and an example under definitions that have one.
- **FR-006**: The first time the reader screen opens, a one-time hint MUST explain how to
  look up a word (long-press; double-click with a mouse).

**Word rules**

- **FR-007**: Leading and trailing punctuation and quotation marks MUST be removed from
  the selected word (“Hello,” → "hello").
- **FR-008**: Apostrophes MUST be handled so contractions stay whole ("don't") and
  possessives look up the noun ("reader's" → "reader"); typographic and straight
  apostrophes MUST behave the same.
- **FR-009**: A word hyphenated across a line break ("exam-" / "ple") MUST be joined and
  looked up as "example". A hyphenated word ("well-known") MUST be looked up whole first,
  then by its parts if there is no whole entry.
- **FR-010**: Lookup MUST ignore case, except that a capitalised word with a proper-noun
  entry MAY show that entry as well.
- **FR-011**: Numbers, symbols, URLs and email addresses MUST NOT trigger a lookup.

**Finding the entry**

- **FR-012**: An inflected word MUST resolve to its base word with a note naming the
  relationship ("mice – plural of mouse"); when the exact form has its own entry, that
  entry MUST come first.
- **FR-013**: Lookups MUST work with no network, from an English dictionary included with
  the app, and show the definition within 300 ms of the gesture on a mid-range phone.
- **FR-014**: When several lookups overlap, only the most recently requested result MUST
  be shown.

**Tap-to-define**

- **FR-015**: The reader MUST be able to turn tap-to-define on and off from the reader
  controls; the choice applies to all books and is remembered.
- **FR-016**: With tap-to-define on, a single tap on a word in the middle area MUST open
  its definition at once (no wait for a second tap); edge zones MUST still turn pages, and
  a tap where there is no word MUST still show or hide the controls.
- **FR-017**: While tap-to-define is on, a small indicator MUST be visible on the reading
  screen.

**Phrases**

- **FR-018**: The reader MUST be able to extend a selection word by word, with handles on
  touch screens and by dragging with a mouse; the phrase MUST be looked up when the
  change ends.
- **FR-019**: If a phrase (up to 8 words) has no entry, the panel MUST show the first
  word's entry with a note that the phrase wasn't found.

**Not found and online**

- **FR-020**: A word with no offline entry MUST show a clear not-found state.
- **FR-021**: When online, the not-found state MUST offer "Search online"; the word MUST
  be sent to the online source only when the reader chooses it, and the result MUST be
  shown in the panel with its source named. When offline, the state MUST say online search
  is unavailable.
- **FR-022**: On the web, the dictionary MUST start downloading in the background the
  first time the reader opens a book, and be kept so lookups then work offline. The first
  app load MUST NOT include it. A lookup made before the download finishes MUST show that
  the dictionary is still downloading (with progress) and show the definition once it is
  ready; without a connection it MUST say the dictionary needs one connection to download.

**Related actions**

- **FR-023**: The panel MUST offer Copy, which puts the looked-up word on the clipboard.
- **FR-024**: Tapping a word inside a definition MUST look it up in the same panel, with a
  Back control returning through the previous entries.

**History**

- **FR-025**: Each lookup MUST be recorded with the word, the entry shown, the book, the
  page and the date and time.
- **FR-026**: The reader MUST be able to view history for the current book and for all
  books (newest first), reopen an entry from it, and clear it for one book or all books
  after confirming.
- **FR-027**: Removing a book MUST remove its lookup history.

**Robustness, platforms, privacy, accessibility**

- **FR-028**: A long-press on a page with no text MUST show a brief "This page has no
  selectable text" message.
- **FR-029**: Text that can't be read as words (garbled extraction) MUST be shown as
  extracted with "No definition found", never a crash.
- **FR-030**: Lookup MUST work the same at any zoom level and in both page modes.
- **FR-031**: Lookup MUST work on Android, iOS and desktop and mobile web browsers.
- **FR-032**: Lookups and history MUST stay on the device, except a word the reader sends
  with "Search online".
- **FR-033**: The panel MUST be readable by screen readers (headword, part of speech and
  each definition), its controls labelled, its text scaling with the system setting, and
  it MUST follow the reading theme with WCAG AA contrast.
- **FR-034**: The dictionary's licence and attribution MUST be shown in the app.

### Key Entities

- **Dictionary entry**: a headword with an optional pronunciation, senses grouped by part
  of speech (each with a definition and optional examples), and optional related words.
  Phrases are entries too. One dictionary per language; English first.
- **Word form**: links an inflected form to its base word with the relationship (plural,
  past tense, comparative, …).
- **Lookup**: the text as selected, the word looked up, the entry shown (or not found),
  the book, the page and when. Kept until cleared or the book is removed.
- **Reader preference**: tap-to-define on or off (all books); whether the one-time hint
  has been shown.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: In a test set of 1,000 word tokens from standard English prose (excluding
  names, numbers and symbols), at least 95% show a correct definition offline.
- **SC-002**: The definition appears within 300 ms of the gesture being recognised on a
  mid-range phone, for 95% of lookups.
- **SC-003**: In a test list of 200 common inflected words, at least 95% resolve to the
  correct base word.
- **SC-004**: In a test set of words hyphenated across line breaks, at least 95% are
  joined correctly, and genuine hyphenated words are not wrongly joined.
- **SC-005**: In a hands-on test, at least 4 of 5 first-time users look up a word during
  their first reading session.
- **SC-006**: Every lookup feature works on Android, iOS, and a desktop and a mobile web
  browser, with no network (except "Search online").
- **SC-007**: Ten lookups in quick succession always end showing the last word.

## Assumptions

- Builds on feature 002's reader: taps are recognised without waiting for a second tap,
  and page text with character positions is available. Long-press is unused in 002, so
  it is free for selection.
- With a mouse, a single click still shows or hides the controls at once; a double-click
  additionally looks up the word (the two clicks toggle the controls twice, leaving them
  as they were).
- Tap-to-define is off until the reader turns it on (the input describes turning it on).
- The panel may grow by dragging; its first size is at most a third of the screen.
- English only in this feature; the dictionary is one of several possible per-language
  dictionaries, so others can be added later.
- The online source is used only on the reader's explicit request per word; which source,
  and what it receives, is decided in the plan.
- Lookup history is on by default and stays on the device; it can be cleared but not
  turned off in this feature.
- "Mid-range phone" is the same reference as in features 001 and 002; iOS is a supported
  target but not verified before merge (constitution v2.0.0).

## Out of Scope

- Translation between languages
- Saving words to a vocabulary list and flashcards (feature 005)
- Audio pronunciation
- Highlights and notes (feature 004)
- OCR for scanned pages
- Dictionaries for languages other than English
- Looking up words outside the reader (for example in the library)
