# Contract: Platform integration

What the app declares to each operating system or browser so files can reach it.

## Android

- `AndroidManifest.xml`, main activity (`launchMode="singleTask"`):
  - `ACTION_VIEW`, category `DEFAULT` and `BROWSABLE`, `mimeType="application/pdf"`, for
    the `content` and `file` schemes ("Open with").
  - `ACTION_SEND` and `ACTION_SEND_MULTIPLE`, `mimeType="application/pdf"` ("Share to").
- Files arrive through `receive_sharing_intent`, both at cold start (`getInitialMedia`)
  and while running (`getMediaStream`). Each becomes an `ImportSource`.
- The file picker uses the system document picker; no storage permission is requested.

## iOS (supported, not verified; see constitution v2.0.0)

- `Info.plist`: `CFBundleDocumentTypes` for `com.adobe.pdf`, with
  `LSSupportsOpeningDocumentsInPlace = NO`, so iOS gives the app a copy.
- A Share Extension target as described in the `receive_sharing_intent` docs, sharing an
  App Group with the app.
- Books are stored in Application Support, so they are not shown in the Files app.

## Web

- File picker: `file_picker` with `allowedExtensions: ['pdf']`, multiple selection.
- Drag and drop: `desktop_drop` `DropTarget` around the library screen. A visible drop
  zone appears while dragging (accessible label "Drop PDF files to add them").
- Storage: OPFS, with `navigator.storage.persist()` requested on first import.
- Static files in `web/`: `sqlite3.wasm` and `drift_worker.js` (drift),
  `pdfium.wasm` (pdfrx). PDFium is loaded only when needed (research R10).
- Must be served over HTTPS (or localhost) because OPFS needs a secure context.
