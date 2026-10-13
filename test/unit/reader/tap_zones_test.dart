import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:potha/core/document/document_format.dart';
import 'package:potha/features/reader/domain/tap_zones.dart';

void main() {
  const width = 400.0;

  TapAction at(double x, {PagePoint? point, List<DocumentLink> links = const []}) =>
      classifyTap(x: x, viewWidth: width, pagePoint: point, linksOnPage: links);

  test('outer fifth on the left goes back, on the right forward (FR-007)', () {
    expect(at(0), const PreviousPage());
    expect(at(79.9), const PreviousPage());
    expect(at(320.1), const NextPage());
    expect(at(400), const NextPage());
  });

  test('the middle toggles the controls (FR-002), including the 20% and 80% lines', () {
    expect(at(80), const ToggleControls());
    expect(at(200), const ToggleControls());
    expect(at(320), const ToggleControls());
  });

  test('works for any view width', () {
    expect(classifyTap(x: 150, viewWidth: 1000), const PreviousPage());
    expect(classifyTap(x: 850, viewWidth: 1000), const NextPage());
    expect(classifyTap(x: 500, viewWidth: 1000), const ToggleControls());
  });

  test('a link under the finger wins over the zones (FR-025)', () {
    const toPage = PageLink(Rect.fromLTRB(0.0, 0.1, 0.3, 0.2), 9);
    final toWeb = WebLink(const Rect.fromLTRB(0.5, 0.5, 0.9, 0.6), Uri.parse('https://example.org'));
    final links = [toPage, toWeb];
    expect(at(10, point: const PagePoint(3, Offset(0.1, 0.15)), links: links),
        const FollowLink(toPage));
    expect(at(200, point: const PagePoint(3, Offset(0.6, 0.55)), links: links),
        FollowLink(toWeb));
    // Outside every link: the zones apply.
    expect(at(10, point: const PagePoint(3, Offset(0.1, 0.5)), links: links),
        const PreviousPage());
  });

  test('a tap between pages ignores links', () {
    const link = PageLink(Rect.fromLTRB(0, 0, 1, 1), 2);
    expect(at(200, links: const [link]), const ToggleControls());
  });
}
