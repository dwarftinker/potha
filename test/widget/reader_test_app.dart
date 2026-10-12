// Fakes for reader widget tests: a scriptable document, and a view that records what the
// reader screen asks of it (002 T016).
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:potha/core/document/document_format.dart';
import 'package:potha/core/document/page_unavailable.dart';
import 'package:potha/core/document/pdf/pdf_document_format.dart';
import 'package:potha/features/reader/reader.dart';
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

  @override
  PagePoint? pagePointAt(Offset globalPosition) => null;
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
}) async {
  final view = FakeViewFactory();
  final app = TestApp(overrides: readerOverrides(doc, view));
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
