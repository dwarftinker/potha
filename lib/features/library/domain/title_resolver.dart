/// Picks a book's title (FR-010): the metadata title if it isn't blank; otherwise the
/// tidied file name; and if that has no letters, "Untitled book" plus the date added.
String resolveTitle({
  required String? metadataTitle,
  required String fileName,
  required DateTime addedAt,
  required String Function(DateTime) formatDate,
}) {
  final meta = metadataTitle?.trim() ?? '';
  if (meta.isNotEmpty) return meta;

  final dot = fileName.lastIndexOf('.');
  final base = dot > 0 ? fileName.substring(0, dot) : (dot == 0 ? '' : fileName);
  final tidy = base.replaceAll('_', ' ').replaceAll(RegExp(r'\s+'), ' ').trim();
  if (RegExp(r'\p{L}', unicode: true).hasMatch(tidy)) return tidy;

  return 'Untitled book ${formatDate(addedAt)}';
}
