// Helpers for on-device tests: PDFs are built in memory because test/fixtures/ isn't
// available on a device.
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
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
