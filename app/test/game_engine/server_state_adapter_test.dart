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

  test('movableIds tolerates map-shaped lists and stringly typed indexes', () {
    // PHP serializes a non-sequential array as a JSON object.
    expect(
      ServerStateAdapter.movableIds('red', {
        '0': {'token': 0},
        '2': {'token': 2},
      }),
      ['red_0', 'red_2'],
    );
    expect(
      ServerStateAdapter.movableIds('red', [
        {'token': '1'},
      ]),
      ['red_1'],
    );
    expect(ServerStateAdapter.movableIds('red', ['3']), ['red_3']);
    expect(ServerStateAdapter.movableIds('red', 'garbage'), isEmpty);
  });

  group('movableFromState — legal-move fallback from the snapshot', () {
    test('a pending dice of 1 yields the ring token (the reported bug)', () {
      final ids = ServerStateAdapter.movableFromState({
        'tokens': {
          'red': [10, -1, -1, -1],
          'yellow': [-1, -1, -1, -1],
        },
        'turn': 'red',
        'phase': 'awaiting_move',
        'dice': 1,
        'seq': 3,
      });
      expect(ids, ['red_0'],
          reason: 'a legal 1-step move must always be offered');
    });

    test('dice 1 with everything in base yields nothing (six required)', () {
      final ids = ServerStateAdapter.movableFromState({
        'tokens': {
          'red': [-1, -1, -1, -1],
          'yellow': [-1, -1, -1, -1],
        },
        'turn': 'red',
        'phase': 'awaiting_move',
        'dice': 1,
      });
      expect(ids, isEmpty);
    });

    test('mirrors server occupancy + exact-home rules', () {
      final ids = ServerStateAdapter.movableFromState({
        'tokens': {
          'red': [10, 11, 55, -1],
          'yellow': [-1, -1, -1, -1],
        },
        'turn': 'red',
        'phase': 'awaiting_move',
        'dice': 2,
      });
      // 10+2=12 free, 11+2=13 free, 55+2=57 overshoots home, base needs a six.
      expect(ids, ['red_0', 'red_1']);
    });

    test('landing on your own token is not offered', () {
      final ids = ServerStateAdapter.movableFromState({
        'tokens': {
          'red': [10, 12, -1, -1],
          'yellow': [-1, -1, -1, -1],
        },
        'turn': 'red',
        'phase': 'awaiting_move',
        'dice': 2,
      });
      // token0 10+2=12 occupied by own token1; token1 12+2=14 free.
      expect(ids, ['red_1']);
    });

    test('shared home slot may hold several own tokens', () {
      final ids = ServerStateAdapter.movableFromState({
        'tokens': {
          'red': [55, 56, -1, -1],
          'yellow': [-1, -1, -1, -1],
        },
        'turn': 'red',
        'phase': 'awaiting_move',
        'dice': 1,
      });
      expect(ids, ['red_0'], reason: '55+1 lands exactly on home');
    });

    test('inactive phases and missing fields yield nothing', () {
      expect(
        ServerStateAdapter.movableFromState({
          'tokens': {
            'red': [10, -1, -1, -1],
          },
          'turn': 'red',
          'phase': 'awaiting_roll',
          'dice': null,
        }),
        isEmpty,
      );
      expect(ServerStateAdapter.movableFromState(const {}), isEmpty);
    });
  });
}
