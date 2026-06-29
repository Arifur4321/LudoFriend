import 'package:flutter_test/flutter_test.dart';
import 'package:ludo_friends/game_engine/board_layout.dart';
import 'package:ludo_friends/game_engine/models/ludo_color.dart';
import 'package:ludo_friends/game_engine/models/token.dart';

void main() {
  test('ring has 52 unique cells', () {
    expect(BoardLayout.ringCells.length, 52);
    expect(BoardLayout.ringCells.toSet().length, 52);
  });

  test('each color has a 6-cell home column', () {
    for (final c in LudoColor.values) {
      expect(BoardLayout.homeColumns[c]!.length, 6);
    }
  });

  test('each color has 4 base slots', () {
    for (final c in LudoColor.values) {
      expect(BoardLayout.baseSlots[c]!.length, 4);
    }
  });

  test('relative position 0 maps to the color start cell', () {
    final redStart = BoardLayout.offsetForRelative(LudoColor.red, 0);
    expect(redStart, BoardLayout.ringPoint(0));
    final greenStart = BoardLayout.offsetForRelative(LudoColor.green, 0);
    expect(greenStart, BoardLayout.ringPoint(13));
  });

  test('a token in base maps to its base slot', () {
    final t = Token(color: LudoColor.blue, index: 2);
    expect(BoardLayout.cellOf(t), BoardLayout.baseSlots[LudoColor.blue]![2]);
  });

  test('a finished token maps to the inner home-column cell', () {
    final t = Token(color: LudoColor.red, index: 0, position: 56);
    expect(BoardLayout.cellOf(t), const GridPoint(7, 6));
  });
}
