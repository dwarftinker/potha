import '../../../core/document/document_format.dart';

/// The chapter the reader is in: the deepest entry whose page is at or before [page]
/// (FR-024). Entries without a page are skipped.
OutlineEntry? currentChapter(List<OutlineEntry> outline, int page) {
  OutlineEntry? best;
  int? bestPage;
  void visit(List<OutlineEntry> entries) {
    for (final e in entries) {
      final p = e.page;
      // Later entries at the same page win, so a section beats its chapter.
      if (p != null && p <= page && (bestPage == null || p >= bestPage!)) {
        best = e;
        bestPage = p;
      }
      visit(e.children);
    }
  }

  visit(outline);
  return best;
}
