import 'package:flutter_test/flutter_test.dart';
import 'package:ludo_friends/game_engine/models/ludo_color.dart';

void main() {
  group('LudoColor 2v2 team mapping', () {
    test('Team A is red + yellow (seats 0 & 2)', () {
      expect(LudoColor.red.teamSide, 0);
      expect(LudoColor.yellow.teamSide, 0);
      expect(LudoColor.teamA, const [LudoColor.red, LudoColor.yellow]);
    });

    test('Team B is green + blue (seats 1 & 3)', () {
      expect(LudoColor.green.teamSide, 1);
      expect(LudoColor.blue.teamSide, 1);
      expect(LudoColor.teamB, const [LudoColor.green, LudoColor.blue]);
    });

    test('teamLabel maps a side to a human label', () {
      expect(LudoColor.teamLabel(0), 'Team A');
      expect(LudoColor.teamLabel(1), 'Team B');
    });

    test('partners share a side, opponents differ', () {
      expect(LudoColor.red.teamSide, LudoColor.yellow.teamSide);
      expect(LudoColor.green.teamSide, LudoColor.blue.teamSide);
      expect(LudoColor.red.teamSide, isNot(LudoColor.green.teamSide));
    });
  });
}
