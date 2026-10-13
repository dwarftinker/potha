// The reader's additions to ReaderDocument, with real PDFium (002 T009).
import 'dart:io';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:pdfrx/pdfrx.dart';
import 'package:potha/core/document/document_format.dart';
import 'package:potha/core/document/pdf/pdf_document_format.dart';

BookFileRef ref(String fixture) {
  final file = File('test/fixtures/$fixture');
  return BookFileRef(
    path: file.absolute.path,
    readAll: file.readAsBytes,
    sizeBytes: file.lengthSync(),
  );
}

// PDFium for host tests comes from tool/fetch_test_pdfium.sh (Linux x64).
final _pdfium = File('build/test_pdfium/libpdfium.so');
final _skip = _pdfium.existsSync()
    ? null
    : 'PDFium not found; run tool/fetch_test_pdfium.sh to enable these tests';

void main() {
  const format = PdfDocumentFormat();

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    if (_skip != null) return;
    Pdfrx.pdfiumModulePath = _pdfium.absolute.path;
    Pdfrx.cacheDirectoryPath = Directory.systemTemp.createTempSync('pdfrx_test').path;
    await pdfrxFlutterInitialize();
  });

  Future<ReaderDocument> open(String fixture) => format.open(ref(fixture));

  test('loadOutline returns the nested table of contents', () async {
    final doc = await open('outline_links.pdf');
    addTearDown(doc.close);
    final outline = await doc.loadOutline();
    expect(outline.map((e) => (e.title, e.page)), [
      ('Chapter One', 1),
      ('Chapter Two', 5),
      ('Chapter Three', 9),
    ]);
    expect(outline[1].children.map((e) => (e.title, e.page)), [
      ('Section 2.1', 6),
      ('Section 2.2', 7),
    ]);
    expect(outline[2].children.every((e) => e.children.isEmpty), isTrue);
  }, skip: _skip);

  test('loadOutline is empty for a book without one', () async {
    final doc = await open('three_pages.pdf');
    addTearDown(doc.close);
    expect(await doc.loadOutline(), isEmpty);
  }, skip: _skip);

  test('loadLinks finds page and web links with normalised rects', () async {
    final doc = await open('outline_links.pdf');
    addTearDown(doc.close);
    final page1 = await doc.loadLinks(1);
    expect(page1, hasLength(1));
    final link = page1.single as PageLink;
    expect(link.page, 9);
    // PDF rect (72, 600)-(300, 640) on a 612 x 792 page, top-left origin.
    expect(link.rect.left, closeTo(72 / 612, 0.01));
    expect(link.rect.top, closeTo((792 - 640) / 792, 0.01));
    expect(link.rect.right, closeTo(300 / 612, 0.01));
    expect(link.rect.bottom, closeTo((792 - 600) / 792, 0.01));

    final page2 = await doc.loadLinks(2);
    expect(page2.whereType<WebLink>().single.uri, Uri.parse('https://example.org/potha'));
    expect(await doc.loadLinks(3), isEmpty);
  }, skip: _skip);

  test('loadPageText returns text with one normalised rect per character', () async {
    final doc = await open('accents.pdf');
    addTearDown(doc.close);
    final text = (await doc.loadPageText(1))!;
    expect(text.text, contains('Café'));
    expect(text.text, contains('naïve'));
    expect(text.charRects, hasLength(text.text.length));
    final c = text.charRects[text.text.indexOf('C')];
    expect(c.left, inInclusiveRange(0, 1));
    expect(c.top, inInclusiveRange(0, 1));
    expect(c.width, greaterThan(0));
    // The first line sits near the top of the page.
    expect(c.top, lessThan(0.2));
    expect(text.hasText, isTrue);
  }, skip: _skip);

  // 003 research R4: PDFium ends a normal line with "\r\n", and replaces a line-end hyphen
  // with U+0002 and no line break ("exam\u0002ple"). The word rules depend on both.
  test('lookup_prose.pdf: line breaks, line-end hyphens and curly quotes (003)', () async {
    final doc = await open('lookup_prose.pdf');
    addTearDown(doc.close);
    final page1 = (await doc.loadPageText(1))!.text;
    expect(page1, contains('melancholy reader was running late.\r\nThree mice'));
    expect(page1, contains('\u201cHello,\u201d'));
    final page2 = (await doc.loadPageText(2))!;
    expect(page2.text, contains('exam\u0002ple of a well\u0002known'));
    expect(page2.text, contains('a well-known fact'));
    expect(page2.charRects, hasLength(page2.text.length));
  }, skip: _skip);

  test('lookup_garbled.pdf extracts control characters, not words (003 FR-029)', () async {
    final doc = await open('lookup_garbled.pdf');
    addTearDown(doc.close);
    final text = (await doc.loadPageText(1))!.text;
    expect(text, '\u0001\u0002\u0003\u0001\u0004 \u0002\u0003\u0004\u0001');
  }, skip: _skip);

  test('loadPageText is empty for an image-only page', () async {
    final doc = await open('scanned.pdf');
    addTearDown(doc.close);
    final text = await doc.loadPageText(1);
    expect(text, isNotNull);
    expect(text!.hasText, isFalse);
  }, skip: _skip);

  test('pageSize reports each page as displayed, including a landscape fold-out', () async {
    final doc = await open('mixed_sizes.pdf');
    addTearDown(doc.close);
    expect(doc.pageSize(1), const Size(595, 842));
    expect(doc.pageSize(3), const Size(1191, 842));
    expect(doc.pageSize(4), const Size(420, 595));
  }, skip: _skip);

  test('renderPageImage renders at the requested width', () async {
    final doc = await open('mixed_sizes.pdf');
    addTearDown(doc.close);
    final image = (await doc.renderPageImage(3, width: 200))!;
    addTearDown(image.dispose);
    expect(image.width, 200);
    expect(image.height, closeTo(200 * 842 / 1191, 1));
  }, skip: _skip);

  test('a damaged page neither throws nor stops other pages (FR-037)', () async {
    // PDFium draws a page with broken content and an empty MediaBox as a blank Letter
    // page, so a page that truly fails to render can't be made from a fixture; the
    // placeholder for that case is covered with a fake document in the widget tests.
    final doc = await open('damaged_page.pdf');
    addTearDown(doc.close);
    expect(doc.pageCount, 5);
    expect(doc.pageSize(3).isEmpty, isFalse);
    (await doc.renderPageImage(3, width: 100))?.dispose();
    await doc.loadPageText(3);
    expect(await doc.loadLinks(3), isEmpty);
    final ok = await doc.renderPageImage(4, width: 100);
    expect(ok, isNotNull);
    ok!.dispose();
  }, skip: _skip);
}
