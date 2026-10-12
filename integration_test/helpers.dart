// Helpers for on-device tests: PDFs are built in memory because test/fixtures/ isn't
// available on a device.
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:cross_file/cross_file.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:potha/core/document/pdf/pdf_document_view.dart';
import 'package:potha/core/document/pdf/pdf_view_controller.dart';
import 'package:potha/features/library/import/import_controller.dart';
import 'package:potha/features/library/import/import_source.dart';

/// A small valid PDF with [pages] pages and an optional Info title. With
/// [imageBytesPerPage] each page also carries an incompressible RGB image.
Uint8List buildPdf({String? title, int pages = 1, int imageBytesPerPage = 0}) {
  final objects = <List<int>>[];
  int add(List<int> body) {
    objects.add(body);
    return objects.length;
  }

  List<int> ascii(String s) => latin1.encode(s);
  final rng = Random(7);
  final font = add(
    ascii('<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica >>'),
  );
  final pagesNum = objects.length + 1;
  objects.add(const []);
  final kids = <int>[];
  for (var i = 0; i < pages; i++) {
    var resources = '<< /Font << /F1 $font 0 R >>';
    var ops = 'BT /F1 24 Tf 72 720 Td (Page ${i + 1}) Tj ET\n';
    if (imageBytesPerPage > 0) {
      final side = sqrt(imageBytesPerPage / 3).floor();
      final data = List<int>.generate(side * side * 3, (_) => rng.nextInt(256));
      final img = add([
        ...ascii(
          '<< /Type /XObject /Subtype /Image /Width $side /Height $side '
          '/ColorSpace /DeviceRGB /BitsPerComponent 8 /Length ${data.length} >>\nstream\n',
        ),
        ...data,
        ...ascii('\nendstream'),
      ]);
      resources = '<< /Font << /F1 $font 0 R >> /XObject << /Im1 $img 0 R >>';
      ops = 'q 468 0 0 468 72 200 cm /Im1 Do Q\n$ops';
    }
    final content = add(
      ascii('<< /Length ${ops.length} >>\nstream\n${ops}endstream'),
    );
    kids.add(
      add(
        ascii(
          '<< /Type /Page /Parent $pagesNum 0 R /MediaBox [0 0 612 792] '
          '/Resources $resources >> /Contents $content 0 R >>',
        ),
      ),
    );
  }
  objects[pagesNum - 1] = ascii(
    '<< /Type /Pages /Count ${kids.length} /Kids [${kids.map((k) => '$k 0 R').join(' ')}] >>',
  );
  final catalog = add(ascii('<< /Type /Catalog /Pages $pagesNum 0 R >>'));
  final info = title == null ? null : add(ascii('<< /Title ($title) >>'));

  final out = BytesBuilder()..add(ascii('%PDF-1.4\n'));
  final offsets = <int>[];
  for (var i = 0; i < objects.length; i++) {
    offsets.add(out.length);
    out
      ..add(ascii('${i + 1} 0 obj\n'))
      ..add(objects[i])
      ..add(ascii('\nendobj\n'));
  }
  final xref = out.length;
  out.add(ascii('xref\n0 ${objects.length + 1}\n0000000000 65535 f \n'));
  for (final o in offsets) {
    out.add(ascii('${o.toString().padLeft(10, '0')} 00000 n \n'));
  }
  out.add(
    ascii(
      'trailer\n<< /Size ${objects.length + 1} /Root $catalog 0 R'
      '${info == null ? '' : ' /Info $info 0 R'} >>\nstartxref\n$xref\n%%EOF\n',
    ),
  );
  return out.toBytes();
}

ImportSource sourceFromBytes(String name, Uint8List bytes) => ImportSource(
  name: name,
  size: bytes.length,
  openRead: () => Stream.value(bytes),
);

ProviderContainer containerOf(WidgetTester tester) =>
    ProviderScope.containerOf(tester.element(find.byType(Scaffold).first));

/// Pumps until [finder] matches or [timeout] passes (real time, for device tests).
Future<void> pumpUntil(
  WidgetTester tester,
  Finder finder, {
  Duration timeout = const Duration(seconds: 20),
}) async {
  final end = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(end)) {
    await tester.pump(const Duration(milliseconds: 100));
    if (finder.evaluate().isNotEmpty) return;
  }
  throw TestFailure('Timed out waiting for $finder');
}

/// A page for [buildReaderPdf].
class TestPage {
  const TestPage({
    this.lines = const [],
    this.size = const Size(612, 792),
    this.linkTo,
    this.webLink,
    this.broken = false,
  });

  final List<String> lines;
  final Size size;

  /// A link (top-left area of the page) to this 1-based page.
  final int? linkTo;

