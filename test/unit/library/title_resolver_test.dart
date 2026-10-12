import 'package:flutter_test/flutter_test.dart';
import 'package:potha/features/library/domain/title_resolver.dart';

void main() {
  final added = DateTime(2026, 10, 12);
  String fmt(DateTime d) => '12 Oct 2026';
  String resolve(String? meta, String file) =>
      resolveTitle(metadataTitle: meta, fileName: file, addedAt: added, formatDate: fmt);

  test('metadata title wins', () {
    expect(resolve('The Idiot', 'scan_0001.pdf'), 'The Idiot');
  });

  test('metadata title is trimmed', () {
    expect(resolve('  The Idiot \n', 'x.pdf'), 'The Idiot');
  });

  test('blank metadata title falls back to the file name', () {
    expect(resolve('   ', 'my_great_book.pdf'), 'my great book');
    expect(resolve(null, 'my_great_book.pdf'), 'my great book');
  });

  test('file name is tidied', () {
    expect(resolve(null, 'scan_0001.pdf'), 'scan 0001');
    expect(resolve(null, 'download (3).PDF'), 'download (3)');
    expect(resolve(null, 'a__b   c.pdf'), 'a b c');
    expect(resolve(null, 'no_extension'), 'no extension');
  });

  test('a name with no letters becomes "Untitled book <date>"', () {
    expect(resolve(null, '0001.pdf'), 'Untitled book 12 Oct 2026');
    expect(resolve(null, '___.pdf'), 'Untitled book 12 Oct 2026');
    expect(resolve('', '.pdf'), 'Untitled book 12 Oct 2026');
  });

  test('non-Latin letters count as letters', () {
    expect(resolve(null, 'Преступление.pdf'), 'Преступление');
  });
}
