// Fakes for reader widget tests: a scriptable document, and a view that records what the
// reader screen asks of it (002 T016).
import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:potha/core/dictionary/dictionary_store.dart';
import 'package:potha/core/document/document_format.dart';
import 'package:potha/core/document/page_unavailable.dart';
import 'package:potha/core/document/pdf/pdf_document_format.dart';
import 'package:potha/core/platform/network_status.dart';
import 'package:potha/features/reader/ui/reader_screen.dart';

import 'test_app.dart';

class FakeReaderDocument implements ReaderDocument {
  FakeReaderDocument({
    this.pageCount = 300,
    this.usedPassword,
    this.outline = const [],
    Map<int, List<DocumentLink>>? links,
    Map<int, String>? texts,
    this.failingPages = const {},
    this.size = const ui.Size(600, 800),
  })  : links = links ?? {},
        texts = texts ?? {};

  @override
  final int pageCount;
  @override
  final String? usedPassword;
  final List<OutlineEntry> outline;
  final Map<int, List<DocumentLink>> links;

  /// Page text by page; pages not listed have no text.
  final Map<int, String> texts;
  final Set<int> failingPages;
  final ui.Size size;
  var closed = false;
  final textRequests = <int>[];

  @override
  Future<DocumentMetadata> readMetadata() async => DocumentMetadata.empty;
  @override
  Future<Uint8List?> renderPagePng(int pageNumber, {required int width}) async => null;
  @override
  ui.Size pageSize(int pageNumber) => size;
  @override
  Future<List<OutlineEntry>> loadOutline() async => outline;
  @override
  Future<List<DocumentLink>> loadLinks(int pageNumber) async => links[pageNumber] ?? const [];
  @override
  Future<PageText?> loadPageText(int pageNumber) async {
    textRequests.add(pageNumber);
    if (failingPages.contains(pageNumber)) return null;
    final text = texts[pageNumber] ?? '';
    if (text.contains('\n')) return layOutLines(text);
    // One rect per character, on a grid: 40 characters a line.
    return PageText(text, [
      for (var i = 0; i < text.length; i++)
        ui.Rect.fromLTWH((i % 40) / 40, (i ~/ 40) / 50, 1 / 40, 1 / 50),
    ]);
  }

  @override
  Future<ui.Image?> renderPageImage(int pageNumber,
      {required int width, Future<void>? cancel}) async {
    if (failingPages.contains(pageNumber)) return null;
    final recorder = ui.PictureRecorder();
    ui.Canvas(recorder).drawColor(const Color(0xFFFFFFFF), BlendMode.src);
    final height = (width * size.height / size.width).round();
    return recorder.endRecording().toImage(width, height);
  }

  @override
  Future<void> close() async => closed = true;
}

/// Page text for lines separated by "\r\n" (as PDFium gives them), laid out like a
/// book: each line 1/25 of the page high from the top, each character 1/50 wide from a
/// 0.1 margin. Line breaks have empty rects (003 word layouts).
PageText layOutLines(String text) {
  final rects = <ui.Rect>[];
  var line = 0, column = 0;
  for (var i = 0; i < text.length; i++) {
    final c = text[i];
    if (c == '\r' || c == '\n') {
      rects.add(ui.Rect.zero);
      if (c == '\n') {
        line++;
        column = 0;
      }
      continue;
    }
    rects.add(ui.Rect.fromLTWH(0.1 + column / 50, 0.05 + line / 25, 1 / 50, 1 / 30));
    column++;
  }
  return PageText(text, rects);
}

/// The view-local centre of the [index]th character of [text] laid out by [layOutLines],
/// as a fraction of the page.
ui.Offset charCentre(String text, int index) => layOutLines(text).charRects[index].center;

/// A dictionary from maps. [delays] holds lookups back until completed (latest-wins
/// tests); [calls] records every key asked for.
class FakeLexicon implements Lexicon {
  FakeLexicon({this.entryMap = const {}, this.formMap = const {}});

  final Map<String, List<DictionaryEntry>> entryMap;
  final Map<String, List<WordFormLink>> formMap;
  final calls = <String>[];
  final delays = <String, Future<void>>{};

  @override
  String get language => 'en';

  @override
  DictionaryInfo get info => const DictionaryInfo(
    source: 'English Wiktionary via wiktextract / kaikki.org',
    licence: 'CC BY-SA 4.0',
    licenceUrl: 'https://creativecommons.org/licenses/by-sa/4.0/',
    sourceUrl: 'https://en.wiktionary.org/',
    dumpDate: '2026-09-02',
    version: '20260902.1',
  );

  @override
  Future<List<DictionaryEntry>> entries(String key) async {
    calls.add(key);
    await delays[key];
    return entryMap[key] ?? const [];
  }

  @override
  Future<List<WordFormLink>> formsOf(String key) async {
    await delays[key];
    return formMap[key] ?? const [];
  }

  @override
  Future<bool> hasEntry(String key) async => entryMap.containsKey(key);
}

