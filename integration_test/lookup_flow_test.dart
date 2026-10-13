// Feature 003 on a device or in Chrome, with real pdfrx and the dictionary built into
// the app (T080):
//   flutter test integration_test/lookup_flow_test.dart -d <device>
// Needs assets/dictionary/ from tool/build_dictionary.py (the full build, or --sample
// --as-asset for a quick run: every word used here is in the sample).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:potha/core/dictionary/dictionary_store.dart';
import 'package:potha/core/document/document_format.dart';
import 'package:potha/core/document/pdf/pdf_document_view.dart';
import 'package:potha/core/document/pdf/pdf_view_controller.dart';
import 'package:potha/features/reader/data/reader_repository.dart';
import 'package:potha/features/reader/ui/lookup_panel.dart';
import 'package:potha/main.dart' as app;

import 'helpers.dart';

/// Page 1: words for lookups; page 2: no text (a "scanned" page).
List<TestPage> _book() => [
  const TestPage(
    lines: [
      'The melancholy reader was running late.',
      'Three mice ran better than the dog.',
      'They would not give up in spite of the rain.',
    ],
  ),
  const TestPage(),
];

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  Future<Offset> wordOn(WidgetTester tester, PdfViewController view, String word) async {
    final doc = tester.widget<PdfDocumentView>(find.byType(PdfDocumentView)).document;
    final text = (await tester.runAsync(() => doc.loadPageText(1)))!;
    final i = text.text.indexOf(word);
    expect(i, isNot(-1), reason: '"$word" on page 1');
    return globalOnPage(view, 1, text.charRects[i + 1].center);
  }

  Future<void> longPress(WidgetTester tester, Offset at) async {
    final g = await tester.startGesture(at);
    await settleFor(tester, const Duration(milliseconds: 700));
    await g.up();
    await settleFor(tester, const Duration(milliseconds: 500));
  }

  Future<void> hideControls(WidgetTester tester) async {
    final controls = find.byKey(const ValueKey('reader-controls'));
    if (tester.widget<IgnorePointer>(controls).ignoring) return;
    final size = tester.getSize(find.byType(Scaffold).last);
    await tester.tapAt(Offset(size.width / 2, size.height * 0.85));
    await settleFor(tester, const Duration(milliseconds: 400));
  }

  testWidgets('look up, related words, phrases, tap-to-define, history, no text, zoom', (
    tester,
  ) async {
    await app.main();
    await tester.pumpAndSettle();
    final title = 'Lookup ${DateTime.now().microsecondsSinceEpoch}';
    await importBook(tester, title, buildReaderPdf(_book()));
    final store = containerOf(tester).read(dictionaryStoreProvider)..ensureStarted();
    await tester.runAsync(() => store.ready.timeout(const Duration(minutes: 2)));
    final view = await openBook(tester, title);
    if (find.text('Got it').evaluate().isNotEmpty) {
      await tester.tap(find.text('Got it'));
      await settleFor(tester, const Duration(milliseconds: 400));
    }

    // Long-press -> panel -> a word in the definition -> Back -> system back closes.
    await longPress(tester, await wordOn(tester, view, 'melancholy'));
    expect(find.byKey(lookupPanelKey), findsOneWidget);
    expect(find.text('Noun'), findsWidgets);
    await tester.tapOnText(find.textRange.ofSubstring('sadness').first);
    await settleFor(tester, const Duration(milliseconds: 500));
    expect(find.byTooltip('Back'), findsOneWidget);
    await tester.tap(find.byTooltip('Back'));
    await settleFor(tester, const Duration(milliseconds: 300));
    await systemBack(tester);
    expect(find.byKey(lookupPanelKey), findsNothing);
    expect(find.byType(PdfDocumentView), findsOneWidget, reason: 'still reading');

    // An inflected word shows its base with a note.
    await longPress(tester, await wordOn(tester, view, 'mice'));
    expect(find.textContaining('plural of mouse'), findsOneWidget);
    await systemBack(tester);

    // Long-press "give", drag to "up".
    final g = await tester.startGesture(await wordOn(tester, view, 'give'));
    await settleFor(tester, const Duration(milliseconds: 700));
    await g.moveTo(await wordOn(tester, view, 'up in'));
    await settleFor(tester, const Duration(milliseconds: 200));
    await g.up();
    await settleFor(tester, const Duration(milliseconds: 500));
    expect(find.text('give up'), findsWidgets);
    await systemBack(tester);

    // Tap-to-define: on, tap a word, then off with the chip.
    await tester.runAsync(
      () => containerOf(tester).read(readerRepositoryProvider).setTapToDefine(true),
    );
    await settleFor(tester, const Duration(milliseconds: 400));
    await hideControls(tester);
    await tester.tapAt(await wordOn(tester, view, 'reader'));
    await settleFor(tester, const Duration(milliseconds: 500));
    expect(find.byKey(lookupPanelKey), findsOneWidget);
    await systemBack(tester);
    await tester.tap(find.text('Tap to define'));
    await settleFor(tester, const Duration(milliseconds: 400));
    await tester.tap(find.text('Turn off'));
    await settleFor(tester, const Duration(milliseconds: 600));
    expect(find.text('Tap to define'), findsNothing);

    // History shows the words.
    final size = tester.getSize(find.byType(Scaffold).last);
    await tester.tapAt(Offset(size.width / 2, size.height * 0.85));
    await settleFor(tester, const Duration(milliseconds: 400));
    await tester.tap(find.byTooltip('Lookup history'));
    await settleFor(tester, const Duration(milliseconds: 800));
    for (final word in ['melancholy', 'mice', 'reader']) {
      expect(find.text(word), findsOneWidget, reason: word);
    }
    await systemBack(tester);
    await hideControls(tester);

    // A page without text says so.
    view.goTo(const ReadingPosition(2, 0), animate: false);
    await settleFor(tester, const Duration(milliseconds: 600));
    await longPress(tester, Offset(size.width / 2, size.height / 2));
    expect(find.text('This page has no selectable text'), findsOneWidget);
    await settleFor(tester, const Duration(seconds: 3));

    // Zoomed to 3×, and in continuous mode: the selection sits on the word and the
    // panel doesn't cover it (FR-030).
    for (final continuous in [false, true]) {
      if (continuous) {
        await tester.tapAt(Offset(size.width / 2, size.height * 0.85));
        await settleFor(tester, const Duration(milliseconds: 400));
        await tester.tap(find.byTooltip('Reader settings'));
        await settleFor(tester, const Duration(milliseconds: 600));
        await tester.tap(find.text('Continuous'));
        await settleFor(tester, const Duration(milliseconds: 600));
        await systemBack(tester); // the sheet
        await hideControls(tester);
      }
      view.goTo(const ReadingPosition(1, 0), animate: false);
      await settleFor(tester, const Duration(milliseconds: 600));
      await view.setZoom(3);
      await settleFor(tester, const Duration(milliseconds: 600));
      final at = await wordOn(tester, view, 'melancholy');
      await longPress(tester, at);
      expect(find.byKey(lookupPanelKey), findsOneWidget);
      final panel = tester.getRect(find.byKey(lookupPanelKey));
      expect(panel.contains(at), isFalse, reason: 'the panel covers the word');
      await systemBack(tester);
      await view.setZoom(1);
    }
    await systemBack(tester);
  });
}
