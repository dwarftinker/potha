// Page view for PDFs (FR-016a): vertical scrolling, no zoom or text selection yet;
// the full reader (feature 002) replaces it.
import 'package:flutter/material.dart';
import 'package:pdfrx/pdfrx.dart';

import '../document_format.dart';
import 'pdf_document_format.dart';

class PdfDocumentViewFactory implements DocumentViewFactory {
  const PdfDocumentViewFactory();

  @override
  Widget build(
    ReaderDocument doc, {
    required int initialPage,
    required ValueChanged<int> onPageChanged,
  }) {
    final pdf = (doc as PdfReaderDocument).document;
    return PdfViewer(
      // The screen owns the document and closes it.
      PdfDocumentRefDirect(pdf, autoDispose: false),
      initialPageNumber: initialPage.clamp(1, doc.pageCount),
      params: PdfViewerParams(
        scaleEnabled: false,
        backgroundColor: Colors.transparent,
        textSelectionParams: const PdfTextSelectionParams(enabled: false),
        onPageChanged: (page) {
          if (page != null) onPageChanged(page);
        },
      ),
    );
  }
}
