// Not found, and searching online (003 US6, FR-020, FR-021).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:potha/core/dictionary/lexicon.dart';
import 'package:potha/features/reader/ui/lookup_panel.dart';

import 'reader_test_app.dart';
import 'test_app.dart';

const text = 'A serendipity of words.';

void main() {
  Future<(TestApp, FakeNetworkStatus)> open(
    WidgetTester tester,
    FakeOnlineDictionary online, {
    bool isOnline = true,
  }) async {
    // A tall screen: the panel's first third holds the whole not-found view.
    tester.view.physicalSize = const Size(800, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final network = FakeNetworkStatus(online: isOnline);
    final doc = FakeReaderDocument(pageCount: 2, texts: {1: '$text\r\n'});
    final (app, _) = await openReader(
      tester,
      doc,
      store: FakeDictionaryStore(FakeLexicon()),
      network: network,
      online: online,
    );
    await dismissHint(tester);
    final rect = tester.getRect(find.byKey(fakeViewKey));
    final c = charCentre('$text\r\n', text.indexOf('serendipity') + 1);
    await tester.longPressAt(Offset(rect.left + c.dx * rect.width, rect.top + c.dy * rect.height));
    await tester.pump(const Duration(milliseconds: 300));
    return (app, network);
  }

  testWidgets('online: "No definition found" with Search online; the result is marked', (
    tester,
  ) async {
    final online = FakeOnlineDictionary(
      OnlineFound([
        entry('serendipity', 'noun', ['A happy accident.']),
      ]),
    );
    final (app, _) = await open(tester, online);
    expect(find.text('No definition found for “serendipity”'), findsOneWidget);
    expect(online.calls, isEmpty);
    await tester.tap(find.text('Search online'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(online.calls, ['serendipity']);
    expect(find.textContaining('A happy accident.'), findsOneWidget);
    expect(find.text('From Wiktionary online'), findsOneWidget);
    await tester.tapAt(const Offset(400, 700));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byKey(lookupPanelKey), findsNothing);
    await closeReader(tester, app);
  });

  testWidgets('"Nothing found online" and "Couldn\'t reach Wiktionary"', (tester) async {
    final online = FakeOnlineDictionary(const OnlineNotFound());
    final (app, _) = await open(tester, online);
    await tester.tap(find.text('Search online'));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('Nothing found online'), findsOneWidget);
    online.result = const OnlineFailed();
    await tester.tap(find.text('Try again'));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text("Couldn't reach Wiktionary"), findsOneWidget);
    await closeReader(tester, app);
  });

  testWidgets('offline: no button, "Online search isn\'t available offline"', (tester) async {
    final online = FakeOnlineDictionary(const OnlineNotFound());
    final (app, _) = await open(tester, online, isOnline: false);
    expect(find.text("Online search isn't available offline."), findsOneWidget);
    expect(find.text('Search online'), findsNothing);
    await closeReader(tester, app);
  });

  testWidgets('going offline while the button shows replaces it with the message', (tester) async {
    final online = FakeOnlineDictionary(const OnlineNotFound());
    final (app, network) = await open(tester, online);
    expect(find.text('Search online'), findsOneWidget);
    network.online = false;
    await tester.pump();
    await tester.pump();
    expect(find.text('Search online'), findsNothing);
    expect(find.text("Online search isn't available offline."), findsOneWidget);
    await closeReader(tester, app);
  });
}
