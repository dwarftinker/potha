import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:potha/core/document/document_format.dart';
import 'package:potha/core/document/pdf/pdf_metadata_reader.dart';

DocumentMetadata read(String fixture) =>
    PdfMetadataReader.read(File('test/fixtures/$fixture').readAsBytesSync());

void main() {
  test('reads Info title and author', () {
    expect(read('with_metadata.pdf'),
        const DocumentMetadata(title: 'The Brothers Karamazov', author: 'Fyodor Dostoevsky'));
  });

  test('decodes a UTF-16BE title', () {
    expect(read('utf16_title.pdf').title, 'Crime and Punishment – Преступление');
  });

  test('reads Info from a compressed object stream', () {
    expect(read('object_stream_metadata.pdf'),
        const DocumentMetadata(title: 'The Brothers Karamazov', author: 'Fyodor Dostoevsky'));
  });

  test('falls back to XMP', () {
    expect(read('xmp_only.pdf'),
        const DocumentMetadata(title: 'War & Peace', author: 'Leo Tolstoy'));
  });

  test('returns nulls when there is no metadata', () {
    expect(read('no_metadata.pdf'), DocumentMetadata.empty);
  });

  test('returns nulls for encrypted files', () {
    expect(read('encrypted.pdf'), DocumentMetadata.empty);
  });

  test('never throws on damaged or non-PDF input', () {
    expect(read('truncated.pdf'), DocumentMetadata.empty);
    expect(read('not_a_pdf.pdf'), DocumentMetadata.empty);
  });
}
