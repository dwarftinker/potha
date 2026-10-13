# Draft: pdfrx feature request (not posted)

Draft for an issue on the pdfrx repository (espresso3389/pdfrx). It combines 001's T077
(document metadata) with 002's T077 (dark-mode rendering). **It needs the user's approval
before it is posted, because posting is public.**

---

**Title**: Expose document metadata and colour-scheme rendering (both are in pdfium.wasm
already)

**Body**:

Thanks for pdfrx. We use it in a Flutter reading app on Android, iOS and the web, and
there are two PDFium features we'd like to use through pdfrx's API.

1. **Document metadata (title, author).** `FPDF_GetMetaText` is exported by the bundled
   `pdfium.wasm`. However, `pdfium_worker.js` has a fixed command table with no metadata
   command, and the native `FPDF_DOCUMENT` handle is private. Could `PdfDocument` gain
   something like `Future<Map<String, String>> loadMetadata()` (or `title` and `author`
   getters) on both native and web? We currently parse the Info dictionary and XMP
   ourselves in Dart.

2. **Rendering with a colour scheme, for dark reading modes.**
   `FPDF_RenderPageBitmapWithColorScheme_Start` recolours text and paths but leaves
   images alone, so photos look right in a dark theme. It is also in `pdfium.wasm`, but
   the worker always calls `FPDF_RenderPageBitmap`. A `colorScheme` option on
   `PdfPage.render` (and a matching `PdfViewerParams` setting) would let apps offer a dark
   mode that doesn't invert photos.

   An alternative that would also help: page-object bounds by type
   (`FPDFPage_CountObjects`, `FPDFPage_GetObject`, `FPDFPageObj_GetType` and
   `FPDFPageObj_GetBounds`, all exported), so apps can find image areas themselves.

We're happy to help with a PR if you'd accept one, on both the native (FFI) side and the
web worker side.

Versions: pdfrx 2.6.5, pdfrx_engine 0.6.1, Flutter 3.47.

---

Where we would use it in Potha:
- metadata: `lib/core/document/pdf/pdf_metadata_reader.dart` (001 research R1);
- colour scheme: `lib/features/reader/domain/reader_theme.dart` and the view's page
  filter (002 research R5, FR-028).
