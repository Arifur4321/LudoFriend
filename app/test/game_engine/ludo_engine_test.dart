import 'package:flutter_test/flutter_test.dart';
import 'package:ludo_friends/game_engine/bot/easy_bot.dart';
import 'package:ludo_friends/game_engine/ludo_engine.dart';
import 'package:ludo_friends/game_engine/models/dice.dart';
import 'package:ludo_friends/game_engine/models/game_player.dart';
import 'package:ludo_friends/game_engine/models/game_state.dart';
import 'package:ludo_friends/game_engine/models/game_status.dart';
import 'package:ludo_friends/game_engine/models/ludo_color.dart';
import 'package:ludo_friends/game_engine/models/token.dart';

GamePlayer _p(LudoColor c, {PlayerKind kind = PlayerKind.human}) =>
    GamePlayer(color: c, name: c.name, kind: kind);

/// Builds a state with explicit token positions for targeted scenarios.
GameState _stateWith(
  List<GamePlayer> players,
  Map<String, int> positions, {
  int current = 0,
  int? dice,
  int consecutiveSixes = 0,
  GameStatus status = GameStatus.waitingForRoll,
  List<String> movable = const [],
}) {
  final tokens = <Token>[];
  for (final pl in players) {
    for (var i = 0; i < 4; i++) {
      final id = '${pl.color.name}_$i';
      tokens
          .add(Token(color: pl.color, index: i, position: positions[id] ?? -1));
    }
  }
  return GameState(
    players: players,
    tokens: tokens,
    currentPlayerIndex: current,
    lastDice: dice,
    consecutiveSixes: consecutiveSixes,
    status: status,
    pendingMovableTokenIds: movable,
  );
}

