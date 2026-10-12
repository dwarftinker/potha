/// Reading progress shown in the library (FR-013): the current page over the page
/// count, rounded down, except that the last page is 100%.
int progressPercent({required int currentPage, required int pageCount}) {
  if (pageCount <= 0) return 0;
  final page = currentPage.clamp(1, pageCount);
  return page == pageCount ? 100 : page * 100 ~/ pageCount;
}

/// "New" for a book never opened, otherwise "NN%".
String progressLabel({required int? currentPage, required int pageCount}) =>
    currentPage == null
        ? 'New'
        : '${progressPercent(currentPage: currentPage, pageCount: pageCount)}%';
