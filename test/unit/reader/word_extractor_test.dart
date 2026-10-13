// From a point on the page to the word to look up (003 research R4, FR-007 to FR-011).
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:potha/core/document/document_format.dart';
import 'package:potha/features/reader/domain/word_extractor.dart';

/// Lines joined with "\r\n" as PDFium gives them; each character 0.02 wide, each line
/// 0.04 high, from (0.1, 0.05). Line breaks get empty rects.
PageText page(List<String> lines) {
  final text = lines.join('\r\n');
  final rects = <Rect>[];
  var line = 0, column = 0;
  for (var i = 0; i < text.length; i++) {
    final c = text[i];
    if (c == '\r' || c == '\n') {
      rects.add(Rect.zero);
      if (c == '\n') {
        line++;
        column = 0;
      }
      continue;
    }
    rects.add(Rect.fromLTWH(0.1 + column * 0.02, 0.05 + line * 0.04, 0.02, 0.03));
    column++;
  }
  return PageText(text, rects);
}

void main() {
  const extractor = WordExtractor();

  /// The query for the word around the first occurrence of [inside] in [text].
  LookupQuery? queryAt(PageText text, String inside, {int offset = 0}) {
    final index = text.text.indexOf(inside);
    expect(index, isNot(-1), reason: '"$inside" not in the page');
    final selection = extractor.wordAt(text, index + offset);
    return selection == null ? null : extractor.queryFor(text, selection);
  }

  group('hit test', () {
    final text = page(['The melancholy reader', 'was running late.']);

    test('finds the character under the point', () {
      final i = text.text.indexOf('melancholy') + 2;
      expect(hitTest(text, text.charRects[i].center), i);
    });

    test('takes the nearest character on the line within half a line height', () {
      final i = text.text.indexOf('late') + 3; // the "e" before "."
      final r = text.charRects[i + 1]; // "."
      expect(hitTest(text, Offset(r.right + 0.01, r.center.dy)), i + 1);
      final m = text.charRects[text.text.indexOf('melancholy')];
      expect(hitTest(text, Offset(m.center.dx, m.top - 0.01)), text.text.indexOf('melancholy'));
    });

    test('white space and gaps give null', () {
      final space = text.text.indexOf(' ');
      expect(hitTest(text, text.charRects[space].center), isNull);
      expect(hitTest(text, const Offset(0.9, 0.9)), isNull);
      expect(hitTest(text, const Offset(0.01, 0.06)), isNull);
    });

    test('a page without text gives null', () {
      expect(hitTest(PageText.empty, const Offset(0.5, 0.5)), isNull);
    });
  });

  group('word rules', () {
    test('selection covers the word as shown, with its rects', () {
      final text = page(['The melancholy reader']);
      final i = text.text.indexOf('melancholy');
      final s = extractor.wordAt(text, i + 4)!;
      expect((s.page, s.start, s.end, s.text), (1, i, i + 10, 'melancholy'));
      expect(s.rects, hasLength(1));
      expect(s.rects.single.left, closeTo(text.charRects[i].left, 1e-9));
      expect(s.rects.single.right, closeTo(text.charRects[i + 9].right, 1e-9));
    });

    test('quotes and punctuation are stripped: “Hello,” -> hello', () {
      final text = page(['“Hello,” said the reader.']);
      final q = queryAt(text, 'Hello')!;
      expect(q.candidates, ['hello']);
      expect(q.display, 'Hello');
      // Pressing on the quote or the comma still finds the word.
      expect(queryAt(text, '“')!.candidates, ['hello']);
      expect(queryAt(text, ',')!.candidates, ['hello']);
    });

    test("possessive 's is removed, both apostrophes: reader's / reader’s -> reader", () {
      expect(queryAt(page(["the reader's friend"]), 'reader')!.candidates, ['reader']);
      expect(queryAt(page(['the reader’s friend']), 'reader')!.candidates, ['reader']);
    });

    test("contractions stay whole: don't / don’t", () {
      expect(queryAt(page(["I don't know"]), 'don')!.candidates, ["don't"]);
      expect(queryAt(page(['I don’t know']), 'don')!.candidates, ["don't"]);
    });

    test('PDFium line-break hyphen (U+0002): exam|ple -> [example, exam-ple]', () {
      final text = page(['He gave an exam\u0002ple of it.']);
      final q = queryAt(text, 'exam')!;
      expect(q.candidates, ['example', 'exam-ple']);
      expect(q.parts, ['exam', 'ple']);
      expect(q.display, 'example');
      // From the second half too.
      expect(queryAt(text, 'ple of')!.candidates, ['example', 'exam-ple']);
    });

    test('PDFium line-break hyphen: well|known -> [wellknown, well-known]', () {
      final q = queryAt(page(['a well\u0002known word']), 'well')!;
      expect(q.candidates, ['wellknown', 'well-known']);
    });

    test('hyphen at a line end, then a line break: exam-/ple -> [example, exam-ple]', () {
      final text = page(['He gave an exam-', 'ple of it.']);
      final q = queryAt(text, 'exam')!;
      expect(q.candidates, ['example', 'exam-ple']);
      final s = extractor.wordAt(text, text.text.indexOf('ple'))!;
      expect(s.text, 'exam-ple');
      expect(s.rects, hasLength(2), reason: 'one rect per line');
    });

    test('an inline hyphenated word: well-known -> [well-known], parts [well, known]', () {
      final q = queryAt(page(['a well-known fact']), 'known')!;
      expect(q.candidates, ['well-known']);
      expect(q.parts, ['well', 'known']);
    });

    test('a soft hyphen is always joined', () {
      final q = queryAt(page(['an exam­ple here']), 'exam')!;
      expect(q.candidates, ['example']);
    });

    test('numbers, URLs, domains and emails are not words (FR-011)', () {
      final text = page([
        'Call 2026 or 3.14 or visit https://x.org or',
        'www.x.org or potha.app or write a@b.org now',
      ]);
      for (final s in ['2026', '3.14', 'https', 'x.org', 'www', 'potha', 'a@b']) {
        expect(queryAt(text, s), isNull, reason: s);
      }
      expect(queryAt(text, 'visit')!.candidates, ['visit']);
      expect(queryAt(text, 'now')!.candidates, ['now']);
    });

    test('a token with digits and letters is a word', () {
      expect(queryAt(page(['play the 1990s hits']), '1990s')!.candidates, ['1990s']);
    });

    test('text with U+FFFD, private-use or control characters is garbled (FR-029)', () {
      for (final bad in ['caf\uFFFD', '\uE000\uE001x', '\u0001\u0002\u0003\u0001']) {
        final q = queryAt(page(['before $bad after']), bad.substring(0, 1))!;
        expect(q.garbled, isTrue, reason: bad);
        expect(q.candidates, isEmpty);
        expect(q.display, bad);
      }
    });

    test('a capitalised word mid-sentence is marked; at a sentence start it is not', () {
      final text = page(['They went to Turkey. Turkey is far, said "Hello" Anna']);
      expect(queryAt(text, 'Turkey')!.capitalisedMidSentence, isTrue);
      expect(queryAt(text, 'Turkey is')!.capitalisedMidSentence, isFalse);
      expect(queryAt(text, 'They')!.capitalisedMidSentence, isFalse);
      expect(queryAt(text, 'Anna')!.capitalisedMidSentence, isTrue);
      expect(queryAt(text, 'went')!.capitalisedMidSentence, isFalse);
    });

    test('a word at a line start after a sentence end is a sentence start', () {
      final text = page(['It was late.', 'Turkey was far.']);
      expect(queryAt(text, 'Turkey')!.capitalisedMidSentence, isFalse);
    });

    test('a single word is not a phrase', () {
      expect(queryAt(page(['give up now']), 'give')!.isPhrase, isFalse);
    });
  });
}
