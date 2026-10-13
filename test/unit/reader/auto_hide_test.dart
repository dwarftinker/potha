import 'package:flutter_test/flutter_test.dart';
import 'package:potha/features/reader/domain/auto_hide.dart';

void main() {
  late AutoHide controls;

  setUp(() => controls = AutoHide());
  tearDown(() => controls.dispose());

  testWidgets('starts hidden; show and toggle', (tester) async {
    expect(controls.visible, isFalse);
    controls.toggle();
    expect(controls.visible, isTrue);
    controls.toggle();
    expect(controls.visible, isFalse);
  });

  testWidgets('hides 3 s after being shown (FR-003)', (tester) async {
    controls.show();
    await tester.pump(const Duration(milliseconds: 2999));
    expect(controls.visible, isTrue);
    await tester.pump(const Duration(milliseconds: 1));
    expect(controls.visible, isFalse);
  });

  testWidgets('an interaction restarts the 3 s', (tester) async {
    controls.show();
    await tester.pump(const Duration(seconds: 2));
    controls.interacted();
    await tester.pump(const Duration(seconds: 2));
    expect(controls.visible, isTrue);
    await tester.pump(const Duration(seconds: 1));
    expect(controls.visible, isFalse);
  });

  testWidgets('a hold (panel open, slider dragging) keeps them until released',
      (tester) async {
    controls.show();
    controls.hold();
    await tester.pump(const Duration(seconds: 10));
    expect(controls.visible, isTrue);
    controls.release();
    await tester.pump(const Duration(milliseconds: 2999));
    expect(controls.visible, isTrue);
    await tester.pump(const Duration(milliseconds: 1));
    expect(controls.visible, isFalse);
  });

  testWidgets('holds nest', (tester) async {
    controls.show();
    controls.hold();
    controls.hold();
    controls.release();
    await tester.pump(const Duration(seconds: 10));
    expect(controls.visible, isTrue);
    controls.release();
    await tester.pump(const Duration(seconds: 3));
    expect(controls.visible, isFalse);
  });

  testWidgets('never hides on its own while a screen reader is on', (tester) async {
    controls.screenReaderOn = true;
    controls.show();
    await tester.pump(const Duration(seconds: 30));
    expect(controls.visible, isTrue);
    controls.toggle();
    expect(controls.visible, isFalse);
    controls.screenReaderOn = false;
    controls.show();
    await tester.pump(const Duration(seconds: 3));
    expect(controls.visible, isFalse);
  });

  testWidgets('notifies listeners on change only', (tester) async {
    var n = 0;
    controls.addListener(() => n++);
    controls.show();
    controls.show();
    controls.hide();
    expect(n, 2);
  });
}
