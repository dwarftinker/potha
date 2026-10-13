// Lookup history (003 US8, FR-025 to FR-027).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:potha/core/db/app_database.dart';
import 'package:potha/core/dictionary/lexicon.dart';
import 'package:potha/features/reader/data/history_repository.dart';
import 'package:potha/features/reader/ui/lookup_panel.dart';

import 'reader_test_app.dart';
import 'test_app.dart';

const text = 'The melancholy reader.';

void main() {
  FakeDictionaryStore store({bool ready = true}) => FakeDictionaryStore(
    FakeLexicon(
      entryMap: {
        'melancholy': [
          entry('melancholy', 'noun', ['Great sadness.']),
        ],
        'reader': [
          entry('reader', 'noun', ['One who reads.']),
        ],
      },
    ),
    ready: ready,
  );

  Future<void> longPress(WidgetTester tester, String word) async {
    final rect = tester.getRect(find.byKey(fakeViewKey));
    final c = charCentre('$text\r\n', text.indexOf(word) + 1);
    await tester.longPressAt(Offset(rect.left + c.dx * rect.width, rect.top + c.dy * rect.height));
    await tester.pump(const Duration(milliseconds: 300));
    await settleReal(tester);
  }

  Future<void> closePanel(WidgetTester tester) async {
    await tester.tapAt(const Offset(400, 300));
    await tester.pump(const Duration(milliseconds: 300));
  }

  Future<void> openHistory(WidgetTester tester) async {
    await tapView(tester, 0.5);
    await tester.tap(find.byTooltip('Lookup history'));
    await tester.pumpAndSettle();
    await settleReal(tester);
  }

  Future<List<HistoryLine>> lines(WidgetTester tester, TestApp app) async =>
      (await tester.runAsync(() => HistoryRepository(app.db).watchAll().first))!;

  testWidgets('one line per word with page and count; All books has titles; a row opens '
      'its definition', (tester) async {
    final doc = FakeReaderDocument(pageCount: 3, texts: {1: '$text\r\n'});
    final (app, _) = await openReader(
      tester,
      doc,
      store: store(),
      before: (app) async {
        await seedBook(tester, app.db, id: 'b2', title: 'Emma');
        await tester.runAsync(
          () => HistoryRepository(app.db).record(
            bookId: 'b2',
            wordKey: 'whale',
            word: 'whale',
            headword: 'whale',
            source: LookupSource.offline,
            page: 12,
          ),
        );
      },
    );
    await dismissHint(tester);
    await longPress(tester, 'melancholy');
    await closePanel(tester);
    await longPress(tester, 'melancholy');
    await closePanel(tester);
    await longPress(tester, 'reader');
    await closePanel(tester);

    await openHistory(tester);
    expect(find.text('melancholy'), findsOneWidget);
    expect(find.text('×2'), findsOneWidget);
    expect(find.textContaining('Page 1 ·'), findsNWidgets(2));
    expect(find.text('reader'), findsOneWidget);
    expect(find.text('whale'), findsNothing);

    await tester.tap(find.text('All books'));
    await tester.pumpAndSettle();
    await settleReal(tester);
    expect(find.text('whale'), findsOneWidget);
    expect(find.textContaining('Emma'), findsOneWidget);
    expect(find.textContaining('Moby-Dick · Page'), findsNWidgets(2));

    await tester.tap(find.text('This book'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('reader'));
    await tester.pumpAndSettle();
    expect(find.byKey(lookupPanelKey), findsOneWidget);
    expect(find.textContaining('One who reads.'), findsOneWidget);
    // Reopening from history doesn't count as a new lookup.
    expect((await lines(tester, app)).where((l) => l.word == 'reader').single.count, 1);
    await closeReader(tester, app);
  });

  testWidgets('Clear asks first and empties the chosen scope; the empty state says what '
      'will appear', (tester) async {
    final doc = FakeReaderDocument(pageCount: 3, texts: {1: '$text\r\n'});
    final (app, _) = await openReader(tester, doc, store: store());
    await dismissHint(tester);
    await openHistory(tester);
    expect(find.text('Words you look up will appear here.'), findsOneWidget);
    Navigator.of(tester.element(find.text('This book'))).pop();
    await tester.pumpAndSettle();
    await tapView(tester, 0.5); // hide the controls again
    await tester.pump(const Duration(milliseconds: 300));

    await longPress(tester, 'melancholy');
    await closePanel(tester);
    await openHistory(tester);
    expect(find.text('melancholy'), findsOneWidget);
    await tester.tap(find.text('Clear'));
    await tester.pumpAndSettle();
    expect(find.text('Clear lookup history for this book?'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(find.text('melancholy'), findsOneWidget);
    await tester.tap(find.text('Clear'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Clear'));
    await tester.pump();
    await settleReal(tester);
    await tester.pumpAndSettle();
    expect(find.text('Words you look up will appear here.'), findsOneWidget);
    expect(await lines(tester, app), isEmpty);
    await closeReader(tester, app);
  });

  testWidgets('a lookup is recorded only once the panel shows its result', (tester) async {
    final dictionary = store(ready: false);
    final doc = FakeReaderDocument(pageCount: 3, texts: {1: '$text\r\n'});
    final (app, _) = await openReader(tester, doc, store: dictionary);
    await dismissHint(tester);
    dictionary.setStatus(const DictionaryUnpacking());
    await longPress(tester, 'melancholy');
    expect(find.text('Preparing the dictionary…'), findsOneWidget);
    expect(await lines(tester, app), isEmpty);
    dictionary.markReady();
    await tester.pump(const Duration(milliseconds: 100));
    await settleReal(tester);
    expect((await lines(tester, app)).single.headword, 'melancholy');
    await closeReader(tester, app);
  });
}
