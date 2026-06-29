import 'package:flutter_test/flutter_test.dart';
import 'package:ludo_friends/game_engine/models/dice.dart';

void main() {
  test('dice always returns 1..6', () {
    final d = DiceRoller(42);
    for (var i = 0; i < 5000; i++) {
      final v = d.roll();
      expect(v, inInclusiveRange(1, 6));
    }
  });

  test('same seed is reproducible', () {
    final a = DiceRoller(7);
    final b = DiceRoller(7);
    for (var i = 0; i < 50; i++) {
      expect(a.roll(), b.roll());
    }
  });
}
