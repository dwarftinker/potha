// PDF implementation of the document abstraction, backed by pdfrx (PDFium).
import 'dart:async';
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

  /// Pages PDFium could not load or render; the view shows a placeholder (FR-037).
  final failedPages = <int>{};

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

  static const _a4 = ui.Size(595, 842);

  @override
  ui.Size pageSize(int pageNumber) {
    final page = document.pages[pageNumber - 1];
    if (page.width <= 0 || page.height <= 0) return _a4;
    return ui.Size(page.width, page.height);
  }

  /// The page, loaded; null if PDFium can't load it.
  Future<PdfPage?> _loaded(int pageNumber) async {
    try {
      final page = await document.pages[pageNumber - 1].ensureLoaded();
      if (page.width <= 0 || page.height <= 0) {
        failedPages.add(pageNumber);
        return null;
      }
      return page;
    } catch (_) {
      failedPages.add(pageNumber);
      return null;
    }
  }

  /// [r] in PDF coordinates (bottom-left origin) normalised to [page] (top-left origin).
  static ui.Rect _normalise(PdfRect r, PdfPage page) => ui.Rect.fromLTRB(
        r.left / page.width,
        (page.height - r.top) / page.height,
        r.right / page.width,
        (page.height - r.bottom) / page.height,
      );

  @override
  Future<List<OutlineEntry>> loadOutline() async {
    List<OutlineEntry> map(List<PdfOutlineNode> nodes) => [
          for (final n in nodes)
            OutlineEntry(
              title: n.title.trim(),
              page: switch (n.dest?.pageNumber) {
                final p? when p >= 1 && p <= pageCount => p,
                _ => null,
              },
              children: map(n.children),
            ),
        ];
    try {
      return map(await document.loadOutline());
    } catch (_) {
      return const [];
    }
  }

  @override
  Future<List<DocumentLink>> loadLinks(int pageNumber) async {
    final page = await _loaded(pageNumber);
    if (page == null) return const [];
    try {
      final links = await page.loadLinks(compact: true, enableAutoLinkDetection: false);
      return [
        for (final link in links)
          for (final r in link.rects)
            if (link.dest?.pageNumber case final p? when p >= 1 && p <= pageCount)
              PageLink(_normalise(r, page), p)
            else if (link.url case final url? when url.hasScheme)
              WebLink(_normalise(r, page), url),
      ];
    } catch (_) {
      return const [];
    }
  }

  @override
  Future<PageText?> loadPageText(int pageNumber) async {
    final page = await _loaded(pageNumber);
    if (page == null) return null;
    try {
      final raw = await page.loadText();
      if (raw == null) return PageText.empty;
      return PageText(raw.fullText, [for (final r in raw.charRects) _normalise(r, page)]);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<ui.Image?> renderPageImage(int pageNumber,
      {required int width, Future<void>? cancel}) async {
    final page = await _loaded(pageNumber);
    if (page == null) return null;
    final token = page.createCancellationToken();
    var cancelled = false;
    unawaited(cancel?.then((_) {
      cancelled = true;
      token.cancel();
    }));
    try {
      final height = (page.height * width / page.width).round();
      final pdfImage = await page.render(
        fullWidth: width.toDouble(),
        fullHeight: height.toDouble(),
        backgroundColor: 0xFFFFFFFF,
        cancellationToken: token,
      );
      if (pdfImage == null) return null;
      try {
        return await pdfImage.createImage();
      } finally {
        pdfImage.dispose();
      }
    } catch (_) {
      if (!cancelled) failedPages.add(pageNumber);
      return null;
    }
  }

  @override
  Future<void> close() => document.dispose();
}

/// Formats the app can import, in sniffing order.
final documentFormatsProvider =
    Provider<List<DocumentFormat>>((ref) => const [PdfDocumentFormat()]);