/// A dictionary entry with numbered senses, for fakes.
DictionaryEntry entry(String headword, String pos, List<String> glosses,
        {String? ipa, List<String> examples = const []}) =>
    DictionaryEntry(
      headword: headword,
      pos: pos,
      ipa: ipa,
      senses: [
        for (var i = 0; i < glosses.length; i++)
          Sense(glosses[i], examples: i == 0 ? examples : const []),
      ],
    );

/// A store whose status tests set; ready at once by default.
class FakeDictionaryStore implements DictionaryStore {
  FakeDictionaryStore(Lexicon lexicon, {bool ready = true}) : _lexicon = lexicon {
    if (ready) markReady();
  }

  final Lexicon _lexicon;
  final _changes = StreamController<DictionaryStatus>.broadcast();
  final _ready = Completer<Lexicon>();
  DictionaryStatus _current = const DictionaryNotStarted();
  var startCalls = 0;

  @override
  DictionaryStatus get current => _current;
  @override
  Stream<DictionaryStatus> get status => _changes.stream;
  @override
  Future<Lexicon> get ready => _ready.future;
  @override
  void ensureStarted() => startCalls++;

  void setStatus(DictionaryStatus status) {
    _current = status;
    _changes.add(status);
  }

  void markReady() {
    setStatus(const DictionaryReady());
    if (!_ready.isCompleted) _ready.complete(_lexicon);
  }

  @override
  Future<void> close() => _changes.close();
}

/// Scripted online results; records each word asked for.
class FakeOnlineDictionary implements OnlineDictionary {
  FakeOnlineDictionary([this.result = const OnlineNotFound()]);

  OnlineResult result;
  final calls = <String>[];

  @override
  Future<OnlineResult> lookUp(String word) async {
    calls.add(word);
    return result;
  }
}

class FakeNetworkStatus implements NetworkStatus {
  // ignore: prefer_initializing_formals (named parameters can't be private)
  FakeNetworkStatus({bool online = true}) : _online = online;

  bool _online;
  final _changes = StreamController<bool>.broadcast();

  @override
  bool get isOnline => _online;
  @override
  Stream<bool> get changes => _changes.stream;

  set online(bool value) {
    _online = value;
    _changes.add(value);
  }
}

/// Opens every book as [doc].
class FakeFormat implements DocumentFormat {
  FakeFormat(this.doc);
  final ReaderDocument doc;
  @override
  String get id => 'pdf';
  @override
  bool sniff(Uint8List header) => true;
  @override
  Future<ReaderDocument> open(BookFileRef file,
          {String? knownPassword, AskPassword? askPassword}) async =>
      doc;
}

/// Records calls; tests move the "view" with [emitPosition] and tap with [tapAt].
class FakeViewController extends ChangeNotifier implements DocumentViewController {
  final calls = <String>[];
  final goTos = <ReadingPosition>[];
  ReaderViewConfig? config;
  ReadingPosition _position = const ReadingPosition(1, 0);
  double _zoom = 1;
  int pageCount = 1;

  @override
  bool get isReady => config != null;
  @override
  ReadingPosition get position => _position;
  @override
  double get zoom => _zoom;

  /// The view reports a new position, as when the reader scrolls.
  void emitPosition(ReadingPosition p) {
    _position = p;
    config!.onPositionChanged(p);
  }

  @override
  Future<void> goTo(ReadingPosition position, {bool animate = true}) async {
    goTos.add(position);
    calls.add('goTo(${position.page}, ${position.offsetY})');
    emitPosition(position);
  }

  @override
  Future<void> next() async {
    calls.add('next');
    final mode = config!.mode;
    if (mode == PageMode.paged && _position.page < pageCount) {
      emitPosition(ReadingPosition(_position.page + 1, 0));
    }
  }

  @override
  Future<void> previous() async {
    calls.add('previous');
    if (config!.mode == PageMode.paged && _position.page > 1) {
      emitPosition(ReadingPosition(_position.page - 1, 0));
    }
  }

  @override
  Future<void> scrollBy(double fraction) async => calls.add('scrollBy($fraction)');
  @override
  Future<void> zoomIn() async {
    calls.add('zoomIn');
    _zoom *= 1.25;
  }

  @override
  Future<void> zoomOut() async {
    calls.add('zoomOut');
    _zoom = (_zoom / 1.25).clamp(1, 5);
  }

  /// The fake view shows the current page filling the view.
  BuildContext? viewContext;

  Rect? get viewRect {
    final box = viewContext?.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize || !box.attached) return null;
    return box.localToGlobal(Offset.zero) & box.size;
  }

  @override
  PagePoint? pagePointAt(Offset globalPosition) {
    final r = viewRect;
    if (r == null || !r.contains(globalPosition)) return null;
    return PagePoint(_position.page,
        Offset((globalPosition.dx - r.left) / r.width, (globalPosition.dy - r.top) / r.height));
  }

  /// Only the current page is "laid out": it fills the view.
  @override
  Rect? pageRectToGlobal(int page, Rect normalised) {
    final r = viewRect;
    if (r == null || page != _position.page) return null;
    return Rect.fromLTRB(
      r.left + normalised.left * r.width,
      r.top + normalised.top * r.height,
      r.left + normalised.right * r.width,
      r.top + normalised.bottom * r.height,
    );
  }

  bool interactionLocked = false;

  @override
  void setInteractionLocked(bool locked) {
    interactionLocked = locked;
    calls.add('locked($locked)');
  }
}

