# Contract: Lookup services and view additions

The interfaces that the lookup feature depends on. All are format-agnostic
(Principle III): nothing here names pdfrx or PDF.

## Additions to the document view (002 contracts/reader-document.md)

```dart
abstract interface class DocumentViewController implements Listenable {
  // … 002 members unchanged …

  /// Where a rect in page coordinates (normalised 0–1) is on screen, or null if that
  /// page isn't laid out. Used to place handles and to choose the panel's edge.
  Rect? pageRectToGlobal(int page, Rect normalised);

  /// While true, the view ignores pans, flings and zooms (from long-press until
  /// pointer up, and while a selection handle is dragged).
  void setInteractionLocked(bool locked);
}

enum HighlightKind { match, activeMatch, selection }

class PageHighlight {
  const PageHighlight(this.page, this.rects, {this.kind = HighlightKind.match});
  // `active` from 002 becomes kind == activeMatch; search is updated accordingly.
}
```

`ReaderViewConfig` gains `selectionColor` (before the page filter, like the other
highlight colours).

## TapDetector (002 R3, extended in research R6)

| Callback | Fires when | Notes |
|---|---|---|
| `onTap(global, local)` | as in 002 | unchanged, no double-tap wait |
| `onLongPress(global, local)` | one pointer held 500 ms within 18 px, view not moving | fires while the pointer is down |
| `onLongPressMove(global)` / `onLongPressEnd()` | the same pointer moves or lifts after a long-press | extends the selection; `onTap` doesn't fire for it |
| `onDoubleClick(global, local)` | mouse only: second click within 300 ms and 18 px | the single clicks have already fired |

## Word extraction (pure Dart)

```dart
/// Character [index] under [point] in [text], or null (research R4).
int? hitTest(PageText text, Offset point);

class WordExtractor {
  /// The word around [index], with line-break and hyphen candidates, or null if it is
  /// not a word (numbers, symbols, URLs, emails: FR-011).
  WordSelection? wordAt(PageText text, int index);

  /// The selection grown or shrunk to word boundaries between [anchor] and [index].
  WordSelection extendTo(PageText text, WordSelection anchor, int index);

  LookupQuery queryFor(PageText text, WordSelection selection);
}
```

## Dictionary

```dart
/// One language's dictionary. English only in this feature; later languages are other
/// instances of the same interface.
abstract interface class Lexicon {
  String get language;                         // 'en'
  DictionaryInfo get info;                     // source, licence, dump date (FR-034)
  Future<List<DictionaryEntry>> entries(String key);
  Future<List<WordFormLink>> formsOf(String key);
  Future<bool> hasEntry(String key);
}

/// Opens or prepares the platform's dictionary file (research R2).
abstract interface class DictionaryStore {
  Stream<DictionaryStatus> get status;
  /// Starts preparing: unpacking on mobile, downloading on the web. Safe to call again.
  void ensureStarted();
  Future<Lexicon> get ready;
}

class LookupResolver {
  LookupResolver(Lexicon lexicon, {Lemmatiser lemmatiser});
  Future<LookupResult> resolve(LookupQuery query);   // ordering: research R5
}

abstract interface class OnlineDictionary {
  /// Only from the "Search online" action (FR-021, FR-032).
  Future<OnlineResult> lookUp(String word);   // found(entries) | notFound | failed
}

abstract interface class NetworkStatus {
  bool get isOnline;                           // connectivity_plus behind this
  Stream<bool> get changes;
}
```

## LookupController (Riverpod)

| Method | Effect |
|---|---|
| `lookUpAt(ReaderTap / long-press point)` | hit test → word → selection → resolve; a request id makes the latest win (FR-014) |
| `extendSelection(index)` / `endExtend()` | update the highlight; resolve when the drag ends (FR-018) |
| `lookUpWord(String)` | word inside a definition: push onto the back stack (FR-024) |
| `back()` | pop the back stack |
| `searchOnline()` | only when online; replaces the not-found body with the online result |
| `close()` | clear the selection and the panel |

Every resolved lookup the reader starts goes to `HistoryRepository.record(...)` after the
panel shows.

## Limits

- A selection lies on one page.
- A phrase is at most 8 words; longer selections look up the first word.
- Garbled text (U+FFFD, private-use or control characters) never reaches the resolver.
