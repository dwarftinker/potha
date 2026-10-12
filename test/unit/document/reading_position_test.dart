import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:potha/core/document/reading_position.dart';

void main() {
  group('ReadingPosition', () {
    test('clamps the page to 1..pageCount and the offset to 0..1', () {
      expect(ReadingPosition.clamped(0, -0.5, pageCount: 10), const ReadingPosition(1, 0));
      expect(ReadingPosition.clamped(12, 1.5, pageCount: 10), const ReadingPosition(10, 1));
      expect(ReadingPosition.clamped(4, 0.25, pageCount: 10), const ReadingPosition(4, 0.25));
    });

    test('fromVisible gives the fraction of the page height at the top of the view', () {
      const page = Rect.fromLTWH(0, 1000, 600, 800);
      expect(ReadingPosition.fromVisible(page: 3, pageRect: page, visibleTop: 1000).offsetY, 0);
      expect(ReadingPosition.fromVisible(page: 3, pageRect: page, visibleTop: 1400).offsetY, 0.5);
      expect(ReadingPosition.fromVisible(page: 3, pageRect: page, visibleTop: 900).offsetY, 0);
      expect(ReadingPosition.fromVisible(page: 3, pageRect: page, visibleTop: 1900).offsetY, 1);
      expect(ReadingPosition.fromVisible(page: 3, pageRect: page, visibleTop: 1400).page, 3);
    });

    test('topIn inverts fromVisible', () {
      const page = Rect.fromLTWH(0, 1000, 600, 800);
      final p = ReadingPosition.fromVisible(page: 3, pageRect: page, visibleTop: 1320);
      expect(p.topIn(page), closeTo(1320, 1e-9));
    });

    test('the same position points at the same content after the page is rescaled (FR-015)',
        () {
      const portrait = Rect.fromLTWH(0, 1000, 600, 800);
      const landscape = Rect.fromLTWH(0, 2000, 1200, 1600); // rotated: twice as wide
      final p = ReadingPosition.fromVisible(page: 3, pageRect: portrait, visibleTop: 1200);
      // A quarter of the way down the page in both layouts.
      expect((p.topIn(landscape) - landscape.top) / landscape.height, closeTo(0.25, 1e-9));
    });

    test('a zero-height page counts as its top', () {
      const empty = Rect.fromLTWH(0, 10, 0, 0);
      expect(ReadingPosition.fromVisible(page: 1, pageRect: empty, visibleTop: 50).offsetY, 0);
    });

    test('value equality and toString', () {
      expect(const ReadingPosition(2, 0.5), const ReadingPosition(2, 0.5));
      expect(const ReadingPosition(2, 0.5).hashCode, const ReadingPosition(2, 0.5).hashCode);
      expect(const ReadingPosition(2, 0.5), isNot(const ReadingPosition(2, 0.6)));
      expect(const ReadingPosition(2, 0.5).toString(), 'ReadingPosition(page 2, 0.500)');
    });

    test('isNearlySameAs ignores offset changes under 1% of a page', () {
      const a = ReadingPosition(5, 0.500);
      expect(a.isNearlySameAs(const ReadingPosition(5, 0.509)), isTrue);
      expect(a.isNearlySameAs(const ReadingPosition(5, 0.511)), isFalse);
      expect(a.isNearlySameAs(const ReadingPosition(6, 0.500)), isFalse);
    });
  });
}
