// Inflected words show their base with a note (003 US2, FR-012).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:potha/core/dictionary/lexicon.dart';
import 'package:potha/features/reader/ui/lookup_panel.dart';

import 'reader_test_app.dart';

const text = 'Three mice were building a nest.';

void main() {
  // Made inside each test: its futures must belong to the test's fake-async zone.
  FakeDictionaryStore store() => FakeDictionaryStore(
    FakeLexicon(
      entryMap: {
        'mouse': [
          entry('mouse', 'noun', ['A small rodent.']),
        ],
        'building': [
          entry('building', 'noun', ['A structure with walls.']),
        ],
        'build': [
          entry('build', 'verb', ['To make something.']),
        ],
      },
      formMap: {
        'mice': [const WordFormLink('mice', 'mouse', FormRelation.plural)],
        'building': [const WordFormLink('building', 'build', FormRelation.presentParticiple)],
      },
    ),
  );

  Offset at(WidgetTester tester, String word) {
    final rect = tester.getRect(find.byKey(fakeViewKey));
    final c = charCentre('$text\r\n', text.indexOf(word) + 1);
    return Offset(rect.left + c.dx * rect.width, rect.top + c.dy * rect.height);
  }

  testWidgets('"mice" shows mouse under "mice – plural of mouse"; "building" the noun, '
      'then build', (tester) async {
    // A tall screen, so the panel's first third holds both entries.
    tester.view.physicalSize = const Size(800, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final doc = FakeReaderDocument(pageCount: 2, texts: {1: '$text\r\n'});
    final (app, _) = await openReader(tester, doc, store: store());
    await dismissHint(tester);

    await tester.longPressAt(at(tester, 'mice'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byKey(lookupPanelKey), findsOneWidget);
    expect(find.text('mice – plural of mouse'), findsOneWidget);
    expect(find.text('mouse'), findsOneWidget);
    expect(find.textContaining('A small rodent.'), findsOneWidget);

    await tester.longPressAt(at(tester, 'building'));
    await tester.pump(const Duration(milliseconds: 300));
    final noun = tester.getTopLeft(find.textContaining('A structure with walls.'));
    final verb = tester.getTopLeft(find.textContaining('To make something.'));
    expect(noun.dy, lessThan(verb.dy));
    expect(find.text('building – present participle of build'), findsOneWidget);
    expect(find.text('build · Verb'), findsOneWidget);
    await closeReader(tester, app);
  });
}
