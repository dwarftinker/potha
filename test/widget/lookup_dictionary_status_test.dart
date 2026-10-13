// The panel while the dictionary is being prepared (003 US3, FR-022, research R2).
import 'package:flutter_test/flutter_test.dart';
import 'package:potha/core/dictionary/lexicon.dart';
import 'package:potha/features/reader/ui/lookup_panel.dart';

import 'reader_test_app.dart';
import 'test_app.dart';

const text = 'The melancholy reader.';

void main() {
  FakeDictionaryStore notReady() => FakeDictionaryStore(
    FakeLexicon(
      entryMap: {
        'melancholy': [
          entry('melancholy', 'noun', ['Great sadness.']),
        ],
      },
    ),
    ready: false,
  );

  Future<void> longPressWord(WidgetTester tester) async {
    final rect = tester.getRect(find.byKey(fakeViewKey));
    final c = charCentre('$text\r\n', 6);
    await tester.longPressAt(Offset(rect.left + c.dx * rect.width, rect.top + c.dy * rect.height));
    await tester.pump(const Duration(milliseconds: 100));
  }

  Future<(TestApp, FakeDictionaryStore)> open(WidgetTester tester) async {
    final store = notReady();
    final doc = FakeReaderDocument(pageCount: 2, texts: {1: '$text\r\n'});
    final (app, _) = await openReader(tester, doc, store: store);
    await dismissHint(tester);
    return (app, store);
  }

  testWidgets('web: downloading shows progress, then the definition', (tester) async {
    final (app, store) = await open(tester);
    store.setStatus(const DictionaryDownloading(42, 100));
    await longPressWord(tester);
    expect(find.text('Downloading the dictionary… 42%'), findsOneWidget);
    store.setStatus(const DictionaryDownloading(90, 100));
    await tester.pump();
    await tester.pump();
    expect(find.text('Downloading the dictionary… 90%'), findsOneWidget);
    store.markReady();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.textContaining('Great sadness.'), findsOneWidget);
    await closeReader(tester, app);
  });

  testWidgets('web: offline before the first download says so; a later lookup retries', (
    tester,
  ) async {
    final (app, store) = await open(tester);
    store.setStatus(const DictionaryFailed(DictionaryFailure.offline));
    final before = store.startCalls;
    await longPressWord(tester);
    expect(
      find.text('The dictionary needs an internet connection once to download.'),
      findsOneWidget,
    );
    expect(store.startCalls, greaterThan(before));
    await tester.tapAt(const Offset(400, 500)); // close
    await tester.pump(const Duration(milliseconds: 300));
    store.markReady();
    await longPressWord(tester);
    expect(find.textContaining('Great sadness.'), findsOneWidget);
    await closeReader(tester, app);
  });

  testWidgets('mobile: unpacking shows "Preparing the dictionary…", then the result', (
    tester,
  ) async {
    final (app, store) = await open(tester);
    store.setStatus(const DictionaryUnpacking());
    await longPressWord(tester);
    expect(find.text('Preparing the dictionary…'), findsOneWidget);
    expect(find.byKey(lookupPanelKey), findsOneWidget);
    store.markReady();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.textContaining('Great sadness.'), findsOneWidget);
    await closeReader(tester, app);
  });
}
