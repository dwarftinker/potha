// 003 FR-033 / constitution VII: the lookup panel, handles, chip, hint, history and About
// are labelled, large enough to tap, readable in every theme, and work at 2× text size.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:potha/core/db/app_database.dart';
import 'package:potha/features/reader/data/reader_repository.dart';
import 'package:potha/features/reader/ui/lookup_panel.dart';

import 'reader_test_app.dart';
import 'test_app.dart';

final pageText = '${'\r\n' * 4}The melancholy reader.\r\n';

FakeDictionaryStore dictionary() => FakeDictionaryStore(
  FakeLexicon(
    entryMap: {
      'melancholy': [
        entry('melancholy', 'noun', ['Great sadness.', 'Black bile.'], ipa: '/ˈmɛlənkəli/'),
      ],
    },
  ),
);

Future<void> longPressMelancholy(WidgetTester tester) async {
  final rect = tester.getRect(find.byKey(fakeViewKey));
  final c = charCentre(pageText, pageText.indexOf('melancholy') + 1);
  await tester.longPressAt(Offset(rect.left + c.dx * rect.width, rect.top + c.dy * rect.height));
  await tester.pump(const Duration(milliseconds: 300));
}

void main() {
  for (final theme in ReadingTheme.values) {
    testWidgets('${theme.name}: panel, handles and chip meet label, size and contrast '
        'guidelines', (tester) async {
      final semantics = tester.ensureSemantics();
      final doc = FakeReaderDocument(pageCount: 3, texts: {1: pageText});
      final (app, _) = await openReader(
        tester,
        doc,
        store: dictionary(),
        before: (app) async {
          await tester.runAsync(() async {
            final repo = ReaderRepository(app.db);
            await repo.setTheme(theme);
            await repo.setTapToDefine(true);
          });
        },
      );
      await settleReal(tester);
      await dismissHint(tester);
      await longPressMelancholy(tester);
      expect(find.byKey(lookupPanelKey), findsOneWidget);
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(textContrastGuideline));
      semantics.dispose();
      await closeReader(tester, app);
    });
  }

  testWidgets('the panel is announced and labelled; each sense is its own node', (tester) async {
    final semantics = tester.ensureSemantics();
    final doc = FakeReaderDocument(pageCount: 3, texts: {1: pageText});
    final (app, _) = await openReader(tester, doc, store: dictionary());
    await dismissHint(tester);
    await longPressMelancholy(tester);
    expect(find.bySemanticsLabel('Definition of melancholy'), findsOneWidget);
    expect(find.bySemanticsLabel('Noun, definition 1: Great sadness.'), findsOneWidget);
    expect(find.bySemanticsLabel('Noun, definition 2: Black bile.'), findsOneWidget);
    // Buttons are labelled by their tooltips; the handles by their own labels.
    expect(find.byTooltip('Close'), findsOneWidget);
    expect(find.byTooltip('Copy'), findsOneWidget);
    expect(find.byTooltip('About this dictionary'), findsOneWidget);
    expect(find.bySemanticsLabel('Selection start'), findsOneWidget);
    expect(find.bySemanticsLabel('Selection end'), findsOneWidget);
    final announced = tester.takeAnnouncements().map((a) => a.message);
    expect(announced, contains('Definition of melancholy'));
    semantics.dispose();
    await closeReader(tester, app);
  });

  testWidgets('the hint, history sheet and About are labelled and large enough', (tester) async {
    final semantics = tester.ensureSemantics();
    final doc = FakeReaderDocument(pageCount: 3, texts: {1: pageText});
    final (app, _) = await openReader(tester, doc, store: dictionary());
    expect(find.text('Got it'), findsOneWidget);
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    await dismissHint(tester);

    await tapView(tester, 0.5);
    await tester.tap(find.byTooltip('Lookup history'));
    await tester.pumpAndSettle();
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    Navigator.of(tester.element(find.text('This book'))).pop();
    await tester.pumpAndSettle();
    await tapView(tester, 0.5);
    await tester.pump(const Duration(milliseconds: 300));

    await longPressMelancholy(tester);
    await tester.tap(find.byTooltip('About this dictionary'));
    await tester.pumpAndSettle();
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    await tester.tap(find.text('Close').last);
    await tester.pumpAndSettle();
    semantics.dispose();
    await closeReader(tester, app);
  });

  testWidgets('at 2× text the panel keeps its first size, scrolls, and does not overflow', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 2.75;
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(() {
      tester.view.reset();
      tester.platformDispatcher.clearTextScaleFactorTestValue();
    });
    final doc = FakeReaderDocument(pageCount: 3, texts: {1: pageText});
    final (app, _) = await openReader(tester, doc, store: dictionary());
    await dismissHint(tester);
    await longPressMelancholy(tester);
    expect(tester.takeException(), isNull);
    final screen = tester.getSize(find.byType(Scaffold).last);
    final panel = tester.getRect(find.byKey(lookupPanelKey));
    expect(panel.height, lessThanOrEqualTo(screen.height / 3 + 1));
    final list = find.descendant(of: find.byKey(lookupPanelKey), matching: find.byType(Scrollable));
    expect(list, findsOneWidget);
    await tester.drag(list, const Offset(0, -200));
    await tester.pump();
    expect(tester.takeException(), isNull);
    await closeReader(tester, app);
  });
}
