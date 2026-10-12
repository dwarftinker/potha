import 'package:flutter_test/flutter_test.dart';
import 'package:potha/core/document/reading_position.dart';
import 'package:potha/features/reader/domain/jump_back.dart';

void main() {
  late JumpBack back;
  setUp(() => back = JumpBack());

  test('is empty at first', () => expect(back.target, isNull));

  test('a jump records where the reader was (FR-026)', () {
    back.recordJump(from: const ReadingPosition(12, 0.4));
    expect(back.target, const ReadingPosition(12, 0.4));
  });

  test('a second jump replaces the way back (one step only)', () {
    back.recordJump(from: const ReadingPosition(12, 0.4));
    back.recordJump(from: const ReadingPosition(80, 0));
    expect(back.target, const ReadingPosition(80, 0));
  });

  test('use returns the position and clears it', () {
    back.recordJump(from: const ReadingPosition(12, 0.4));
    expect(back.use(), const ReadingPosition(12, 0.4));
    expect(back.target, isNull);
    expect(back.use(), isNull);
  });

  test('clear empties it, and listeners hear each change', () {
    var n = 0;
    back.addListener(() => n++);
    back.recordJump(from: const ReadingPosition(3, 0));
    back.clear();
    back.clear();
    expect(back.target, isNull);
    expect(n, 2);
  });
}
