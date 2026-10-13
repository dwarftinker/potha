// The lookup flow: point -> word -> selection -> result, latest request wins
// (003 data-model.md "LookupState", FR-014, SC-007).
import 'dart:async';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:potha/core/dictionary/dictionary_store.dart';
import 'package:potha/core/document/document_format.dart';
import 'package:potha/core/platform/network_status.dart';
import 'package:potha/features/reader/data/page_text_cache.dart';
import 'package:potha/features/reader/lookup_controller.dart';

/// Words on one line, each character 0.02 wide from x = 0.1, at y 0.05–0.08.
PageText line(String text) => PageText(text, [
  for (var i = 0; i < text.length; i++) Rect.fromLTWH(0.1 + i * 0.02, 0.05, 0.02, 0.03),
]);

/// The page point on the [n]th character of [word] in [text].
PagePoint at(int page, String text, String word, {int n = 1}) {
  final i = text.indexOf(word) + n;
  return PagePoint(page, Offset(0.1 + i * 0.02 + 0.01, 0.065));
}

DictionaryEntry e(String headword, String pos) =>
    DictionaryEntry(headword: headword, pos: pos, senses: [Sense('$headword meaning')]);

class TestLexicon implements Lexicon {
  TestLexicon(this.map);
  final Map<String, List<DictionaryEntry>> map;
  final holds = <String, Completer<void>>{};

  @override
  String get language => 'en';
  @override
  DictionaryInfo get info => const DictionaryInfo(
    source: 'test',
    licence: 'CC BY-SA 4.0',
    licenceUrl: '',
    sourceUrl: '',
    dumpDate: '',
    version: '1',
  );
  @override
  Future<List<DictionaryEntry>> entries(String key) async {
    await holds[key]?.future;
    return map[key] ?? const [];
  }

  @override
  Future<List<WordFormLink>> formsOf(String key) async => const [];
  @override
  Future<bool> hasEntry(String key) async => map.containsKey(key);
}

class TestStore implements DictionaryStore {
  TestStore(this.lexicon, {bool ready = true}) {
    if (ready) markReady();
  }
  final Lexicon lexicon;
  final _changes = StreamController<DictionaryStatus>.broadcast();
  final _ready = Completer<Lexicon>();
  DictionaryStatus _current = const DictionaryNotStarted();
  var starts = 0;

  @override
  DictionaryStatus get current => _current;
  @override
  Stream<DictionaryStatus> get status => _changes.stream;
  @override
  Future<Lexicon> get ready => _ready.future;
  @override
  void ensureStarted() => starts++;
  @override
  Future<void> close() => _changes.close();

  void set(DictionaryStatus s) {
    _current = s;
    _changes.add(s);
  }

  void markReady() {
    set(const DictionaryReady());
    if (!_ready.isCompleted) _ready.complete(lexicon);
  }
}

class TestNetwork implements NetworkStatus {
  TestNetwork(this._online);
  bool _online;
  final _changes = StreamController<bool>.broadcast();
  @override
  bool get isOnline => _online;
  @override
  Stream<bool> get changes => _changes.stream;
  set online(bool v) {
    _online = v;
    _changes.add(v);
  }
}

class TestOnline implements OnlineDictionary {
  final words = <String>[];
  OnlineResult next = const OnlineNotFound();
  Completer<void>? hold;
  @override
  Future<OnlineResult> lookUp(String word) async {
    words.add(word);
    await hold?.future;
    return next;
  }
}

