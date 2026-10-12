import 'package:flutter_test/flutter_test.dart';
import 'package:potha/features/library/domain/progress.dart';

void main() {
  test('percent is the current page over the page count, rounded down (FR-013)', () {
    expect(progressPercent(currentPage: 1, pageCount: 300), 0);
    expect(progressPercent(currentPage: 150, pageCount: 300), 50);
    expect(progressPercent(currentPage: 299, pageCount: 300), 99);
  });

  test('the last page is 100%', () {
    expect(progressPercent(currentPage: 300, pageCount: 300), 100);
    expect(progressPercent(currentPage: 1, pageCount: 1), 100);
  });

  test('out-of-range pages are clamped', () {
    expect(progressPercent(currentPage: 0, pageCount: 10), 10);
    expect(progressPercent(currentPage: 50, pageCount: 10), 100);
  });

  test('label is "New" without progress, otherwise "NN%"', () {
    expect(progressLabel(currentPage: null, pageCount: 300), 'New');
    expect(progressLabel(currentPage: 126, pageCount: 300), '42%');
    expect(progressLabel(currentPage: 300, pageCount: 300), '100%');
  });
}
