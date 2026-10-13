// Copy the word, and look up words inside a definition with Back (003 US7, FR-023, FR-024).
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'reader_test_app.dart';

const text = 'The melancholy reader.';

void main() {
  FakeDictionaryStore store() => FakeDictionaryStore(
    FakeLexicon(
      entryMap: {
        'melancholy': [
          entry('melancholy', 'noun', ['Great sadness or gloom.']),
        ],
        'sadness': [
          entry('sadness', 'noun', ['The state of being sad.']),
        ],
        'sad': [
          entry('sad', 'adj', ['Unhappy.']),
        ],
      },
    ),
  );

  testWidgets('Copy, then two related words and Back twice', (tester) async {
    final copied = <String>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (
      call,
    ) async {
      if (call.method == 'Clipboard.setData') {
        copied.add((call.arguments as Map)['text'] as String);
      }
      return null;
    });
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );

    final doc = FakeReaderDocument(pageCount: 2, texts: {1: '$text\r\n'});
    final (app, _) = await openReader(tester, doc, store: store());
    await dismissHint(tester);
    final rect = tester.getRect(find.byKey(fakeViewKey));
    final c = charCentre('$text\r\n', text.indexOf('melancholy') + 1);
    await tester.longPressAt(Offset(rect.left + c.dx * rect.width, rect.top + c.dy * rect.height));
    await tester.pump(const Duration(milliseconds: 300));

    await tester.tap(find.byTooltip('Copy'));
    await tester.pump();
    expect(copied, ['melancholy']);
    expect(find.text('Copied'), findsOneWidget);
    expect(find.byTooltip('Back'), findsNothing);

    // Words in a definition can be tapped.
    await tester.tapOnText(find.textRange.ofSubstring('sadness'));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.textContaining('The state of being sad.'), findsOneWidget);
    await tester.tapOnText(find.textRange.ofSubstring('sad.').first);
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.textContaining('Unhappy.'), findsOneWidget);

    await tester.tap(find.byTooltip('Back'));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.textContaining('The state of being sad.'), findsOneWidget);
    await tester.tap(find.byTooltip('Back'));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.textContaining('Great sadness or gloom.'), findsOneWidget);
    expect(find.byTooltip('Back'), findsNothing);
    await tester.pump(const Duration(seconds: 4));
    await closeReader(tester, app);
  });
}
