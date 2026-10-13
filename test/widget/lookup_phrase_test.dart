// Look up a selected phrase (003 US5, FR-018, FR-019).
import 'package:flutter/gestures.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:potha/core/document/document_format.dart';
import 'package:potha/features/reader/ui/lookup_panel.dart';
import 'package:potha/features/reader/ui/selection_handles.dart';

import 'reader_test_app.dart';
import 'test_app.dart';

const text = 'They would not give up in spite of the rain.';
final pageText = '${'\r\n' * 4}$text\r\nGive over now.\r\n';

void main() {
  FakeDictionaryStore store() => FakeDictionaryStore(
    FakeLexicon(
      entryMap: {
        'give': [
          entry('give', 'verb', ['To hand over.']),
        ],
        'give up': [
          entry('give up', 'verb', ['To stop trying.']),
        ],
        'in': [
          entry('in', 'prep', ['Inside.']),
        ],
        'in spite of': [
          entry('in spite of', 'prep', ['Despite.']),
        ],
      },
    ),
  );

  Offset at(WidgetTester tester, String word, {int n = 1, int from = 0}) {
    final rect = tester.getRect(find.byKey(fakeViewKey));
    final c = charCentre(pageText, pageText.indexOf(word, from) + n);
    return Offset(rect.left + c.dx * rect.width, rect.top + c.dy * rect.height);
  }

  Future<(TestApp, FakeViewFactory)> open(WidgetTester tester) async {
    final doc = FakeReaderDocument(pageCount: 2, texts: {1: pageText});
    final (app, view) = await openReader(tester, doc, store: store());
    await dismissHint(tester);
    return (app, view);
  }

  String? selectedText(FakeViewFactory view) {
    final h = view.controller.config!.highlights.where((h) => h.kind == HighlightKind.selection);
    return h.isEmpty ? null : '${h.single.rects.length}';
  }

  testWidgets('long-press "give", drag to "up": the highlight grows, then "give up" shows', (
    tester,
  ) async {
    final (app, view) = await open(tester);
    final g = await tester.startGesture(at(tester, 'give'));
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.textContaining('To hand over.'), findsOneWidget);
    final before = tester.getRect(find.byKey(fakeViewKey));
    await g.moveTo(at(tester, 'up', n: 1));
    await tester.pump();
    final grown = view.controller.config!.highlights
        .singleWhere((h) => h.kind == HighlightKind.selection)
        .rects
        .single;
    expect(grown.right * before.width, greaterThan(at(tester, 'up').dx - before.left - 10));
    await g.up();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.textContaining('To stop trying.'), findsOneWidget);
    expect(view.controller.calls.where((c) => c.startsWith('locked')).last, 'locked(false)');
    expect(selectedText(view), isNotNull);
    await closeReader(tester, app);
  });

  testWidgets('dragging the end handle from "in" to "of" looks up "in spite of"', (tester) async {
    final (app, _) = await open(tester);
    await tester.longPressAt(at(tester, 'in spite'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.textContaining('Inside.'), findsOneWidget);
    final end = find.byWidgetPredicate((w) => w is SelectionHandle && !w.start);
    expect(end, findsOneWidget);
    final handle = tester.getCenter(end);
    final g = await tester.startGesture(handle);
    await g.moveTo(at(tester, 'of', n: 1) + const Offset(0, 14));
    await tester.pump();
    await g.up();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.textContaining('Despite.'), findsOneWidget);
    await closeReader(tester, app);
  });

  testWidgets('a made-up phrase: "No entry for" it, with the first word\'s entry (FR-019)', (
    tester,
  ) async {
    final (app, _) = await open(tester);
    final from = pageText.indexOf('Give');
    final g = await tester.startGesture(at(tester, 'Give', from: from));
    await tester.pump(const Duration(milliseconds: 600));
    await g.moveTo(at(tester, 'over', from: from));
    await tester.pump();
    await g.up();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('No entry for “Give over”'), findsOneWidget);
    expect(find.textContaining('To hand over.'), findsOneWidget);
    await closeReader(tester, app);
  });

  testWidgets('handles are at least 48 dp and labelled', (tester) async {
    final semantics = tester.ensureSemantics();
    final (app, _) = await open(tester);
    await tester.longPressAt(at(tester, 'give'));
    await tester.pump(const Duration(milliseconds: 300));
    for (final label in ['Selection start', 'Selection end']) {
      final f = find.bySemanticsLabel(label);
      expect(f, findsOneWidget);
      final size = tester.getSize(
        find.ancestor(of: f, matching: find.byType(SelectionHandle)).first,
      );
      expect(size.width, greaterThanOrEqualTo(48));
      expect(size.height, greaterThanOrEqualTo(48));
    }
    expect(find.byKey(lookupPanelKey), findsOneWidget);
    await closeReader(tester, app);
    semantics.dispose();
  });

  testWidgets('with a mouse, dragging from the selection extends it', (tester) async {
    final (app, view) = await open(tester);
    // Double-click "give" (the clicks toggle the controls twice).
    for (var i = 0; i < 2; i++) {
      final click = await tester.startGesture(at(tester, 'give'), kind: PointerDeviceKind.mouse);
      await click.up();
      await tester.pump(const Duration(milliseconds: 50));
    }
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.textContaining('To hand over.'), findsOneWidget);
    final drag = await tester.startGesture(at(tester, 'give'), kind: PointerDeviceKind.mouse);
    await drag.moveTo(at(tester, 'up'));
    await tester.pump();
    await drag.up();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.textContaining('To stop trying.'), findsOneWidget);
    expect(view.controller.interactionLocked, isFalse);
    await closeReader(tester, app);
  });
}
