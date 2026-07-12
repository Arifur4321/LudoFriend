import 'package:flutter_test/flutter_test.dart';
import 'package:ludo_friends/features/game/application/server_state_adapter.dart';
import 'package:ludo_friends/game_engine/models/game_player.dart';
import 'package:ludo_friends/game_engine/models/game_status.dart';
import 'package:ludo_friends/game_engine/models/ludo_color.dart';

void main() {
  final players = [
    const GamePlayer(color: LudoColor.red, name: 'Aisha'),
    const GamePlayer(color: LudoColor.yellow, name: 'Maya'),
  ];

  test('maps compact server state into a GameState', () {
    final state = ServerStateAdapter.toGameState(
      serverState: {
        'tokens': {
          'red': [-1, 0, 5, 56],
          'yellow': [-1, -1, -1, -1],
        },
        'turn': 'yellow',
        'dice': 6,
        'status': 'active',
      },
      players: players,
    );

    expect(state.tokens.length, 8);
    expect(state.currentPlayerIndex, 1); // yellow is second
    expect(state.currentColor, LudoColor.yellow);
    expect(state.lastDice, 6);

    final red = state.tokensOf(LudoColor.red);
    expect(red[0].isInBase, true); // -1
    expect(red[1].position, 0);
    expect(red[3].isFinished, true); // 56
  });

  test('awaitingMove only when dice is set and there are movable tokens', () {
    final base = {
      'tokens': {
        'red': [0, 0, 0, 0],
        'yellow': [-1, -1, -1, -1],
      },
      'turn': 'red',
      'dice': 3,
    };

    final noMoves = ServerStateAdapter.toGameState(
      serverState: base,
      players: players,
    );
    expect(noMoves.status, GameStatus.waitingForRoll);

    final withMoves = ServerStateAdapter.toGameState(
      serverState: base,
      players: players,
      movableTokenIds: const ['red_0'],
    );
    expect(withMoves.status, GameStatus.awaitingMove);
    expect(withMoves.pendingMovableTokenIds, ['red_0']);
  });

  test('preserves server awaiting-move phase for a remote player', () {
    final state = ServerStateAdapter.toGameState(
      serverState: {
        'tokens': {
          'red': [0, -1, -1, -1],
          'yellow': [-1, -1, -1, -1],
        },
        'turn': 'yellow',
        'phase': 'awaiting_move',
        'dice': 6,
      },
      players: players,
    );

    expect(state.status, GameStatus.awaitingMove);
    expect(state.pendingMovableTokenIds, isEmpty);
    expect(state.currentColor, LudoColor.yellow);
  });

  test('detects a finished match from winner', () {
    final state = ServerStateAdapter.toGameState(
      serverState: {
        'tokens': {
          'red': [56, 56, 56, 56],
          'yellow': [0, 0, 0, 0],
        },
        'turn': 'red',
        'dice': null,
        'winner': 'red',
      },
      players: players,
    );
    expect(state.status, GameStatus.finished);
    expect(state.winner, LudoColor.red);
    expect(state.isFinished, true);
  });

  test('movableIds handles int lists and map lists', () {
    expect(ServerStateAdapter.movableIds('red', [0, 2]), ['red_0', 'red_2']);
    expect(
      ServerStateAdapter.movableIds('green', [
        {'token': 1},
        {'index': 3},
      ]),
      ['green_1', 'green_3'],
    );
    expect(ServerStateAdapter.movableIds('red', null), isEmpty);
  });
}
