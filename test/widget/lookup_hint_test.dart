// The one-time lookup hint (003 FR-006, US1 scenario 7).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'reader_test_app.dart';
import 'test_app.dart';

void main() {
  testWidgets('shown on the first open with the three ways to look up; Got it hides it for good', (
    tester,
  ) async {
    final doc = FakeReaderDocument(pageCount: 3);
    final (app, _) = await openReader(tester, doc);
    expect(find.textContaining('Long-press a word to look it up'), findsOneWidget);
    expect(find.textContaining('double-click with a mouse'), findsOneWidget);
    expect(find.textContaining('Tap to define'), findsOneWidget);

    await tester.tap(find.text('Got it'));
    await settleReal(tester);
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.textContaining('Long-press a word to look it up'), findsNothing);
    final prefs = await tester.runAsync(() => app.db.select(app.db.readerPreferences).getSingle());
    expect(prefs!.lookupHintShown, isTrue);

    // The next open: no hint.
    await leaveReader(tester);
    final navigator = tester.state<NavigatorState>(find.byType(Navigator));
    navigator.push(MaterialPageRoute<void>(builder: (_) => readerScreenFor('b1')));
    await settleReal(tester);
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byKey(fakeViewKey), findsOneWidget);
    expect(find.textContaining('Long-press a word to look it up'), findsNothing);
    await closeReader(tester, app);
  });
}