void main() {
  const engine = LudoEngine();
  final four = [
    _p(LudoColor.red),
    _p(LudoColor.green),
    _p(LudoColor.yellow),
    _p(LudoColor.blue),
  ];

  group('leaving base', () {
    test('a token can leave base only on a 6', () {
      final s = LudoEngine.newGame(players: four);
      expect(engine.movableTokens(s, LudoColor.red, 5), isEmpty);
      expect(engine.movableTokens(s, LudoColor.red, 6).length, 4);
    });

    test('rolling a non-6 with everything in base passes the turn', () {
      final s = LudoEngine.newGame(players: four);
      final r = engine.applyRoll(s, 3);
      expect(r.noMove, isTrue);
      expect(r.state.currentPlayerIndex, 1); // turn advanced to green
    });

    test('launching a token from base places it on the start cell', () {
      var s = LudoEngine.newGame(players: four);
      final r = engine.applyRoll(s, 6);
      s = r.state;
      final m = engine.applyMove(s, 'red_0');
      expect(m.state.tokenById('red_0').position, 0);
    });
  });

  group('extra turns', () {
    test('rolling a 6 grants another turn (same player)', () {
      final s = _stateWith(four, {'red_0': 1},
          current: 0,
          dice: 6,
          status: GameStatus.awaitingMove,
          movable: ['red_0']);
      final m = engine.applyMove(s, 'red_0');
      expect(m.result.grantsExtraTurn, isTrue);
      expect(m.state.currentPlayerIndex, 0);
      expect(m.state.status, GameStatus.waitingForRoll);
    });

    test('a non-6 with no capture or home passes the turn', () {
      final s = _stateWith(four, {'red_0': 1},
          current: 0,
          dice: 3,
          status: GameStatus.awaitingMove,
          movable: ['red_0']);
      final m = engine.applyMove(s, 'red_0');
      expect(m.result.grantsExtraTurn, isFalse);
      expect(m.state.currentPlayerIndex, 1);
    });
  });

  group('three consecutive sixes', () {
    test('the third six is forfeited and the turn passes', () {
      // two sixes already banked this turn; red has a launched token.
      final s = _stateWith(four, {'red_0': 0}, current: 0, consecutiveSixes: 2);
      final r = engine.applyRoll(s, 6);
      expect(r.forfeited, isTrue);
      expect(r.state.currentPlayerIndex, 1);
      expect(r.state.consecutiveSixes, 0);
    });

    test('first and second six do not forfeit', () {
      final s = _stateWith(four, {'red_0': 0}, current: 0, consecutiveSixes: 1);
      final r = engine.applyRoll(s, 6);
      expect(r.forfeited, isFalse);
      expect(r.state.consecutiveSixes, 2);
    });
  });

  group('capturing', () {
    test('landing on an opponent off a safe cell sends it home', () {
      // red_0 sits on absolute cell 10 (not safe); green_0 lands there.
      final s = _stateWith(four, {'red_0': 10, 'green_0': 46},
          current: 1,
          dice: 3,
          status: GameStatus.awaitingMove,
          movable: ['green_0']);
      final m = engine.applyMove(s, 'green_0');
      expect(m.result.capturedTokenIds, contains('red_0'));
      expect(m.result.capturedFromPositions['red_0'], 10);
      expect(m.state.tokenById('red_0').isInBase, isTrue);
      expect(m.result.grantsExtraTurn, isTrue); // capture => extra turn
    });

    test('a token on a safe cell cannot be captured', () {
      // red_0 on absolute cell 8 (a safe star); green_0 lands there.
      final s = _stateWith(four, {'red_0': 8, 'green_0': 46},
          current: 1,
          dice: 1,
          status: GameStatus.awaitingMove,
          movable: ['green_0']);
      final m = engine.applyMove(s, 'green_0');
      expect(m.result.capturedTokenIds, isEmpty);
      expect(m.state.tokenById('red_0').position, 8);
    });

    test('no capture happens inside a home column', () {
      // both in home columns -> private, never collide.
      final s = _stateWith(four, {'red_0': 53, 'green_0': 53},
          current: 0,
          dice: 1,
          status: GameStatus.awaitingMove,
          movable: ['red_0']);
      final m = engine.applyMove(s, 'red_0');
      expect(m.result.capturedTokenIds, isEmpty);
    });
  });

  group('home path', () {
    test('a token must land exactly on home', () {
      final s = _stateWith(four, {'blue_0': 53}, current: 0);
      expect(engine.movableTokens(s, LudoColor.blue, 3),
          contains('blue_0')); // 53+3 = 56
      expect(
          engine.movableTokens(s, LudoColor.blue, 4), isEmpty); // 57 overshoots
    });

    test('reaching home grants an extra turn', () {
      final s = _stateWith(four, {'blue_0': 50},
          current: 3,
          dice: 6,
          status: GameStatus.awaitingMove,
          movable: ['blue_0']);
      final m = engine.applyMove(s, 'blue_0');
      expect(m.state.tokenById('blue_0').isFinished, isTrue);
      expect(m.result.reachedHome, isTrue);
      expect(m.result.grantsExtraTurn, isTrue);
    });
  });

  group('winning', () {
    test('a color wins when all four tokens are home', () {
      final s = _stateWith(
          four, {'red_0': 56, 'red_1': 56, 'red_2': 56, 'red_3': 50},
          current: 0,
          dice: 6,
          status: GameStatus.awaitingMove,
          movable: ['red_3']);
      final m = engine.applyMove(s, 'red_3');
      expect(m.result.winner, LudoColor.red);
      expect(m.state.status, GameStatus.finished);
      expect(engine.isWinner(m.state, LudoColor.red), isTrue);
    });
  });

  group('full games terminate (2p and 4p)', () {
    LudoColor playout(List<LudoColor> colors, int seed) {
      final players = colors.map((c) => _p(c, kind: PlayerKind.bot)).toList();
      var s = LudoEngine.newGame(players: players);
      final dice = DiceRoller(seed);
      const bot = EasyBot();
      var guard = 0;
      while (!s.isFinished && guard < 500000) {
        guard++;
        final r = engine.applyRoll(s, dice.roll());
        s = r.state;
        if (r.movable.isNotEmpty) {
          s = engine
              .applyMove(s, bot.chooseMove(s, s.lastDice!, r.movable))
              .state;
        }
      }
      expect(s.isFinished, isTrue, reason: 'game must finish (seed $seed)');
      return s.winner!;
    }

    test('4-player games always finish with a winner', () {
      for (var seed = 0; seed < 15; seed++) {
        final w = playout(LudoColor.fourPlayerColors, seed);
        expect(LudoColor.values, contains(w));
      }
    });

    test('2-player games always finish with a winner', () {
      for (var seed = 0; seed < 15; seed++) {
        final w = playout(LudoColor.twoPlayerColors, seed);
        expect(LudoColor.twoPlayerColors, contains(w));
      }
    });
  });
}