class FakeViewFactory implements DocumentViewFactory {
  final controllers = <FakeViewController>[];
  FakeViewController get controller => controllers.last;

  @override
  DocumentViewController createController() {
    final c = FakeViewController();
    controllers.add(c);
    return c;
  }

  @override
  Widget build(ReaderDocument doc,
      {required DocumentViewController controller, required ReaderViewConfig config}) {
    final c = controller as FakeViewController
      ..config = config
      ..pageCount = doc.pageCount;
    return _FakeView(doc: doc, controller: c, config: config);
  }
}

const fakeViewKey = ValueKey('fake-view');

class _FakeView extends StatefulWidget {
  const _FakeView({required this.doc, required this.controller, required this.config});
  final ReaderDocument doc;
  final FakeViewController controller;
  final ReaderViewConfig config;

  @override
  State<_FakeView> createState() => _FakeViewState();
}

class _FakeViewState extends State<_FakeView> {
  @override
  void initState() {
    super.initState();
    widget.controller._position = widget.config.initialPosition;
    widget.controller.addListener(_changed);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_changed);
    super.dispose();
  }

  void _changed() => setState(() {});

  @override
  Widget build(BuildContext context) {
    widget.controller.viewContext = context;
    final page = widget.controller.position.page;
    final failing =
        widget.doc is FakeReaderDocument && (widget.doc as FakeReaderDocument).failingPages.contains(page);
    return SizedBox.expand(
      key: fakeViewKey,
      child: ColoredBox(
        color: widget.config.backgroundColor,
        child: Center(
          child: failing
              ? const PageUnavailable()
              : Text('View page $page ${widget.config.mode.name} ${widget.config.fit.name}'),
        ),
      ),
    );
  }
}

/// Overrides that open every book with [doc] in a [FakeViewFactory].
/// (TestApp supplies the dictionary, network and online fakes.)
List<Override> readerOverrides(FakeReaderDocument doc, FakeViewFactory view) => [
      documentFormatsProvider.overrideWithValue([FakeFormat(doc)]),
      documentViewFactoriesProvider.overrideWithValue({'pdf': view}),
    ];

/// Taps the view at [fraction] of its width, at mid-height.
Future<void> tapView(WidgetTester tester, double fraction) async {
  final rect = tester.getRect(find.byKey(fakeViewKey));
  await tester.tapAt(Offset(rect.left + rect.width * fraction, rect.center.dy));
  await tester.pump();
}

/// Starts the app, adds a book and opens it in the reader with [doc] and a fake view.
Future<(TestApp, FakeViewFactory)> openReader(
  WidgetTester tester,
  FakeReaderDocument doc, {
  int? currentPage,
  Future<void> Function(TestApp app)? before,
  FakeDictionaryStore? store,
  FakeNetworkStatus? network,
  OnlineDictionary? online,
}) async {
  final view = FakeViewFactory();
  final app = TestApp(
    dictionaryStore: store,
    network: network,
    online: online,
    overrides: readerOverrides(doc, view),
  );
  await app.pump(tester);
  await seedBook(tester, app.db,
      id: 'b1', title: 'Moby-Dick', pageCount: doc.pageCount, currentPage: currentPage);
  await before?.call(app);
  final navigator = tester.state<NavigatorState>(find.byType(Navigator));
  navigator.push(MaterialPageRoute<void>(builder: (_) => const ReaderScreen(bookId: 'b1')));
  await settleReal(tester);
  await tester.pump(const Duration(milliseconds: 500));
  return (app, view);
}

/// Unmounts the reader and app, letting every timer finish.
Future<void> closeReader(WidgetTester tester, TestApp app) async {
  await tester.pump(const Duration(seconds: 5));
  await settleReal(tester);
  await app.dispose(tester);
}

/// Pops the reader and pumps frame by frame until its route has closed (the closing
/// animation needs intermediate frames), well within the saver's 1 s timer.
Future<void> leaveReader(WidgetTester tester) async {
  Navigator.of(tester.element(find.byKey(fakeViewKey))).pop();
  for (var i = 0; i < 8 && find.byType(ReaderScreen, skipOffstage: false).evaluate().isNotEmpty;
      i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
  expect(find.byType(ReaderScreen, skipOffstage: false), findsNothing);
}

/// Closes the one-time lookup hint if it is showing (003 FR-006).
Future<void> dismissHint(WidgetTester tester) async {
  final gotIt = find.text('Got it');
  if (gotIt.evaluate().isEmpty) return;
  await tester.tap(gotIt);
  await settleReal(tester);
  await tester.pump(const Duration(milliseconds: 300));
}

/// A reader screen for [bookId], for tests that open a book a second time.
Widget readerScreenFor(String bookId) => ReaderScreen(bookId: bookId);
