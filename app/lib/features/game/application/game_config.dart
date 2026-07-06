import '../../../game_engine/models/game_player.dart';
import '../../../game_engine/models/ludo_color.dart';
import '../../../game_engine/rules/rule_config.dart';

enum GameMode { passAndPlay, vsBot, online }

/// Everything needed to start a match. Built by the play-options / room flow and
/// handed to the [GameController].
class GameConfig {
  const GameConfig({
    required this.mode,
    required this.players,
    this.rules = const RuleConfig(),
    this.seed,
    this.autoMoveSingle = true,
    this.matchId,
    this.boardThemeKey = 'classic',
    this.stake = 0,
    this.teamMode = false,
  });

  final GameMode mode;
  final List<GamePlayer> players;
  final RuleConfig rules;
  final int? seed;

  /// Auto-play the only legal move for snappier turns (offline only).
  final bool autoMoveSingle;

  /// Backend match id for online games.
  final String? matchId;

  /// Which board tier's visual theme to render (see [BoardTheme]).
  final String boardThemeKey;

  /// Per-seat coin stake (0 for casual/practice). Enforced server-side.
  final int stake;

  /// 2v2 team play (4-player boards only).
  final bool teamMode;

  bool get isOnline => mode == GameMode.online;

  /// Convenience builder for a quick local game.
  static GameConfig local({
    required int humans,
    required int bots,
    List<String>? names,
    RuleConfig rules = const RuleConfig(),
    int? seed,
    String boardThemeKey = 'classic',
    bool teamMode = false,
  }) {
    final total = humans + bots;
    assert(total == 2 || total == 4, 'Ludo needs 2 or 4 seats');
    final colors =
        total == 2 ? LudoColor.twoPlayerColors : LudoColor.fourPlayerColors;
    final players = <GamePlayer>[];
    for (var i = 0; i < total; i++) {
      final isBot = i >= humans;
      players.add(GamePlayer(
        color: colors[i],
        name: names != null && i < names.length
            ? names[i]
            : isBot
                ? 'Bot ${i - humans + 1}'
                : 'Player ${i + 1}',
        kind: isBot ? PlayerKind.bot : PlayerKind.human,
      ));
    }
    return GameConfig(
      mode: bots > 0 && humans <= 1 ? GameMode.vsBot : GameMode.passAndPlay,
      players: players,
      rules: rules,
      seed: seed,
      boardThemeKey: boardThemeKey,
      teamMode: teamMode,
    );
  }
}
