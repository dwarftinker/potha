import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:potha/features/reader/ui/tap_detector.dart';

void main() {
  late List<Offset> taps;
  late ValueNotifier<int> moving;

  Future<void> pumpDetector(WidgetTester tester) async {
    taps = [];
    moving = ValueNotifier(0);
    await tester.pumpWidget(Directionality(
      textDirection: TextDirection.ltr,
      child: TapDetector(
        movement: moving,
        onTap: (global, local) => taps.add(local),
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
}
