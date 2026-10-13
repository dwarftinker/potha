// User Story 1: read comfortably (FR-001 to FR-004, FR-037, FR-040).
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:potha/core/document/document_format.dart';

import 'reader_test_app.dart';
import 'test_app.dart';

void main() {
  late List<String> systemUi;

  setUp(() => systemUi = []);

  Future<void> mockSystemChrome(WidgetTester tester) async =>
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform,
          (call) async {
        if (call.method == 'SystemChrome.setEnabledSystemUIMode') {
          systemUi.add(call.arguments as String);
        }
        return null;
      });

  final topBar = find.byTooltip('Back to library');
  bool shown(WidgetTester tester) =>
      tester.widget<IgnorePointer>(find.byKey(const ValueKey('reader-controls'))).ignoring ==
      false;

  testWidgets('opens on the page with the controls hidden (FR-001)', (tester) async {
    await mockSystemChrome(tester);
    final (app, _) = await openReader(tester, FakeReaderDocument());
    expect(find.textContaining('View page 1'), findsOneWidget);
    expect(shown(tester), isFalse);
    expect(systemUi.last, 'SystemUiMode.immersiveSticky');
    await closeReader(tester, app);
  });

  testWidgets('a centre tap shows and hides the bars (FR-002, FR-004)', (tester) async {
    await mockSystemChrome(tester);
    final (app, _) = await openReader(tester, FakeReaderDocument());

    await tapView(tester, 0.5);
    await tester.pump(const Duration(milliseconds: 300));
    expect(shown(tester), isTrue);
    expect(topBar, findsOneWidget);
    expect(find.text('Moby-Dick'), findsOneWidget);
    expect(find.text('Page 1 of 300'), findsOneWidget);
    expect(find.byType(Slider), findsOneWidget);
    expect(systemUi.last, 'SystemUiMode.edgeToEdge');

    await tapView(tester, 0.5);
    await tester.pump(const Duration(milliseconds: 300));
    expect(shown(tester), isFalse);
    expect(systemUi.last, 'SystemUiMode.immersiveSticky');
    await closeReader(tester, app);
  });

  testWidgets('the bars hide after 3 s (FR-003)', (tester) async {
    final (app, _) = await openReader(tester, FakeReaderDocument());
    await tapView(tester, 0.5);
    await tester.pump(const Duration(milliseconds: 2900));
    expect(shown(tester), isTrue);
    await tester.pump(const Duration(milliseconds: 400));
    expect(shown(tester), isFalse);
    await closeReader(tester, app);
  });

  testWidgets('with a screen reader on, the bars stay until hidden (FR-003)', (tester) async {
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(accessibleNavigation: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    final (app, _) = await openReader(tester, FakeReaderDocument());
    await tapView(tester, 0.5);
    await tester.pump(const Duration(seconds: 10));
    expect(shown(tester), isTrue);
    await closeReader(tester, app);
  });

  testWidgets('a page change is announced as "Page N of M" (FR-040)', (tester) async {
    final (app, view) = await openReader(tester, FakeReaderDocument());
    tester.takeAnnouncements();
    view.controller.emitPosition(const ReadingPosition(2, 0));
    await tester.pump();
    expect(tester.takeAnnouncements(), contains(isAccessibilityAnnouncement('Page 2 of 300')));
    // Scrolling within the page announces nothing.
    view.controller.emitPosition(const ReadingPosition(2, 0.5));
    await tester.pump();
    expect(tester.takeAnnouncements(), isEmpty);
    await closeReader(tester, app);
  });

  testWidgets('a page that cannot be shown has a placeholder (FR-037)', (tester) async {
    final (app, view) = await openReader(tester, FakeReaderDocument(failingPages: {3}));
    view.controller.emitPosition(const ReadingPosition(3, 0));
    await tester.pump();
    expect(find.text("This page can't be shown"), findsOneWidget);
    await closeReader(tester, app);
  });

  testWidgets('Back returns to the library and restores the system bars', (tester) async {
    await mockSystemChrome(tester);
    final (app, _) = await openReader(tester, FakeReaderDocument());
    await tapView(tester, 0.5);
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(topBar);
    await tester.pump(const Duration(seconds: 1));
    await settleReal(tester);
    expect(find.text('Library'), findsOneWidget);
    expect(systemUi.last, 'SystemUiMode.edgeToEdge');
    await closeReader(tester, app);
  });

  testWidgets('a library snackbar does not stay over the reader', (tester) async {
    final (app, _) = await openReader(tester, FakeReaderDocument(), before: (app) async {
      final context = tester.element(find.text('Library'));
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Book added'), duration: Duration(minutes: 1)));
      await tester.pump();
    });
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Book added'), findsNothing);
    await closeReader(tester, app);
  });
}
