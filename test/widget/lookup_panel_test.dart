// Look up a word by selecting it (003 US1; contracts/lookup-ui.md). Fakes throughout.
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:potha/core/document/document_format.dart';
import 'package:potha/features/reader/ui/lookup_panel.dart';

import 'reader_test_app.dart';
import 'test_app.dart';

const page1 = 'The melancholy reader was running late.\r\nThree mice ran better than the dog.';

/// Lines down to the bottom third, ending with "serendipity".
final page2 = [
  for (var i = 0; i < 20; i++) 'line $i of filler text',
  'the serendipity',
].join('\r\n');

FakeDictionaryStore dictionary() => FakeDictionaryStore(
  FakeLexicon(
    entryMap: {
      'melancholy': [
        entry(
          'melancholy',
          'noun',
          ['Great sadness.', 'Black bile.'],
          ipa: '/ˈmɛlənkəli/',
          examples: ['A deep melancholy.'],
        ),
        entry('melancholy', 'adj', ['Affected with great sadness.']),
      ],
      'serendipity': [
        entry('serendipity', 'noun', ['A happy accident.']),
      ],
      'reader': [
        entry('reader', 'noun', ['One who reads.']),
      ],
    },
  ),
);

/// Global position of the [n]th character of [word] in [text] on the fake view.
Offset wordAt(WidgetTester tester, String text, String word, {int n = 1}) {
  final rect = tester.getRect(find.byKey(fakeViewKey));
  final c = charCentre(text, text.indexOf(word) + n);
  return Offset(rect.left + c.dx * rect.width, rect.top + c.dy * rect.height);
}

Future<void> longPress(WidgetTester tester, Offset at) async {
  await tester.longPressAt(at);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
}

