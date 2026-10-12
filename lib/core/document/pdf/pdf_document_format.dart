// PDF implementation of the document abstraction, backed by pdfrx (PDFium).
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pdfrx/pdfrx.dart';

import '../document_format.dart';
import 'pdf_metadata_file_io.dart'
    if (dart.library.js_interop) 'pdf_metadata_file_web.dart';
import 'pdf_metadata_reader.dart';

class PdfDocumentFormat implements DocumentFormat {
  const PdfDocumentFormat();

  static const _magic = [0x25, 0x50, 0x44, 0x46, 0x2D]; // %PDF-

  @override
  String get id => 'pdf';

  /// `%PDF-` within the first 1024 bytes.
  @override
  bool sniff(Uint8List header) {
    final end = header.length < 1024 ? header.length : 1024;
    outer:
    for (var i = 0; i + _magic.length <= end; i++) {
      for (var j = 0; j < _magic.length; j++) {
        if (header[i + j] != _magic[j]) continue outer;
      }
      return true;
    }
    return false;
  }

  @override
  Future<ReaderDocument> open(
    BookFileRef file, {
    String? knownPassword,
    AskPassword? askPassword,
  }) async {
    var attempts = 0;
    String? lastPassword;
    Future<String?> provide() async {
      attempts++;
      if (attempts == 1 && knownPassword != null) return lastPassword = knownPassword;
      final retry = attempts > 1;
      return lastPassword = await askPassword?.call(retry: retry);
    }

    try {
      // Idempotent. Done here rather than at startup so PDFium (and on the web its WASM
      // module) loads only when a PDF is first needed (research R10).
      await pdfrxFlutterInitialize();
      if (file.path != null) {
        final doc = await PdfDocument.openFile(file.path!, passwordProvider: provide);
        return PdfReaderDocument(doc, file, attempts == 0 ? null : lastPassword);
      }
      // Web: no file path; the bytes are already in browser memory (max 100 MB).
      final bytes = await file.readAll();
      final doc = await PdfDocument.openData(bytes, passwordProvider: provide);
      return PdfReaderDocument(doc, file, attempts == 0 ? null : lastPassword, bytes);
    } on PdfPasswordException catch (e) {
      throw DocumentOpenException(DocumentOpenFailure.passwordCancelled, e);
    } catch (e) {
      throw DocumentOpenException(DocumentOpenFailure.damaged, e);
    }
  }
}

/// A PDF opened through pdfrx; the page view needs the underlying [document].
class PdfReaderDocument implements ReaderDocument {
  PdfReaderDocument(this.document, this._file, this.usedPassword, [this._bytes]);

  final PdfDocument document;
  final BookFileRef _file;
  final Uint8List? _bytes;

  @override
  final String? usedPassword;

  @override
  int get pageCount => document.pages.length;

  @override
  Future<DocumentMetadata> readMetadata() async {
    if (usedPassword != null) return DocumentMetadata.empty; // encrypted strings
    try {
      if (_file.path != null) return await readMetadataFromPath(_file.path!);
      return PdfMetadataReader.read(_bytes ?? await _file.readAll());
    } catch (_) {
      return DocumentMetadata.empty;
    }
  }

  @override
  Future<Uint8List?> renderPagePng(int pageNumber, {required int width}) async {
    try {
      final page = document.pages[pageNumber - 1];
      final height = (page.height * width / page.width).round();
      final pdfImage = await page.render(
        fullWidth: width.toDouble(),
        fullHeight: height.toDouble(),
        backgroundColor: 0xFFFFFFFF,
      );
      if (pdfImage == null) return null;
      try {
        final image = await pdfImage.createImage();
        final data = await image.toByteData(format: ui.ImageByteFormat.png);
        image.dispose();
        return data?.buffer.asUint8List();
      } finally {
        pdfImage.dispose();
      }
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> close() => document.dispose();
}

/// Formats the app can import, in sniffing order.
final documentFormatsProvider =
    Provider<List<DocumentFormat>>((ref) => const [PdfDocumentFormat()]);
