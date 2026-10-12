/speckit.specify Build in-book dictionary lookup: when a reader selects a word, show its
definition instantly without leaving the page.

Why: this is the app's core differentiator. Readers, especially language learners and
people reading technical or literary texts, constantly hit unfamiliar words. Switching to
another app breaks concentration. Lookup must be instant, work offline and feel like part
of reading.

User stories (in priority order):

P1 – Look up a word by selecting it. When I long-press a word on the page, that word is
selected and a definition panel slides up from the bottom covering no more than about a
third of the screen, so I can still see the context. On web with a mouse, double-clicking
a word does the same. The panel shows: the word, its pronunciation (phonetic spelling)
when available, part of speech, numbered definitions grouped by part of speech, and an
example sentence where available. I dismiss the panel by tapping outside it, swiping it
down or pressing Escape, and the selection clears.

P1 – Get the right entry for inflected words. If I select "running", "mice", "better" or
"studied", I see the definition of the base word ("run", "mouse", "good", "study"), with
a note like "running – form of run". If the exact form has its own entry (e.g.
"building" as a noun), that entry is shown first.

P1 – Works offline. Lookup works with no network connection, using a dictionary that is
included with the app. Definitions appear in under 300 ms.

P2 – Tap-to-define mode. I can turn on a mode where a single tap on any word shows its
definition, without long-pressing. When the mode is on, a small indicator is visible so
I'm not confused about why taps behave differently. Tapping page edges still turns pages.

P2 – Look up a selected phrase. If I extend the selection to several words (e.g. "give
up", "in spite of"), the app looks up the phrase. If no phrase entry exists, it shows the
definition of the first word and says the phrase wasn't found.

P2 – Not found. If a word isn't in the offline dictionary, the panel says so clearly and,
when online, offers "Search online" which tries an online dictionary source and shows the
result in the same panel. When offline, it says online search is unavailable.

P3 – Related actions. From the definition panel I can copy the word, and jump to related
words shown in the definition (tapping a word inside a definition looks it up, with a
back button to return to the previous definition).

P3 – Lookup history. The app keeps a list of words I've looked up, per book and overall,
with the date and page. I can clear this history at any time.

Word selection rules (important for correctness):
- Leading and trailing punctuation and quotation marks are removed ("“Hello,”" → "hello").
- Apostrophes are handled sensibly ("don't" stays as one word; "reader's" looks up
  "reader").
- A word hyphenated across a line break ("exam-" / "ple") is joined and looked up as
  "example". A genuine hyphenated word ("well-known") is looked up as a whole first, then
  by its parts if not found.
- Case doesn't matter, except a capitalised word that also has a proper-noun entry may
  show both.
- Numbers, symbols and URLs don't trigger a lookup.

Edge cases:
- Scanned pages with no text: long-pressing shows a brief message that this page has no
  selectable text, rather than doing nothing.
- Pages where text extraction yields garbled characters (broken fonts): the app shows
  what it extracted and says no definition was found, without crashing.
- Lookup while zoomed in or in continuous scroll mode works the same as in paged mode.
- The panel never covers the selected word; if the word is in the lower part of the
  screen, the page scrolls or the panel opens from the top.
- Rapidly looking up several words in a row always shows the most recent word's
  definition.
- Initial release dictionary language is English; the design should not prevent adding
  other languages later.

Success criteria:
- 95% of single-word lookups on standard English prose return a correct definition
  offline.
- Definition panel appears within 300 ms of the gesture on a mid-range phone.
- For inflected forms in a test list of 200 common words, at least 95% resolve to the
  correct base word.
- Hyphenated line-break words are correctly joined in at least 95% of test cases.
- Usability: a first-time user discovers lookup (long-press) within their first reading
  session, aided by a one-time hint shown on first open of the reader.
- Works on Android, iOS and both mobile and desktop web browsers.

Out of scope: translation between languages, saving words to a vocabulary list and
flashcards (later feature), audio pronunciation, highlights, OCR for scanned pages,
dictionaries for languages other than English.
