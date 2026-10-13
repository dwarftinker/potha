// Where the lookup panel opens, so it never covers the word (003 FR-003, research R7).
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:potha/features/reader/domain/panel_placement.dart';

void main() {
  const view = Size(400, 900);

  Rect word(double top) => Rect.fromLTWH(100, top, 80, 20);

  test('a word in the top two thirds: bottom panel, at most a third of the view', () {
    final p = panelPlacement(view: view, word: word(200));
    expect(p.edge, PanelEdge.bottom);
    expect(p.height, lessThanOrEqualTo(300));
    expect(p.height, greaterThan(200));
  });

  test('a word the bottom panel would cover: top panel', () {
    for (final top in [620.0, 700.0, 860.0]) {
      final p = panelPlacement(view: view, word: word(top));
      expect(p.edge, PanelEdge.top, reason: 'word at $top');
      expect(p.height, lessThanOrEqualTo(300));
      expect(top, greaterThanOrEqualTo(p.height), reason: 'the top panel must not cover it');
    }
  });

  test('just above the bottom panel stays at the bottom', () {
    final p = panelPlacement(view: view, word: word(560));
    expect(p.edge, PanelEdge.bottom);
    expect(560 + 20, lessThanOrEqualTo(view.height - p.height));
  });

  test('covered either way: the panel goes to the edge farther from the word', () {
    expect(
      panelPlacement(view: view, word: const Rect.fromLTRB(0, 200, 400, 650)).edge,
      PanelEdge.bottom,
    ); // centre 425 is above the middle (450): bottom is farther
    expect(
      panelPlacement(view: view, word: const Rect.fromLTRB(0, 280, 400, 720)).edge,
      PanelEdge.top,
    ); // centre 500 is below the middle: top is farther
  });

  test('the first height is never over a third, also in a short landscape view', () {
    for (final size in [const Size(400, 900), const Size(900, 400), const Size(1280, 720)]) {
      for (final top in [10.0, size.height / 2, size.height - 30]) {
        final p = panelPlacement(view: size, word: Rect.fromLTWH(10, top, 50, 20));
        expect(p.height, lessThanOrEqualTo(size.height / 3 + 0.001));
      }
    }
  });
}