void main() {
  const text = 'The melancholy reader was running late. Turkey';
  late TestLexicon lexicon;
  late TestStore store;
  late Map<int, PageText?> pages;
  late LookupController c;
  late TestNetwork network;
  late TestOnline online;

  LookupController controller() => LookupController(
    store: store,
    pageText: PageTextCache((p) async => pages[p]),
    network: network,
    online: online,
  );

  setUp(() {
    lexicon = TestLexicon({
      'melancholy': [e('melancholy', 'noun'), e('melancholy', 'adj')],
      'reader': [e('reader', 'noun')],
      'late': [e('late', 'adj')],
    });
    store = TestStore(lexicon);
    network = TestNetwork(true);
    online = TestOnline();
    pages = {1: line(text), 2: PageText.empty, 3: line('before \u0001\u0002\u0003 after')};
    c = controller();
  });

  tearDown(() => c.dispose());

  test('a long-press point resolves to shown, with the selection', () async {
    await c.lookUpAt(at(1, text, 'melancholy'));
    final s = c.state as LookupShown;
    expect(s.result.sections.map((x) => x.entry.pos), ['noun', 'adj']);
    expect(s.selection!.text, 'melancholy');
    expect(c.selection, s.selection);
  });

  test('an empty spot leaves the state as it was', () async {
    await c.lookUpAt(const PagePoint(1, Offset(0.9, 0.9)));
    expect(c.state, isA<LookupIdle>());
    await c.lookUpAt(at(1, text, 'reader'));
    await c.lookUpAt(const PagePoint(1, Offset(0.9, 0.9)));
    expect((c.state as LookupShown).selection!.text, 'reader');
  });

  test('a page without text gives noText, then idle', () async {
    final seen = <Type>[];
    c.addListener(() => seen.add(c.state.runtimeType));
    await c.lookUpAt(const PagePoint(2, Offset(0.5, 0.5)));
    expect(seen, [LookupNoText, LookupIdle]);
  });

  test('garbled text gives notFound with the extracted text', () async {
    await c.lookUpAt(at(3, 'before \u0001\u0002\u0003 after', '\u0001', n: 0));
    final s = c.state as LookupNotFound;
    expect(s.result.query.garbled, isTrue);
    expect(s.result.query.display, '\u0001\u0002\u0003');
  });

  test('a word without an entry gives notFound', () async {
    await c.lookUpAt(at(1, text, 'running'));
    expect((c.state as LookupNotFound).result.query.display, 'running');
  });

  test('while the store is not ready: preparing with progress, then shown', () async {
    store = TestStore(lexicon, ready: false);
    c.dispose();
    c = controller();
    final pending = c.lookUpAt(at(1, text, 'melancholy'));
    await pumpEventQueue();
    expect(store.starts, greaterThan(0));
    expect(c.state, isA<LookupPreparing>());
    expect((c.state as LookupPreparing).selection!.text, 'melancholy');
    store.set(const DictionaryDownloading(42, 100));
    await pumpEventQueue();
    expect((c.state as LookupPreparing).status, isA<DictionaryDownloading>());
    store.markReady();
    await pending;
    expect(c.state, isA<LookupShown>());
  });

  test('a failed store shows preparing(failed) and retries on the next lookup', () async {
    store = TestStore(lexicon, ready: false);
    c.dispose();
    c = controller();
    unawaited(c.lookUpAt(at(1, text, 'melancholy')));
    await pumpEventQueue();
    store.set(const DictionaryFailed(DictionaryFailure.offline));
    await pumpEventQueue();
    expect((c.state as LookupPreparing).status, isA<DictionaryFailed>());
    final before = store.starts;
    unawaited(c.lookUpAt(at(1, text, 'reader')));
    await pumpEventQueue();
    expect(store.starts, greaterThan(before));
  });

  test('latest wins: ten requests where earlier ones finish later end on the tenth', () async {
    final words = ['melancholy', 'reader', 'late'];
    for (final w in words) {
      lexicon.holds[w] = Completer<void>();
    }
    final requests = <Future<void>>[];
    for (var i = 0; i < 10; i++) {
      requests.add(c.lookUpAt(at(1, text, words[i % 3])));
      await pumpEventQueue();
    }
    // The tenth asked for "melancholy"; release in reverse order of asking.
    for (final w in words.reversed) {
      lexicon.holds[w]!.complete();
      await pumpEventQueue();
    }
    await Future.wait(requests);
    expect((c.state as LookupShown).selection!.text, 'melancholy');
  });

  test('close() clears the selection and drops a pending lookup', () async {
    lexicon.holds['reader'] = Completer<void>();
    final pending = c.lookUpAt(at(1, text, 'reader'));
    await pumpEventQueue();
    expect(c.selection, isNotNull, reason: 'the word is highlighted while it loads');
    c.close();
    lexicon.holds['reader']!.complete();
    await pending;
    expect(c.state, isA<LookupIdle>());
    expect(c.selection, isNull);
  });

  group('online search (US6)', () {
    test('not found while online offers it; searchOnline shows the online entry', () async {
      await c.lookUpAt(at(1, text, 'running'));
      expect((c.state as LookupNotFound).online, OnlineSearch.available);
      expect(online.words, isEmpty, reason: 'nothing is sent without the reader asking');
      online.next = OnlineFound([e('running', 'noun')]);
      online.hold = Completer<void>();
      final searching = c.searchOnline();
      await pumpEventQueue();
      expect((c.state as LookupNotFound).online, OnlineSearch.searching);
      online.hold!.complete();
      await searching;
      final shown = c.state as LookupShown;
      expect(shown.result.source, EntrySource.online);
      expect(shown.result.headword, 'running');
      expect(online.words, ['running']);
    });

    test('nothing found online, or a failure, says so', () async {
      await c.lookUpAt(at(1, text, 'running'));
      await c.searchOnline();
      expect((c.state as LookupNotFound).online, OnlineSearch.nothingFound);
      online.next = const OnlineFailed();
      await c.lookUpAt(at(1, text, 'running'));
      await c.searchOnline();
      expect((c.state as LookupNotFound).online, OnlineSearch.failed);
    });

    test('offline: not available, and searchOnline does nothing', () async {
      network.online = false;
      await c.lookUpAt(at(1, text, 'running'));
      expect((c.state as LookupNotFound).online, OnlineSearch.unavailable);
      await c.searchOnline();
      expect(online.words, isEmpty);
    });

    test('going offline or online updates the offer', () async {
      await c.lookUpAt(at(1, text, 'running'));
      network.online = false;
      await pumpEventQueue();
      expect((c.state as LookupNotFound).online, OnlineSearch.unavailable);
      network.online = true;
      await pumpEventQueue();
      expect((c.state as LookupNotFound).online, OnlineSearch.available);
    });

    test('garbled text is never searched online', () async {
      await c.lookUpAt(at(3, 'before \u0001\u0002\u0003 after', '\u0001', n: 0));
      expect((c.state as LookupNotFound).online, OnlineSearch.unavailable);
      await c.searchOnline();
      expect(online.words, isEmpty);
    });
  });

  group('related words and Back (US7)', () {
    test('lookUpWord pushes onto the back stack; back() returns', () async {
      await c.lookUpAt(at(1, text, 'melancholy'));
      final first = c.state as LookupShown;
      expect(c.canGoBack, isFalse);
      await c.lookUpWord('reader');
      expect((c.state as LookupShown).result.headword, 'reader');
      expect(c.canGoBack, isTrue);
      await c.lookUpWord('late,');
      expect((c.state as LookupShown).result.headword, 'late');
      c.back();
      expect((c.state as LookupShown).result.headword, 'reader');
      c.back();
      expect(c.state, same(first));
      expect(c.canGoBack, isFalse);
      // The page selection stays on the word first pressed.
      expect(c.selection!.text, 'melancholy');
    });

    test('a word without an entry is pushed too, as not found', () async {
      await c.lookUpAt(at(1, text, 'melancholy'));
      await c.lookUpWord('zorblax');
      expect(c.state, isA<LookupNotFound>());
      c.back();
      expect((c.state as LookupShown).result.headword, 'melancholy');
    });

    test('a new lookup on the page clears the stack', () async {
      await c.lookUpAt(at(1, text, 'melancholy'));
      await c.lookUpWord('reader');
      await c.lookUpAt(at(1, text, 'late'));
      expect(c.canGoBack, isFalse);
    });

    test('latest wins for related lookups too', () async {
      await c.lookUpAt(at(1, text, 'melancholy'));
      lexicon.holds['reader'] = Completer<void>();
      final slow = c.lookUpWord('reader');
      await pumpEventQueue();
      await c.lookUpWord('late');
      lexicon.holds['reader']!.complete();
      await slow;
      expect((c.state as LookupShown).result.headword, 'late');
    });
  });
}
