# Contract: Lookup interaction

What readers see and do. This extends 002's `contracts/reader-ui.md`; anything not listed
here is unchanged. Widget and integration tests check these rows.

## Gestures on the page

The first matching rule wins.

| Input | Tap-to-define off | Tap-to-define on | Spec |
|---|---|---|---|
| Tap on a link | Follow the link (002) | Same | Edge cases |
| Tap in an edge zone | Turn the page (002) | Same, even on a word | FR-016 |
| Tap on a word | Show or hide the controls | Look up the word, at once | FR-016 |
| Tap on no word | Show or hide the controls | Same | FR-016 |
| Long-press on a word, link included | Select it and look it up | Same | FR-001 |
| Long-press then drag | Extend the selection word by word; look up when lifted | Same | FR-018 |
| Long-press on empty space | Nothing | Same | Edge cases |
| Long-press on a page without text | "This page has no selectable text" (snackbar, 3 s) | Same | FR-028 |
| Mouse double-click on a word | Select and look up (the single clicks toggle the controls twice) | Same | FR-001 |
| Mouse drag from the selection | Extend the selection | Same | FR-018 |

With the panel open:
- a tap outside it closes it;
- a long-press selects and looks up the new word;
- swipes and page turns close it (FR-004).

## Selection

- The word is drawn with the selection highlight, in the theme's colours (FR-002).
- On touch screens, two handles sit at its ends. Each handle is at least 48 × 48 dp,
  labelled "Selection start" and "Selection end".
- A selection never crosses a page. Past 8 words, the first word is looked up.

## Panel

| Part | Contents |
|---|---|
| Header | Back (after a related lookup), headword, IPA, Copy, Close |
| Note | "running – form of run", "No entry for "in spite off"", "From Wiktionary online" |
| Body | One section per part of speech: "Noun", then numbered senses, tags in small caps, examples in italics; then the next entry |
| Footer | "Wiktionary · CC BY-SA 4.0 · About" |

- **Placement**: at the bottom, at most 1/3 of the view. At the top, from the same rule,
  when the selection's rect would be covered (FR-003). It can be dragged up to 85%.
- **Closing**: tap outside, swipe toward its edge, Esc, system back, page turn.
- **Not found**: "No definition found for "word"".
  - Online: "Search online" button.
  - Offline: "Online search isn't available offline."
  - Searching: progress, then the result marked "From Wiktionary online", or "Nothing
    found online" / "Couldn't reach Wiktionary".
- **Dictionary not ready**:
  - Web: "Downloading the dictionary… 42%", then the result.
  - Offline before the first download: "The dictionary needs an internet connection
    once to download."
  - Mobile: "Preparing the dictionary…".
- **Copy**: copies the headword (or the phrase), then shows "Copied" (FR-023).
- **Related words**: every word in a definition or example is tappable. Back returns
  through earlier entries (FR-024).

## Reader controls

- **Top bar** gains "Lookup history" (icon, labelled).
- **Settings sheet** gains the switch "Tap to define: tap a word to look it up".
- **Indicator**: when tap-to-define is on, a small chip "Tap to define" in the top corner,
  shown whether or not the controls are shown. Tapping it asks "Turn off tap to define?"
  with Turn off / Cancel (FR-017).
- **Hint**: on the first reader open, a banner at the bottom: "Long-press a word to look
  it up (double-click with a mouse). Turn on Tap to define in settings to look up with
  one tap." It closes with Got it, and doesn't come back (FR-006).

## History sheet

- Tabs "This book" and "All books". Rows show the word, the headword if different, page,
  date and "×3" (count).
- "All books" adds the book title. Rows are newest first.
- Choosing a row opens the panel for that word (no page selection).
- "Clear" opens a dialog: "Clear lookup history for this book?" (or "…for all books?"),
  with Clear / Cancel.
- Empty state: "Words you look up will appear here."

## Library

- The menu gains "About Potha", which opens Flutter's about and licences page. The
  dictionary's licence is listed there (FR-034).

## Accessibility (FR-033)

- Panel: a semantics container labelled "Definition of <word>". Each sense is its own
  node ("Noun, definition 1: …"). Controls are labelled: Back, Copy, Close, Search
  online, About this dictionary.
- Screen-reader users: in the page view's custom actions (002), "Look up word" is not
  available, because the page has no word-level semantics. Instead, the history sheet
  and the panel are fully readable. Word selection by screen reader is a known
  limitation, the same as 002's page view.
- Text scales with the system setting. At 200%, the panel keeps its first size and
  scrolls; it can be dragged taller.
- WCAG AA contrast in the light, dark and sepia panel colours.
- A panel that opens is announced ("Definition of melancholy").
