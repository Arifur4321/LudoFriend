import 'package:flutter_test/flutter_test.dart';
import 'package:ludo_friends/game_engine/models/move_result.dart';

void main() {
  test('parses authoritative cell path and captured return positions', () {
    final move = MoveResult.fromServer(
      {
        'color': 'red',
        'token': 2,
        'from': 7,
        'to': 12,
        'path': [8, 9, 10, 11, 12],
        'move_seq': 19,
        'captured': [
          {'color': 'green', 'token': 1, 'from': 50},
        ],
        'finished': false,
        'extra_turn': true,
      },
      fallbackTokenId: 'red_2',
    );

    expect(move.movedTokenId, 'red_2');
    expect(move.path, [8, 9, 10, 11, 12]);
    expect(move.sequence, 19);
    expect(move.capturedTokenIds, ['green_1']);
    expect(move.capturedFromPositions, {'green_1': 50});
    expect(move.maxCapturedReturnSteps, 51);
  });

  test('builds a fallback step path for an older server response', () {
    final move = MoveResult.fromServer(
      {'from': 3, 'to': 6},
      fallbackTokenId: 'yellow_0',
    );

    expect(move.path, [4, 5, 6]);
  });
}
