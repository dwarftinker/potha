// The PDF page view with real PDFium (host tests; tool/fetch_test_pdfium.sh).
// Checks layout, positions and paging logic; feel and speed are checked on devices.
import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pdfrx/pdfrx.dart';
import 'package:potha/core/document/document_format.dart';
import 'package:potha/core/document/pdf/pdf_document_format.dart';
import 'package:potha/core/document/pdf/pdf_document_view.dart';
import 'package:potha/core/document/pdf/pdf_view_controller.dart';

final _pdfium = File('build/test_pdfium/libpdfium.so');
final _skip = !_pdfium.existsSync(); // run tool/fetch_test_pdfium.sh to enable

void main() {
  setUpAll(() async {
    if (_skip) return;
    Pdfrx.pdfiumModulePath = _pdfium.absolute.path;
    Pdfrx.cacheDirectoryPath = Directory.systemTemp.createTempSync('pdfrx_view').path;
    await pdfrxFlutterInitialize();
  });

  late PdfReaderDocument doc;
  late PdfViewController controller;
  late List<ReadingPosition> reported;

  // Moves animate, and animations only advance while the test pumps: start a move with
  // unawaited(...), then settle.
  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 20; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  Future<void> show(WidgetTester tester, String fixture,
      {PageMode mode = PageMode.paged,
      PageFit fit = PageFit.fitWidth,
      ReadingPosition start = const ReadingPosition(1, 0)}) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final file = File('test/fixtures/$fixture');
    doc = (await tester.runAsync(() => const PdfDocumentFormat().open(BookFileRef(
        path: file.absolute.path,
        readAll: file.readAsBytes,
        sizeBytes: file.lengthSync()))))! as PdfReaderDocument;
    controller = const PdfDocumentViewFactory().createController() as PdfViewController;
    reported = [];
    await tester.pumpWidget(MaterialApp(
      home: _Host(doc: doc, controller: controller, mode: mode, fit: fit, start: start,
          onPosition: reported.add),
    ));
    await settle(tester);
  }

  Future<void> close(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await settle(tester);
    await tester.runAsync(doc.close);
  }

  testWidgets('opens at the start position, at the normal view', (tester) async {
    await show(tester, 'outline_links.pdf', start: const ReadingPosition(4, 0));
    expect(controller.isReady, isTrue);
    expect(controller.zoom, closeTo(1, 0.001));
    expect(controller.position.page, 4);
    await close(tester);
  }, skip: _skip);

  testWidgets('paged: next and previous turn exactly one page; ends do nothing (FR-007, FR-010)',
      (tester) async {
    await show(tester, 'outline_links.pdf');
    unawaited(controller.next());
    await settle(tester);
    expect(controller.position.page, 2);
    unawaited(controller.previous());
    await settle(tester);
    unawaited(controller.previous());
    await settle(tester);
    expect(controller.position.page, 1);
    unawaited(controller.goTo(const ReadingPosition(12, 0), animate: false));
    await settle(tester);
    unawaited(controller.next());
    await settle(tester);
    expect(controller.position.page, 12);
    await close(tester);
  }, skip: _skip);

  testWidgets('paged: a long swipe turns, a short one snaps back', (tester) async {
    await show(tester, 'outline_links.pdf');
    await tester.dragFrom(const Offset(300, 400), const Offset(-60, 0));
    await settle(tester);
    expect(controller.position.page, 1);
    await tester.dragFrom(const Offset(300, 400), const Offset(-150, 0));
    await settle(tester);
    expect(controller.position.page, 2);
    await tester.dragFrom(const Offset(100, 400), const Offset(150, 0));
    await settle(tester);
    expect(controller.position.page, 1);
    expect(reported.map((p) => p.page), containsAllInOrder([2, 1]));
    await close(tester);
  }, skip: _skip);

  testWidgets('paged: zoomed in, the zoom is kept on the next page, shown from its top-left (FR-021)',
      (tester) async {
    await show(tester, 'outline_links.pdf');
    unawaited(controller.setZoom(2));
    await settle(tester);
    expect(controller.zoom, closeTo(2, 0.01));
    unawaited(controller.next());
    await settle(tester);
    expect(controller.position, const ReadingPosition(2, 0));
    expect(controller.zoom, closeTo(2, 0.01));
    final page2 = controller.pdf.layout.pageLayouts[1];
    expect(controller.visibleRect.left, closeTo(page2.left, 1));
    await close(tester);
  }, skip: _skip);

  testWidgets('paged: a landscape fold-out is shown whole, centred (FR-036)', (tester) async {
    await show(tester, 'mixed_sizes.pdf', start: const ReadingPosition(3, 0));
    final rect = controller.pdf.layout.pageLayouts[2];
    expect(rect.width, closeTo(400, 0.5));
    expect(rect.height, closeTo(400 * 842 / 1191, 0.5));
    expect(controller.visibleRect.contains(rect.center), isTrue);
    await close(tester);
  }, skip: _skip);

  testWidgets('continuous: next scrolls one screen less a line (FR-007)', (tester) async {
    await show(tester, 'text_500.pdf', mode: PageMode.continuous);
    final before = controller.visibleRect.top;
    unawaited(controller.next());
    await settle(tester);
    expect(controller.visibleRect.top - before, closeTo(800 - 800 / 24, 1));
    await close(tester);
  }, skip: _skip);

  testWidgets('continuous: goTo puts the saved point at the top of the view (FR-012)',
      (tester) async {
    await show(tester, 'text_500.pdf',
        mode: PageMode.continuous, start: const ReadingPosition(57, 0.5));
    final p = controller.position;
    expect(p.page, 57);
    expect(p.offsetY, closeTo(0.5, 0.01));
    await close(tester);
  }, skip: _skip);

  testWidgets('switching mode or fit keeps the page and place (FR-015)', (tester) async {
    await show(tester, 'text_500.pdf',
        mode: PageMode.continuous, start: const ReadingPosition(57, 0.5));
    Future<void> rebuild(PageMode mode, PageFit fit) async {
      await tester.pumpWidget(MaterialApp(
        home: _Host(doc: doc, controller: controller, mode: mode, fit: fit,
            start: const ReadingPosition(57, 0.5), onPosition: reported.add),
      ));
      await settle(tester);
    }

    await rebuild(PageMode.continuous, PageFit.fitPage);
    expect(controller.position.page, 57);
    expect(controller.position.offsetY, closeTo(0.5, 0.02));
    await rebuild(PageMode.paged, PageFit.fitPage);
    expect(controller.position.page, 57);
    await rebuild(PageMode.continuous, PageFit.fitWidth);
    expect(controller.position.page, 57);
    await close(tester);
  }, skip: _skip);

  testWidgets('rotating keeps the page and place (FR-015)', (tester) async {
    await show(tester, 'text_500.pdf',
        mode: PageMode.continuous, start: const ReadingPosition(120, 0.25));
    tester.view.physicalSize = const Size(800, 400);
    await tester.pump();
    await settle(tester);
    expect(controller.position.page, 120);
    expect(controller.position.offsetY, closeTo(0.25, 0.02));
    await close(tester);
  }, skip: _skip);

  testWidgets('pagePointAt maps a screen point to the page under it', (tester) async {
    await show(tester, 'outline_links.pdf');
    final rect = controller.pdf.layout.pageLayouts[0];
    final global = Offset(rect.left + rect.width * 0.25, rect.top + rect.height * 0.75);
    final point = controller.pagePointAt(global)!;
    expect(point.page, 1);
    expect(point.offset.dx, closeTo(0.25, 0.01));
    expect(point.offset.dy, closeTo(0.75, 0.01));
    await close(tester);
  }, skip: _skip);

  // 003: placing handles and the panel needs page rects on screen (contracts/lookup.md).
  void expectRoundTrip(int page) {
    const n = Rect.fromLTRB(0.25, 0.25, 0.5, 0.3);
    final global = controller.pageRectToGlobal(page, n)!;
    final tl = controller.pagePointAt(global.topLeft + const Offset(0.5, 0.5))!;
    final br = controller.pagePointAt(global.bottomRight - const Offset(0.5, 0.5))!;
    expect((tl.page, br.page), (page, page));
    expect(tl.offset.dx, closeTo(0.25, 0.01));
    expect(tl.offset.dy, closeTo(0.25, 0.01));
    expect(br.offset.dx, closeTo(0.5, 0.01));
    expect(br.offset.dy, closeTo(0.3, 0.01));
  }

  testWidgets('pageRectToGlobal maps page rects to the screen in both modes and zoomed (003)',
      (tester) async {
    await show(tester, 'three_pages.pdf');
    expectRoundTrip(1);
    expect(controller.pageRectToGlobal(9, const Rect.fromLTRB(0, 0, 1, 1)), isNull);
    unawaited(controller.setZoom(2));
    await settle(tester);
    expectRoundTrip(1);
    await close(tester);

    await show(tester, 'three_pages.pdf',
        mode: PageMode.continuous, start: const ReadingPosition(2, 0));
    expectRoundTrip(2);
    unawaited(controller.setZoom(3));
    await settle(tester);
    expectRoundTrip(2);
    await close(tester);
  }, skip: _skip);

  testWidgets('the interaction lock blocks drags in both modes (003 research R6)', (tester) async {
    await show(tester, 'outline_links.pdf');
    controller.setInteractionLocked(true);
    await tester.pump();
    await tester.dragFrom(const Offset(300, 400), const Offset(-150, 0));
    await settle(tester);
    expect(controller.position.page, 1);
    controller.setInteractionLocked(false);
    await tester.pump();
    await tester.dragFrom(const Offset(300, 400), const Offset(-150, 0));
    await settle(tester);
    expect(controller.position.page, 2);
    await close(tester);

    await show(tester, 'outline_links.pdf', mode: PageMode.continuous);
    final top = controller.visibleRect.top;
    controller.setInteractionLocked(true);
    await tester.pump();
    await tester.dragFrom(const Offset(200, 600), const Offset(0, -300));
    await settle(tester);
    expect(controller.visibleRect.top, closeTo(top, 0.5));
    controller.setInteractionLocked(false);
    await tester.pump();
    await tester.dragFrom(const Offset(200, 600), const Offset(0, -300));
    await settle(tester);
    expect(controller.visibleRect.top, greaterThan(top + 100));
    await close(tester);
  }, skip: _skip);
}

class _Host extends StatelessWidget {
  const _Host({
    required this.doc,
    required this.controller,
    required this.mode,
    required this.fit,
    required this.start,
    required this.onPosition,
  });

  final PdfReaderDocument doc;
  final PdfViewController controller;
  final PageMode mode;
  final PageFit fit;
  final ReadingPosition start;
  final ValueChanged<ReadingPosition> onPosition;

  @override
  Widget build(BuildContext context) => const PdfDocumentViewFactory().build(doc,
      controller: controller,
      config: ReaderViewConfig(
          mode: mode, fit: fit, initialPosition: start, onPositionChanged: onPosition));
}
