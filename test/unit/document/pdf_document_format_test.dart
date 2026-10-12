import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pdfrx/pdfrx.dart';
import 'package:potha/core/document/document_format.dart';
import 'package:potha/core/document/pdf/pdf_document_format.dart';

BookFileRef ref(String fixture, {bool withPath = true}) {
  final file = File('test/fixtures/$fixture');
  return BookFileRef(
    path: withPath ? file.absolute.path : null,
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
    // No path_provider plugin in host tests; give pdfrx a cache directory directly.
    Pdfrx.cacheDirectoryPath = Directory.systemTemp.createTempSync('pdfrx_test').path;
    await pdfrxFlutterInitialize();
  });

  test('sniff accepts PDFs and rejects other files', () {
    expect(
      format.sniff(File('test/fixtures/three_pages.pdf').readAsBytesSync()),
      isTrue,
    );
    expect(
      format.sniff(File('test/fixtures/not_a_pdf.pdf').readAsBytesSync()),
      isFalse,
    );
  });

  group('with PDFium', () {
    test('opens a PDF by path and reads pages and metadata', () async {
      final doc = await format.open(ref('with_metadata.pdf'));
      expect(doc.pageCount, 1);
      expect(doc.usedPassword, isNull);
      expect((await doc.readMetadata()).title, 'The Brothers Karamazov');
      await doc.close();
    });

    test('opens a PDF from bytes (web path)', () async {
      final doc = await format.open(ref('three_pages.pdf', withPath: false));
      expect(doc.pageCount, 3);
      await doc.close();
    });

    test('asks for a password, retries after a wrong one, and reports the used password', () async {
      final asked = <bool>[];
      final doc = await format.open(
        ref('encrypted.pdf'),
        askPassword: ({required retry}) async {
          asked.add(retry);
          return retry ? 'secret' : 'wrong';
        },
      );
      expect(asked, [false, true]);
      expect(doc.usedPassword, 'secret');
      await doc.close();
    });

    test('a known password is tried first', () async {
      var asked = false;
      final doc = await format.open(
        ref('encrypted.pdf'),
        knownPassword: 'secret',
        askPassword: ({required retry}) async {
          asked = true;
          return null;
        },
      );
      expect(asked, isFalse);
      await doc.close();
    });

    test('cancelling the password throws passwordCancelled', () async {
      await expectLater(
        format.open(
          ref('encrypted.pdf'),
          askPassword: ({required retry}) async => null,
        ),
        throwsA(
          isA<DocumentOpenException>().having(
            (e) => e.kind,
            'kind',
            DocumentOpenFailure.passwordCancelled,
          ),
        ),
      );
    });

    test('a truncated file throws damaged', () async {
      await expectLater(
        format.open(ref('truncated.pdf')),
        throwsA(
          isA<DocumentOpenException>().having(
            (e) => e.kind,
            'kind',
            DocumentOpenFailure.damaged,
          ),
        ),
      );
    });

    testWidgets('renders page 1 to PNG at the requested width', (tester) async {
      await tester.runAsync(() async {
        final doc = await format.open(ref('three_pages.pdf'));
        final png = await doc.renderPagePng(1, width: 360);
        expect(png, isNotNull);
        expect(png!.sublist(1, 4), 'PNG'.codeUnits);
        await doc.close();
      });
    });
  }, skip: _skip);
}
