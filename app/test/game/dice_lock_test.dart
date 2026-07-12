import 'package:flutter_test/flutter_test.dart';
import 'package:ludo_friends/features/game/application/game_session.dart';
import 'package:ludo_friends/features/game/application/server_state_adapter.dart';
import 'package:ludo_friends/game_engine/models/game_player.dart';
import 'package:ludo_friends/game_engine/models/ludo_color.dart';

/// The dice is enabled purely from `GameSession.canRoll`, which is derived from
/// the authoritative snapshot. These tests pin the lock/unlock rules the fix
/// relies on: the die is tappable only on the local human's awaiting-roll turn,
/// stays locked while a move/token selection is pending, and re-enables for a
/// legitimate extra turn (server keeps the turn in the awaiting-roll phase).
void main() {
  // Seat 0 is the local human ("me"); seat 1 is a remote opponent.
  const players = [
    GamePlayer(color: LudoColor.red, name: 'Me'),
    GamePlayer(color: LudoColor.yellow, name: 'Them', kind: PlayerKind.remote),
  ];

  GameSession sessionFrom(Map<String, dynamic> serverState,
      {List<String> movable = const []}) {
    return GameSession(
      game: ServerStateAdapter.toGameState(
        serverState: serverState,
        players: players,
        movableTokenIds: movable,
      ),
    );
  }

  test('dice is tappable on my awaiting-roll turn', () {
    final session = sessionFrom({
      'tokens': {
        'red': [-1, -1, -1, -1],
        'yellow': [-1, -1, -1, -1],
      },
      'turn': 'red',
      'phase': 'awaiting_roll',
      'dice': null,
    });
    expect(session.canRoll, isTrue);
  });

  test('dice stays locked while token selection is required', () {
    final session = sessionFrom(
      {
        'tokens': {
          'red': [0, -1, -1, -1],
          'yellow': [-1, -1, -1, -1],
        },
        'turn': 'red',
        'phase': 'awaiting_move',
        'dice': 6,
      },
      movable: const ['red_0'],
    );
    // A dice value is pending a move: the player must pick a token, not re-roll.
    expect(session.game.pendingMovableTokenIds, ['red_0']);
    expect(session.canRoll, isFalse);
  });

  test('dice re-enables for a legitimate extra turn (still my awaiting-roll)', () {
    // Server granted another roll (six/capture/home): same player, awaiting_roll.
    final session = sessionFrom({
      'tokens': {
        'red': [10, -1, -1, -1],
        'yellow': [3, -1, -1, -1],
      },
      'turn': 'red',
      'phase': 'awaiting_roll',
      'dice': null,
    });
    expect(session.canRoll, isTrue);
  });

  test('dice is not tappable on the opponent\'s turn', () {
    final session = sessionFrom({
      'tokens': {
        'red': [-1, -1, -1, -1],
        'yellow': [-1, -1, -1, -1],
      },
      'turn': 'yellow',
      'phase': 'awaiting_roll',
      'dice': null,
    });
    expect(session.canRoll, isFalse);
  });

  test('dice is not tappable once the match is finished', () {
    final session = sessionFrom({
      'tokens': {
        'red': [56, 56, 56, 56],
        'yellow': [0, 0, 0, 0],
      },
      'turn': 'red',
      'dice': null,
      'winner': 'red',
    });
    expect(session.canRoll, isFalse);
  });

  test('the rolling flag locks the die even on my turn', () {
    final base = sessionFrom({
      'tokens': {
        'red': [-1, -1, -1, -1],
        'yellow': [-1, -1, -1, -1],
      },
      'turn': 'red',
      'phase': 'awaiting_roll',
      'dice': null,
    });
    // While the roll animation/request is in flight, canRoll is false.
    final rolling = GameSession(game: base.game, isRolling: true);
    expect(base.canRoll, isTrue);
    expect(rolling.canRoll, isFalse);
  });
}
