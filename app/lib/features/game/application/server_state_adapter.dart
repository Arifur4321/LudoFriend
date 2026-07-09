import '../../../game_engine/models/game_player.dart';
import '../../../game_engine/models/game_state.dart';
import '../../../game_engine/models/game_status.dart';
import '../../../game_engine/models/ludo_color.dart';
import '../../../game_engine/models/token.dart';
import '../../../game_engine/rules/rule_config.dart';

/// Translates the backend's compact authoritative match snapshot into the
/// client's rich [GameState].
///
/// The server stores state as
/// `{ tokens: { 'red':[p,p,p,p], ... }, turn: 'red', dice: int|null, status,
/// winner }` where positions use the shared **relative** convention (-1 base …
/// 56 home) — identical to [Token.position]. This is a pure function so it is
/// trivially unit-testable (see test/game_engine/server_state_adapter_test.dart).
class ServerStateAdapter {
  const ServerStateAdapter._();

  static GameState toGameState({
    required Map<String, dynamic> serverState,
    required List<GamePlayer> players,
    RuleConfig rules = const RuleConfig(),
    List<String> movableTokenIds = const [],
  }) {
    final tokensMap = (serverState['tokens'] as Map?)?.cast<String, dynamic>() ??
        const <String, dynamic>{};

    final tokens = <Token>[];
    for (final player in players) {
      final raw = tokensMap[player.color.id];
      final positions = raw is List ? raw : const [];
      for (var i = 0; i < positions.length; i++) {
        tokens.add(Token(
          color: player.color,
          index: i,
          position: (positions[i] as num).toInt(),
        ));
      }
    }

    final turnColor = serverState['turn'] as String?;
    var currentIndex = players.indexWhere((p) => p.color.id == turnColor);
    if (currentIndex < 0) currentIndex = 0;

    final rawDice = serverState['dice'];
    final dice = rawDice == null ? null : (rawDice as num).toInt();

    final serverStatus = serverState['status'] as String?;
    final winnerColor = serverState['winner'] as String?;

    final GameStatus status;
    if (serverStatus == 'finished' || winnerColor != null) {
      status = GameStatus.finished;
    } else if (dice != null && movableTokenIds.isNotEmpty) {
      status = GameStatus.awaitingMove;
    } else {
      status = GameStatus.waitingForRoll;
    }

    return GameState(
      players: players,
      tokens: tokens,
      currentPlayerIndex: currentIndex,
      rules: rules,
      lastDice: dice,
      status: status,
      winner:
          winnerColor == null ? null : LudoColor.fromId(winnerColor),
      pendingMovableTokenIds: movableTokenIds,
    );
  }

  /// Build token ids (`'red_2'`) from the server's `legal_moves` for [color].
  /// Accepts either a list of token indexes (`[0,2]`) or a list of maps that
  /// carry a `token`/`index` field — whichever the API returns.
  static List<String> movableIds(String color, dynamic legalMoves) {
    if (legalMoves is! List) return const [];
    final ids = <String>[];
    for (final m in legalMoves) {
      int? idx;
      if (m is num) {
        idx = m.toInt();
      } else if (m is Map) {
        final v = m['token'] ?? m['index'] ?? m['token_index'];
        if (v is num) idx = v.toInt();
      }
      if (idx != null) ids.add('${color}_$idx');
    }
    return ids;
  }
}