  /// A link (top-left area of the page) to this address.
  final String? webLink;

  /// Broken content and an empty MediaBox; PDFium draws it blank.
  final bool broken;
}

/// The area, in PDF points from the bottom-left, of the links [buildReaderPdf] adds.
const testLinkRect = Rect.fromLTRB(72, 600, 300, 640);

/// A PDF for the reader tests: text lines (Helvetica, WinAnsi), links, an outline of
/// `(title, page, children)` entries, compressed content (dart:io zlib).
Uint8List buildReaderPdf(List<TestPage> pages,
    {List<(String, int, List<(String, int)>)> outline = const []}) {
  final objects = <List<int>?>[];
  int add(List<int> body) {
    objects.add(body);
    return objects.length;
  }

  int reserve() {
    objects.add(null);
    return objects.length;
  }

  List<int> ascii(String s) => latin1.encode(s);
  List<int> stream(String dict, List<int> data) {
    final z = zlib.encode(data);
    return [
      ...ascii('<< $dict /Filter /FlateDecode /Length ${z.length} >>\nstream\n'),
      ...z,
      ...ascii('\nendstream'),
    ];
  }

  String esc(String s) => s.replaceAll(r'\', r'\\').replaceAll('(', r'\(').replaceAll(')', r'\)');

  final font = add(ascii('<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica '
      '/Encoding /WinAnsiEncoding >>'));
  final pagesNum = reserve();
  final pageNums = [for (final _ in pages) reserve()];
  final r = testLinkRect;
  for (var i = 0; i < pages.length; i++) {
    final p = pages[i];
    final w = p.size.width.round(), h = p.size.height.round();
    if (p.broken) {
      objects[pageNums[i] - 1] = ascii('<< /Type /Page /Parent $pagesNum 0 R /MediaBox [0 0 0 0] '
          '/Contents 99999 0 R /Resources 99998 0 R >>');
      continue;
    }
    final ops = StringBuffer();
    if (p.lines.isNotEmpty) {
      ops.write('BT /F1 12 Tf 15 TL 72 ${h - 90} Td\n');
      for (final line in p.lines) {
        ops.write('(${esc(line)}) Tj T*\n');
      }
      ops.write('ET\n');
    }
    final content = add(stream('', latin1.encode(ops.toString())));
    final annots = <int>[
      if (p.linkTo != null)
        add(ascii('<< /Type /Annot /Subtype /Link /Rect [${r.left} ${r.top} ${r.right} ${r.bottom}] '
            '/Border [0 0 0] /Dest [${pageNums[p.linkTo! - 1]} 0 R /Fit] >>')),
      if (p.webLink != null)
        add(ascii('<< /Type /Annot /Subtype /Link /Rect [${r.left} ${r.top} ${r.right} ${r.bottom}] '
            '/Border [0 0 0] /A << /S /URI /URI (${p.webLink}) >> >>')),
    ];
    objects[pageNums[i] - 1] = ascii('<< /Type /Page /Parent $pagesNum 0 R /MediaBox [0 0 $w $h] '
        '/Resources << /Font << /F1 $font 0 R >> >> /Contents $content 0 R'
        '${annots.isEmpty ? '' : ' /Annots [${annots.map((a) => '$a 0 R').join(' ')}]'} >>');
  }
  objects[pagesNum - 1] = ascii('<< /Type /Pages /Count ${pageNums.length} '
      '/Kids [${pageNums.map((k) => '$k 0 R').join(' ')}] >>');

  var catalogExtra = '';
  if (outline.isNotEmpty) {
    final root = reserve();
    (int, int) addItems(List<(String, int, List<(String, int)>)> items, int parent) {
      final nums = [for (final _ in items) reserve()];
      for (var j = 0; j < items.length; j++) {
        final (title, page, children) = items[j];
        final body = StringBuffer('<< /Title (${esc(title)}) /Parent $parent 0 R '
            '/Dest [${pageNums[page - 1]} 0 R /Fit]');
        if (j > 0) body.write(' /Prev ${nums[j - 1]} 0 R');
        if (j < items.length - 1) body.write(' /Next ${nums[j + 1]} 0 R');
        if (children.isNotEmpty) {
          final (first, last) =
              addItems([for (final (t, p) in children) (t, p, const <(String, int)>[])], nums[j]);
          body.write(' /First $first 0 R /Last $last 0 R /Count ${children.length}');
        }
        body.write(' >>');
        objects[nums[j] - 1] = ascii(body.toString());
      }
      return (nums.first, nums.last);
    }

    final (first, last) = addItems(outline, root);
    objects[root - 1] =
        ascii('<< /Type /Outlines /First $first 0 R /Last $last 0 R /Count ${outline.length} >>');
    catalogExtra = ' /Outlines $root 0 R';
  }
  final catalog = add(ascii('<< /Type /Catalog /Pages $pagesNum 0 R$catalogExtra >>'));

  final out = BytesBuilder()..add(ascii('%PDF-1.5\n'));
  final offsets = <int>[];
  for (var i = 0; i < objects.length; i++) {
    offsets.add(out.length);
    out
      ..add(ascii('${i + 1} 0 obj\n'))
      ..add(objects[i]!)
      ..add(ascii('\nendobj\n'));
  }
  final xref = out.length;
  out.add(ascii('xref\n0 ${objects.length + 1}\n0000000000 65535 f \n'));
  for (final o in offsets) {
    out.add(ascii('${o.toString().padLeft(10, '0')} 00000 n \n'));
  }
  out.add(ascii('trailer\n<< /Size ${objects.length + 1} /Root $catalog 0 R >>\n'
      'startxref\n$xref\n%%EOF\n'));
  return out.toBytes();
}

/// Lines of filler prose; page [i] of a book gets different text.
List<String> proseLines(int seed, {int count = 40, String? extra}) {
  const words = ['the', 'sea', 'was', 'calm', 'and', 'grey', 'under', 'a', 'low', 'sky',
    'while', 'ship', 'moved', 'slowly', 'north', 'past', 'islands', 'reefs', 'birds', 'light'];
  final rng = Random(seed);
  final lines = [
    for (var i = 0; i < count; i++) List.generate(9, (_) => words[rng.nextInt(words.length)]).join(' '),
  ];
  if (extra != null) lines[count ~/ 2] = '${lines[count ~/ 2]} $extra';
  return lines;
}

/// Imports [bytes] the way the platform does: from a file, through XFile (CLAUDE.md:
/// XFile streams Uint8List chunks).
Future<ImportSource> sourceViaFile(String name, Uint8List bytes) async {
  final dir = await Directory.systemTemp.createTemp('potha_it');
  final file = File('${dir.path}/$name');
  await file.writeAsBytes(bytes);
  return ImportSource.fromXFile(XFile(file.path));
}

/// Imports a book and waits for it to appear in the library.
Future<void> importBook(WidgetTester tester, String title, Uint8List bytes) async {
  await containerOf(tester).read(importControllerProvider.notifier).importSources(
      [await sourceViaFile('$title.pdf', bytes)],
      askPassword: (_, {required retry}) async => null);
  await pumpUntil(tester, find.text(title));
}

/// The open reader's view controller.
PdfViewController readerView(WidgetTester tester) =>
    tester.widget<PdfDocumentView>(find.byType(PdfDocumentView)).controller;

/// Opens [title] from the library and waits until its page view is ready.
Future<PdfViewController> openBook(WidgetTester tester, String title) async {
  await tester.tap(find.text(title).first);
  await pumpUntil(tester, find.byType(PdfDocumentView));
  final view = readerView(tester);
  await pumpUntilTrue(tester, () => view.isReady);
  await settleFor(tester, const Duration(milliseconds: 500));
  return view;
}

/// Like [openBook], but stops the clock as soon as the page view is ready (timings).
Future<PdfViewController> openBookFast(WidgetTester tester, String title) async {
  await tester.tap(find.text(title).first);
  await pumpUntil(tester, find.byType(PdfDocumentView));
  final view = readerView(tester);
  await pumpUntilTrue(tester, () => view.isReady);
  await tester.pump();
  return view;
}

/// Pumps until [condition] holds or [timeout] passes (real time).
Future<void> pumpUntilTrue(WidgetTester tester, bool Function() condition,
    {Duration timeout = const Duration(seconds: 20), String? reason}) async {
  final end = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(end)) {
    if (condition()) return;
    await tester.pump(const Duration(milliseconds: 50));
  }
  throw TestFailure('Timed out waiting for ${reason ?? 'a condition'}');
}

/// Pumps frames for [duration] of real time (animations, rendering).
Future<void> settleFor(WidgetTester tester, Duration duration) async {
  final end = DateTime.now().add(duration);
  while (DateTime.now().isBefore(end)) {
    await tester.pump(const Duration(milliseconds: 16));
  }
}

/// The global position of a point on [page], given normalised to the page.
Offset globalOnPage(PdfViewController view, int page, Offset normalised) {
  final rect = view.pdf.layout.pageLayouts[page - 1];
  final doc = Offset(rect.left + rect.width * normalised.dx, rect.top + rect.height * normalised.dy);
  return view.pdf.documentToGlobal(doc)!;
}