void main() {
  late FakeReaderDocument doc;

  setUp(() => doc = FakeReaderDocument(pageCount: 5, texts: {1: page1, 2: page2}));

  Future<(TestApp, FakeViewFactory)> open(WidgetTester tester) async {
    final (app, view) = await openReader(tester, doc, store: dictionary());
    await dismissHint(tester);
    return (app, view);
  }

  testWidgets('long-press a word: selection highlight and the panel with its entry (FR-005)', (
    tester,
  ) async {
    final (app, view) = await open(tester);
    await longPress(tester, wordAt(tester, page1, 'melancholy'));

    final highlights = view.controller.config!.highlights;
    final selection = highlights.where((h) => h.kind == HighlightKind.selection).single;
    expect(selection.page, 1);
    expect(selection.rects, isNotEmpty);

    expect(find.byKey(lookupPanelKey), findsOneWidget);
    expect(find.text('melancholy'), findsWidgets);
    expect(find.text('/ˈmɛlənkəli/'), findsOneWidget);
    expect(find.text('Noun'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Adjective'),
      60,
      scrollable: find.descendant(of: find.byKey(lookupPanelKey), matching: find.byType(Scrollable)),
    );
    expect(find.text('Adjective'), findsOneWidget);
    expect(find.textContaining('1. Great sadness.'), findsOneWidget);
    expect(find.textContaining('2. Black bile.'), findsOneWidget);
    expect(find.text('A deep melancholy.'), findsOneWidget);
    expect(find.textContaining('Wiktionary · CC BY-SA 4.0'), findsOneWidget);
    // The view was locked from the long-press until the lift.
    expect(view.controller.calls, containsAllInOrder(['locked(true)', 'locked(false)']));
    await closeReader(tester, app);
  });

  Future<void> expectClosed(WidgetTester tester, FakeViewFactory view) async {
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byKey(lookupPanelKey), findsNothing);
    expect(
      view.controller.config!.highlights.where((h) => h.kind == HighlightKind.selection),
      isEmpty,
    );
  }

  testWidgets('a tap outside closes it, and does not toggle the controls', (tester) async {
    final (app, view) = await open(tester);
    await longPress(tester, wordAt(tester, page1, 'melancholy'));
    final rect = tester.getRect(find.byKey(fakeViewKey));
    await tester.tapAt(Offset(rect.center.dx, rect.top + 300));
    await tester.pump();
    await expectClosed(tester, view);
    expect(find.byKey(const ValueKey('reader-controls')), findsOneWidget);
    expect(
      tester.widget<IgnorePointer>(find.byKey(const ValueKey('reader-controls'))).ignoring,
      isTrue,
      reason: 'the controls stay hidden',
    );
    await closeReader(tester, app);
  });

  testWidgets('a swipe down closes it', (tester) async {
    final (app, view) = await open(tester);
    await longPress(tester, wordAt(tester, page1, 'melancholy'));
    await tester.drag(find.byKey(lookupPanelHandleKey), const Offset(0, 200));
    await tester.pump();
    await expectClosed(tester, view);
    await closeReader(tester, app);
  });

  testWidgets('Esc closes it first, without leaving the reader', (tester) async {
    final (app, view) = await open(tester);
    await longPress(tester, wordAt(tester, page1, 'melancholy'));
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump();
    await expectClosed(tester, view);
    expect(find.byKey(fakeViewKey), findsOneWidget);
    await closeReader(tester, app);
  });

  testWidgets('system back closes it first, without leaving the reader', (tester) async {
    final (app, view) = await open(tester);
    await longPress(tester, wordAt(tester, page1, 'melancholy'));
    await tester.binding.handlePopRoute();
    await tester.pump();
    await expectClosed(tester, view);
    expect(find.byKey(fakeViewKey), findsOneWidget);
    await closeReader(tester, app);
  });

  testWidgets('a page turn closes it', (tester) async {
    final (app, view) = await open(tester);
    await longPress(tester, wordAt(tester, page1, 'melancholy'));
    view.controller.emitPosition(const ReadingPosition(2, 0));
    await tester.pump();
    await expectClosed(tester, view);
    await closeReader(tester, app);
  });

  testWidgets('a word in the bottom third opens the panel at the top (FR-003)', (tester) async {
    final (app, view) = await open(tester);
    await longPress(tester, wordAt(tester, page1, 'melancholy'));
    final screen = tester.getSize(find.byType(Scaffold).last);
    expect(tester.getRect(find.byKey(lookupPanelKey)).bottom, closeTo(screen.height, 1));
    await tester.tapAt(const Offset(10, 400));
    await tester.pump(const Duration(milliseconds: 400));

    view.controller.emitPosition(const ReadingPosition(2, 0));
    await tester.pump();
    final word = wordAt(tester, page2, 'serendipity');
    expect(word.dy, greaterThan(screen.height * 2 / 3));
    await longPress(tester, word);
    final panel = tester.getRect(find.byKey(lookupPanelKey));
    expect(panel.top, closeTo(0, 1));
    expect(panel.bottom, lessThan(word.dy));
    expect(panel.height, lessThanOrEqualTo(screen.height / 3 + 1));
    await closeReader(tester, app);
  });

  testWidgets('a mouse double-click looks up and leaves the controls as they were', (tester) async {
    final (app, _) = await open(tester);
    final at = wordAt(tester, page1, 'reader');
    for (var i = 0; i < 2; i++) {
      final g = await tester.startGesture(at, kind: PointerDeviceKind.mouse);
      await g.up();
      await tester.pump(const Duration(milliseconds: 50));
    }
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byKey(lookupPanelKey), findsOneWidget);
    expect(find.textContaining('One who reads.'), findsOneWidget);
    expect(
      tester.widget<IgnorePointer>(find.byKey(const ValueKey('reader-controls'))).ignoring,
      isTrue,
    );
    await closeReader(tester, app);
  });

  testWidgets('a long-press on a page without text says so', (tester) async {
    final (app, view) = await open(tester);
    view.controller.emitPosition(const ReadingPosition(3, 0));
    await tester.pump();
    final rect = tester.getRect(find.byKey(fakeViewKey));
    await longPress(tester, rect.center);
    expect(find.text('This page has no selectable text'), findsOneWidget);
    expect(find.byKey(lookupPanelKey), findsNothing);
    await tester.pump(const Duration(seconds: 4));
    await closeReader(tester, app);
  });

  testWidgets('a word without an entry: "No definition found"', (tester) async {
    final (app, _) = await open(tester);
    await longPress(tester, wordAt(tester, page1, 'running'));
    expect(find.text('No definition found for “running”'), findsOneWidget);
    await closeReader(tester, app);
  });

  testWidgets('the footer opens "About this dictionary" (FR-034)', (tester) async {
    final (app, _) = await open(tester);
    await longPress(tester, wordAt(tester, page1, 'melancholy'));
    await tester.tap(find.byTooltip('About this dictionary'));
    await tester.pumpAndSettle();
    expect(find.text('About this dictionary'), findsOneWidget);
    expect(find.textContaining('English Wiktionary'), findsOneWidget);
    expect(find.textContaining('CC BY-SA 4.0'), findsWidgets);
    expect(find.textContaining('2026-09-02'), findsOneWidget);
    await tester.tap(find.text('Close'));
    await tester.pumpAndSettle();
    await closeReader(tester, app);
  });

  testWidgets('the dictionary is started when a book opens (FR-022)', (tester) async {
    final store = dictionary();
    final (app, _) = await openReader(tester, doc, store: store);
    expect(store.startCalls, greaterThan(0));
    await closeReader(tester, app);
  });

  testWidgets('the visible pages\' text is loaded once the view is still (research R4)',
      (tester) async {
    final (app, view) = await open(tester);
    expect(doc.textRequests, containsAll([1, 2]));
    doc.textRequests.clear();
    // Moving quickly: nothing is loaded until the view has been still for 300 ms.
    view.controller.emitPosition(const ReadingPosition(3, 0));
    await tester.pump(const Duration(milliseconds: 100));
    view.controller.emitPosition(const ReadingPosition(4, 0));
    await tester.pump(const Duration(milliseconds: 100));
    expect(doc.textRequests, isEmpty);
    await tester.pump(const Duration(milliseconds: 300));
    expect(doc.textRequests, [4, 5]);
    await closeReader(tester, app);
  });
}
