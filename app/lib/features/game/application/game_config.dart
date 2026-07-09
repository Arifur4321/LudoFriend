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
    this.myColor,
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

  /// The local player's color for online games (whose dice/tokens are tappable).
  final String? myColor;

  /// Which board tier's visual theme to render (see [BoardTheme]).
  final String boardThemeKey;

  /// Per-seat coin stake (0 for casual/practice). Enforced server-side.
  final int stake;

  /// 2v2 team play (4-player boards only).
  final bool teamMode;

  bool get isOnline => mode == GameMode.online;

  /// Convenience builder for a quick local game. When [meName] is supplied the
  /// first human seat represents the signed-in user, so their name and (for
  /// non-guests) their profile photo appear on the board; guests get an SVG.
  static GameConfig local({
    required int humans,
    required int bots,
    List<String>? names,
    RuleConfig rules = const RuleConfig(),
    int? seed,
    String boardThemeKey = 'classic',
    bool teamMode = false,
    String? meName,
    String? meAvatarUrl,
    bool meIsGuest = false,
  }) {
    final total = humans + bots;
    assert(total == 2 || total == 4, 'Ludo needs 2 or 4 seats');
    final colors =
        total == 2 ? LudoColor.twoPlayerColors : LudoColor.fourPlayerColors;
    final players = <GamePlayer>[];
    for (var i = 0; i < total; i++) {
      final isBot = i >= humans;
      final isMe = i == 0 && !isBot;
      players.add(GamePlayer(
        color: colors[i],
        name: isMe && meName != null && meName.isNotEmpty
            ? meName
            : names != null && i < names.length
                ? names[i]
                : isBot
                    ? 'Bot ${i - humans + 1}'
                    : 'Player ${i + 1}',
        kind: isBot ? PlayerKind.bot : PlayerKind.human,
        avatarUrl: isMe ? meAvatarUrl : null,
        isGuest: isMe ? meIsGuest : false,
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

  /// Build an online match config from the backend match `players` payload (each
  /// entry: `{user_id, name, avatar, is_guest, color, is_bot}`). The seat whose
  /// color is [myColor] is promoted to human so its dice/tokens are tappable
  /// locally; all other seats are remote.
  static GameConfig online({
    required String matchId,
    required List<Map<String, dynamic>> serverPlayers,
    required String? myColor,
    RuleConfig rules = const RuleConfig(),
    String boardThemeKey = 'classic',
    int stake = 0,
    bool teamMode = false,
  }) {
    final players = serverPlayers.map(GamePlayer.fromServer).map((p) {
      final mine = myColor != null && p.color.id == myColor && !p.isBot;
      return mine ? p.copyWith(kind: PlayerKind.human) : p;
    }).toList(growable: false);

    return GameConfig(
      mode: GameMode.online,
      players: players,
      rules: rules,
      matchId: matchId,
      myColor: myColor,
      boardThemeKey: boardThemeKey,
      stake: stake,
      teamMode: teamMode,
      autoMoveSingle: false,
    );
  }
}
