// Tap-to-define (003 US4, FR-015 to FR-017): off by default; when on, a tap on a word
// looks it up at once, edges still turn pages, and a chip says the mode is on.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:potha/core/document/document_format.dart';
import 'package:potha/features/reader/ui/lookup_panel.dart';

import 'reader_test_app.dart';
import 'test_app.dart';

/// A word in the middle of the line, and one near the right edge.
const text = 'so the melancholy one read on to the line';

/// Below the chip in the top corner.
final pageText = '${'\r\n' * 6}$text\r\n';

void main() {
  FakeDictionaryStore store() => FakeDictionaryStore(
    FakeLexicon(
      entryMap: {
        'melancholy': [
          entry('melancholy', 'noun', ['Great sadness.']),
        ],
        'line': [
          entry('line', 'noun', ['A long mark.']),
        ],
      },
    ),
  );

  Offset at(WidgetTester tester, String word) {
    final rect = tester.getRect(find.byKey(fakeViewKey));
    final c = charCentre(pageText, pageText.indexOf(word) + 1);
    return Offset(rect.left + c.dx * rect.width, rect.top + c.dy * rect.height);
  }

  bool controlsShown(WidgetTester tester) =>
      !tester.widget<IgnorePointer>(find.byKey(const ValueKey('reader-controls'))).ignoring;

  Future<(TestApp, FakeViewFactory)> open(WidgetTester tester) async {
    final doc = FakeReaderDocument(pageCount: 5, texts: {1: pageText, 2: pageText});
    final (app, view) = await openReader(tester, doc, store: store());
    await dismissHint(tester);
    return (app, view);
  }

  Future<void> turnOn(WidgetTester tester) async {
    await tapView(tester, 0.5);
    await tester.tap(find.byTooltip('Reader settings'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Tap to define'));
    await tester.tap(find.text('Tap to define'));
    await tester.pump();
    await settleReal(tester);
    Navigator.of(tester.element(find.text('Theme'))).pop();
    await tester.pumpAndSettle();
    await tapView(tester, 0.5); // hide the controls again
    await tester.pump(const Duration(milliseconds: 300));
  }

  testWidgets('off by default: a tap on a word toggles the controls', (tester) async {
    final (app, _) = await open(tester);
    expect(find.text('Tap to define'), findsNothing, reason: 'no chip');
    await tester.tapAt(at(tester, 'melancholy'));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byKey(lookupPanelKey), findsNothing);
    expect(controlsShown(tester), isTrue);
    await closeReader(tester, app);
  });

  testWidgets('on: a tap on a word looks it up at once; edges turn pages; empty space '
      'toggles the controls', (tester) async {
    final (app, view) = await open(tester);
    await turnOn(tester);
    expect(controlsShown(tester), isFalse);

    await tester.tapAt(at(tester, 'melancholy'));
    // No double-tap wait: a frame later the panel is open.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 16));
    expect(find.byKey(lookupPanelKey), findsOneWidget);
    expect(find.textContaining('Great sadness.'), findsOneWidget);
    expect(controlsShown(tester), isFalse);
    await tester.tapAt(const Offset(400, 300)); // outside: closes
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byKey(lookupPanelKey), findsNothing);

    // "line" sits in the right edge zone: the page turns, no lookup.
    final edgeWord = at(tester, 'line');
    expect(edgeWord.dx, greaterThan(tester.getSize(find.byKey(fakeViewKey)).width * 0.8));
    await tester.tapAt(edgeWord);
    await tester.pump(const Duration(milliseconds: 300));
    expect(view.controller.calls.last, 'next');
    expect(find.byKey(lookupPanelKey), findsNothing);

    // Empty space in the middle toggles the controls.
    await tester.tapAt(const Offset(400, 300));
    await tester.pump(const Duration(milliseconds: 100));
    expect(controlsShown(tester), isTrue);
    await closeReader(tester, app);
  });

  testWidgets('the chip shows with the controls hidden; tapping it asks, Turn off turns '
      'it off', (tester) async {
    final (app, _) = await open(tester);
    await turnOn(tester);
    expect(find.text('Tap to define'), findsOneWidget);
    await tester.tap(find.text('Tap to define'));
    await tester.pumpAndSettle();
    expect(find.text('Turn off tap to define?'), findsOneWidget);
    await tester.tap(find.text('Turn off'));
    await tester.pump();
    await settleReal(tester);
    await tester.pumpAndSettle();
    expect(find.text('Tap to define'), findsNothing);
    final prefs = await tester.runAsync(() => app.db.select(app.db.readerPreferences).getSingle());
    expect(prefs!.tapToDefine, isFalse);
    await closeReader(tester, app);
  });

  testWidgets('the setting is kept when the reader opens again', (tester) async {
    final (app, view) = await open(tester);
    await turnOn(tester);
    await leaveReader(tester);
    final navigator = tester.state<NavigatorState>(find.byType(Navigator));
    navigator.push(MaterialPageRoute<void>(builder: (_) => readerScreenFor('b1')));
    await settleReal(tester);
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('Tap to define'), findsOneWidget);
    view.controller.emitPosition(const ReadingPosition(1, 0));
    await tester.pump();
    await tester.tapAt(at(tester, 'melancholy'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 16));
    expect(find.byKey(lookupPanelKey), findsOneWidget);
    await closeReader(tester, app);
  });
}
