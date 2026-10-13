// Starts unpacking the bundled dictionary on Android and iOS after the first frame, so
// it is ready before the first lookup (003 research R2). On the web this does nothing:
// the stub keeps the dictionary store out of the first-load bundle (FR-022); the reader
// starts the download when a book opens.
export 'dictionary_warmup_stub.dart' if (dart.library.io) 'dictionary_warmup_io.dart';
