
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:potha/core/db/app_database.dart';
import 'package:potha/features/reader/domain/reader_theme.dart';

void main() {
  Matcher near(Color expected, {int tolerance = 2}) => predicate<Color>((c) {
        int ch(double v) => (v * 255).round();
        return (ch(c.r) - ch(expected.r)).abs() <= tolerance &&
            (ch(c.g) - ch(expected.g)).abs() <= tolerance &&
            (ch(c.b) - ch(expected.b)).abs() <= tolerance;
      }, 'within $tolerance of $expected');

  final light = ReaderTheme.of(ReadingTheme.light);
  final sepia = ReaderTheme.of(ReadingTheme.sepia);
  final dark = ReaderTheme.of(ReadingTheme.dark);

  test('light leaves pages alone', () {
    expect(light.pageFilter, isNull);
    expect(light.apply(const Color(0xFF123456)), const Color(0xFF123456));
  });

  test('sepia maps white to the paper tone and black to the ink tone', () {
    expect(sepia.apply(const Color(0xFFFFFFFF)), near(const Color(0xFFF4ECD8)));
    expect(sepia.apply(const Color(0xFF000000)), near(const Color(0xFF5B4636)));
  });

  test('dark maps white to the dark background and black to light text', () {
    expect(dark.apply(const Color(0xFFFFFFFF)), near(const Color(0xFF1E1E1E)));
    expect(dark.apply(const Color(0xFF000000)), near(const Color(0xFFE0E0E0)));
  });

  test('photos keep their hues in dark and sepia (FR-028)', () {
    for (final theme in [dark, sepia]) {
      for (final c in const [
        Color(0xFFFF0000),
        Color(0xFF00FF00),
        Color(0xFF0000FF),
        Color(0xFFFF8000),
        Color(0xFF66B3FF),
      ]) {
        final before = HSVColor.fromColor(c).hue;
        final after = HSVColor.fromColor(theme.apply(c)).hue;
        final diff = ((before - after + 540) % 360 - 180).abs();
        expect(diff, lessThan(15), reason: '${theme.name} $c -> ${theme.apply(c)}');
      }
    }
  });

  test('highlights come out in the intended colour after the page filter', () {
    for (final theme in [light, sepia, dark]) {
      for (final (paint, intended) in [
        (theme.highlightPaintColor, theme.highlight),
        (theme.activeHighlightPaintColor, theme.activeHighlight),
      ]) {
        expect(theme.apply(paint.withValues(alpha: 1)),
            near(intended.withValues(alpha: 1), tolerance: 10),
            reason: theme.name.name);
        expect(paint.a, closeTo(intended.a, 0.01));
      }
    }
  });

  test('control colours meet WCAG AA contrast (FR-040)', () {
    double luminance(Color c) => c.computeLuminance();
    double contrast(Color a, Color b) {
      final l1 = luminance(a), l2 = luminance(b);
      return (l1 > l2 ? l1 + 0.05 : l2 + 0.05) / (l1 > l2 ? l2 + 0.05 : l1 + 0.05);
    }

    for (final theme in [light, sepia, dark]) {
      expect(contrast(theme.barForeground, theme.barBackground), greaterThanOrEqualTo(4.5),
          reason: theme.name.name);
    }
  });
}
