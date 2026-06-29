import 'package:flutter_test/flutter_test.dart';
import 'package:ludo_friends/game_engine/ludo_engine.dart';
import 'package:ludo_friends/game_engine/models/game_player.dart';
import 'package:ludo_friends/game_engine/models/game_state.dart';
import 'package:ludo_friends/game_engine/models/ludo_color.dart';
import 'package:ludo_friends/game_engine/rules/rule_config.dart';

void main() {
  test('GameState survives a JSON round-trip', () {
    final players = [
      const GamePlayer(color: LudoColor.red, name: 'You'),
      const GamePlayer(
          color: LudoColor.yellow, name: 'Bot', kind: PlayerKind.bot),
    ];
    var s = LudoEngine.newGame(players: players);
    // Advance a couple of moves so positions/dice/turn differ from defaults.
    const engine = LudoEngine();
    s = engine.applyRoll(s, 6).state;
    s = engine.applyMove(s, 'red_0').state;

    final json = s.toJson();
    final restored = GameState.fromJson(json);

    expect(restored.players.length, s.players.length);
    expect(restored.currentPlayerIndex, s.currentPlayerIndex);
    expect(restored.status, s.status);
    expect(restored.tokenById('red_0').position, s.tokenById('red_0').position);
    expect(restored.toJson(), s.toJson());
  });

  test('RuleConfig round-trips and keeps safe cells', () {
    const cfg = RuleConfig(turnTimerSeconds: 30, rollAgainOnSix: false);
    final restored = RuleConfig.fromJson(cfg.toJson());
    expect(restored.turnTimerSeconds, 30);
    expect(restored.rollAgainOnSix, isFalse);
    expect(restored.safeCells, RuleConfig.defaultSafeCells);
  });
}
