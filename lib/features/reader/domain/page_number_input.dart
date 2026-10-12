import 'package:flutter/foundation.dart';

/// The result of reading a typed page number (FR-023).
@immutable
sealed class PageNumberInput {
  const PageNumberInput();
}

class PageNumberOk extends PageNumberInput {
  const PageNumberOk(this.page);
  final int page;
  @override
  bool operator ==(Object other) => other is PageNumberOk && other.page == page;
  @override
  int get hashCode => page;
  @override
  String toString() => 'PageNumberOk($page)';
}

class PageNumberError extends PageNumberInput {
  const PageNumberError(this.message);
  final String message;
  @override
  bool operator ==(Object other) => other is PageNumberError && other.message == message;
  @override
  int get hashCode => message.hashCode;
  @override
  String toString() => 'PageNumberError($message)';
}

PageNumberInput parsePageNumber(String input, int pageCount) {
  final text = input.trim();
  final page = RegExp(r'^\d+$').hasMatch(text) ? int.tryParse(text) : null;
  if (page != null && page >= 1 && page <= pageCount) return PageNumberOk(page);
  return PageNumberError(pageCount == 1
      ? 'This book has only page 1.'
      : 'Enter a page from 1 to $pageCount.');
}
