import 'package:flutter_test/flutter_test.dart';
import 'package:ludo_friends/game_engine/bot/easy_bot.dart';
import 'package:ludo_friends/game_engine/ludo_engine.dart';
import 'package:ludo_friends/game_engine/models/game_player.dart';
import 'package:ludo_friends/game_engine/models/game_state.dart';
import 'package:ludo_friends/game_engine/models/game_status.dart';
import 'package:ludo_friends/game_engine/models/ludo_color.dart';
import 'package:ludo_friends/game_engine/models/token.dart';

GameState _stateWith(Map<String, int> positions,
    {int current = 0,
    int? dice,
    List<String> movable = const [],
    GameStatus status = GameStatus.awaitingMove}) {
  const colors = LudoColor.fourPlayerColors;
  final players = colors
      .map((c) => GamePlayer(color: c, name: c.name, kind: PlayerKind.bot))
      .toList();
  final tokens = <Token>[];
  for (final c in colors) {
    for (var i = 0; i < 4; i++) {
      tokens.add(
          Token(color: c, index: i, position: positions['${c.name}_$i'] ?? -1));
    }
  }
  return GameState(
    players: players,
    tokens: tokens,
    currentPlayerIndex: current,
    lastDice: dice,
    status: status,
    pendingMovableTokenIds: movable,
  );
}

void main() {
  const bot = EasyBot();
  const engine = LudoEngine();

  test('bot always returns a legally movable token', () {
    var s = LudoEngine.newGame(players: [
      const GamePlayer(color: LudoColor.red, name: 'r', kind: PlayerKind.bot),
      const GamePlayer(
          color: LudoColor.yellow, name: 'y', kind: PlayerKind.bot),
    ]);
    s = engine.applyRoll(s, 6).state;
    final choice = bot.chooseMove(s, 6, s.pendingMovableTokenIds);
    expect(s.pendingMovableTokenIds, contains(choice));
  });

  test('bot prefers a capture when available', () {
    // green can either advance green_1 or capture red_0 (abs 10) with green_0.
    final s = _stateWith(
      {'red_0': 10, 'green_0': 46, 'green_1': 5},
      current: 1,
      dice: 3,
      movable: ['green_0', 'green_1'],
    );
    expect(bot.chooseMove(s, 3, ['green_0', 'green_1']), 'green_0');
  });

  test('bot launches from base when that is the sensible option', () {
    final s = _stateWith(
      {'red_0': -1, 'red_1': 20},
      current: 0,
      dice: 6,
      movable: ['red_0', 'red_1'],
    );
    // With a 6 and no capture/home available, launching is prioritised.
    expect(bot.chooseMove(s, 6, ['red_0', 'red_1']), 'red_0');
  });
}
