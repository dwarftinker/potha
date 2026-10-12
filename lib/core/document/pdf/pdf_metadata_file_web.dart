import '../document_format.dart';

/// Web files have no path; metadata is read from bytes instead.
Future<DocumentMetadata> readMetadataFromPath(String path) =>
    throw UnsupportedError('No file paths on the web');
