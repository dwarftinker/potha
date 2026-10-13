import 'package:flutter_test/flutter_test.dart';
import 'package:potha/features/reader/domain/page_number_input.dart';

void main() {
  test('accepts a page in range (FR-023)', () {
    expect(parsePageNumber('120', 300), const PageNumberOk(120));
    expect(parsePageNumber(' 7 ', 300), const PageNumberOk(7));
    expect(parsePageNumber('1', 300), const PageNumberOk(1));
    expect(parsePageNumber('300', 300), const PageNumberOk(300));
  });

  test('rejects anything else with the range', () {
    for (final input in ['0', '301', '-3', 'abc', '', '1.5', '12a']) {
      expect(parsePageNumber(input, 300), const PageNumberError('Enter a page from 1 to 300.'),
          reason: input);
    }
  });

  test('a one-page book', () {
    expect(parsePageNumber('2', 1), const PageNumberError('This book has only page 1.'));
  });
}
