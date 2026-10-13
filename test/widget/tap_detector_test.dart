import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:potha/features/reader/ui/tap_detector.dart';

void main() {
  late List<Offset> taps;
  late List<String> events;
  late ValueNotifier<int> moving;

  Future<void> pumpDetector(WidgetTester tester) async {
    taps = [];
    events = [];
    moving = ValueNotifier(0);
    await tester.pumpWidget(Directionality(
      textDirection: TextDirection.ltr,
      child: TapDetector(
        movement: moving,
        onTap: (global, local) {
          taps.add(local);
          events.add('tap');
        },
        onLongPress: (global, local) => events.add('longPress(${local.dx.round()})'),
        onLongPressMove: (global) => events.add('move(${global.dx.round()})'),
        onLongPressEnd: () => events.add('end'),
        onDoubleClick: (global, local) => events.add('doubleClick'),
        // A recogniser below that wants double taps must not delay ours.
        child: GestureDetector(
          onDoubleTap: () {},
          onTap: () {},
          child: const SizedBox.expand(child: ColoredBox(color: Color(0xFFFFFFFF))),
        ),
      ),
    ));
  }

  testWidgets('fires on pointer up with no delay (FR-017)', (tester) async {
    await pumpDetector(tester);
    final g = await tester.startGesture(const Offset(100, 100));
    await g.up();
    expect(taps, [const Offset(100, 100)]);
    // Let the double-tap recogniser below time out.
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('two quick taps are two taps, never a double tap', (tester) async {
    await pumpDetector(tester);
    await tester.tapAt(const Offset(50, 50));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tapAt(const Offset(52, 50));
    expect(taps, hasLength(2));
    // Let the double-tap recogniser below time out.
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('a drag over 18 px is not a tap', (tester) async {
    await pumpDetector(tester);
    final g = await tester.startGesture(const Offset(100, 100));
    await g.moveBy(const Offset(19, 0));
    await g.up();
    expect(taps, isEmpty);
    // Let the double-tap recogniser below time out.
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('a small wobble is still a tap', (tester) async {
    await pumpDetector(tester);
    final g = await tester.startGesture(const Offset(100, 100));
    await g.moveBy(const Offset(10, 5));
    await g.up();
    expect(taps, hasLength(1));
    // Let the double-tap recogniser below time out.
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('a hold over 300 ms is not a tap', (tester) async {
    await pumpDetector(tester);
    final g = await tester.startGesture(const Offset(100, 100));
    await tester.pump(const Duration(milliseconds: 301));
    await g.up();
    expect(taps, isEmpty);
    // Let the double-tap recogniser below time out.
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('a second pointer cancels the tap', (tester) async {
    await pumpDetector(tester);
    final a = await tester.startGesture(const Offset(100, 100), pointer: 1);
    final b = await tester.startGesture(const Offset(200, 200), pointer: 2);
    await b.up();
    await a.up();
    expect(taps, isEmpty);
    // Let the double-tap recogniser below time out.
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('the view moving during the gesture cancels the tap', (tester) async {
    await pumpDetector(tester);
    final g = await tester.startGesture(const Offset(100, 100));
    moving.value++;
    await g.up();
    expect(taps, isEmpty);
    // The next tap works again.
    await tester.tapAt(const Offset(100, 100));
    expect(taps, hasLength(1));
    // Let the double-tap recogniser below time out.
    await tester.pump(const Duration(seconds: 1));
  });

  // 003: long-press, long-press drag and mouse double-click (research R6).
  group('long-press', () {
    testWidgets('fires at 500 ms while the pointer is still down', (tester) async {
      await pumpDetector(tester);
      final g = await tester.startGesture(const Offset(100, 100));
      await tester.pump(const Duration(milliseconds: 450));
      expect(events, isEmpty);
      await tester.pump(const Duration(milliseconds: 60));
      expect(events, ['longPress(100)']);
      await g.up();
      expect(events, ['longPress(100)', 'end']);
      await tester.pump(const Duration(seconds: 1));
    });

    testWidgets('then moves go to onLongPressMove and the lift to onLongPressEnd, no tap',
        (tester) async {
      await pumpDetector(tester);
      final g = await tester.startGesture(const Offset(100, 100));
      await tester.pump(const Duration(milliseconds: 520));
      await g.moveTo(const Offset(160, 100));
      await g.moveTo(const Offset(220, 104));
      await g.up();
      expect(events, ['longPress(100)', 'move(160)', 'move(220)', 'end']);
      expect(taps, isEmpty);
      await tester.pump(const Duration(seconds: 1));
    });

    testWidgets('not when the pointer moved over 18 px first', (tester) async {
      await pumpDetector(tester);
      final g = await tester.startGesture(const Offset(100, 100));
      await g.moveBy(const Offset(0, 30));
      await tester.pump(const Duration(milliseconds: 600));
      await g.up();
      expect(events, isEmpty);
      await tester.pump(const Duration(seconds: 1));
    });

    testWidgets('not with a second pointer down', (tester) async {
      await pumpDetector(tester);
      final a = await tester.startGesture(const Offset(100, 100));
      final b = await tester.startGesture(const Offset(200, 200), pointer: 7);
      await tester.pump(const Duration(milliseconds: 600));
      await a.up();
      await b.up();
      expect(events, isEmpty);
      await tester.pump(const Duration(seconds: 1));
    });

    testWidgets('not when the view moved', (tester) async {
      await pumpDetector(tester);
      final g = await tester.startGesture(const Offset(100, 100));
      await tester.pump(const Duration(milliseconds: 200));
      moving.value++;
      await tester.pump(const Duration(milliseconds: 400));
      await g.up();
      expect(events, isEmpty);
      await tester.pump(const Duration(seconds: 1));
    });
  });

  group('mouse double-click', () {
    Future<void> click(WidgetTester tester, Offset at) async {
      final g = await tester.startGesture(at, kind: PointerDeviceKind.mouse);
      await g.up();
    }

    testWidgets('two clicks within 300 ms and 18 px: two taps, then one double-click',
        (tester) async {
      await pumpDetector(tester);
      await click(tester, const Offset(100, 100));
      await tester.pump(const Duration(milliseconds: 150));
      await click(tester, const Offset(105, 102));
      expect(events, ['tap', 'tap', 'doubleClick']);
      await tester.pump(const Duration(seconds: 1));
    });

    testWidgets('clicks too far apart in time or space are not a double-click', (tester) async {
      await pumpDetector(tester);
      await click(tester, const Offset(100, 100));
      await tester.pump(const Duration(milliseconds: 350));
      await click(tester, const Offset(100, 100));
      await tester.pump(const Duration(milliseconds: 100));
      await click(tester, const Offset(150, 100));
      expect(events, ['tap', 'tap', 'tap']);
      await tester.pump(const Duration(seconds: 1));
    });

    testWidgets('a touch double tap is two taps, never a double-click', (tester) async {
      await pumpDetector(tester);
      await tester.tapAt(const Offset(100, 100));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.tapAt(const Offset(100, 100));
      expect(events, ['tap', 'tap']);
      await tester.pump(const Duration(seconds: 1));
    });
  });
}
