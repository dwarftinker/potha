import 'package:flutter_test/flutter_test.dart';
import 'package:potha/core/document/document_format.dart';
import 'package:potha/features/reader/domain/outline.dart';

void main() {
  const outline = [
    OutlineEntry(title: 'Preface', page: 3),
    OutlineEntry(title: 'One', page: 10, children: [
      OutlineEntry(title: '1.1', page: 12),
      OutlineEntry(title: 'Broken', page: null),
      OutlineEntry(title: '1.2', page: 20),
    ]),
    OutlineEntry(title: 'Two', page: 40),
  ];

  String? at(int page) => currentChapter(outline, page)?.title;

  test('the deepest entry at or before the page (FR-024)', () {
    expect(at(3), 'Preface');
    expect(at(9), 'Preface');
    expect(at(10), 'One');
    expect(at(15), '1.1');
    expect(at(25), '1.2');
    expect(at(40), 'Two');
    expect(at(500), 'Two');
  });

  test('nothing before the first entry; entries without a page are skipped', () {
    expect(at(1), isNull);
    expect(currentChapter(const [OutlineEntry(title: 'x')], 5), isNull);
  });
}
