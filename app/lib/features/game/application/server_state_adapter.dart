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
    final tokensMap =
        (serverState['tokens'] as Map?)?.cast<String, dynamic>() ??
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

    final serverPhase = serverState['phase'] as String?;
    final serverStatus = serverState['status'] as String?;
    final winnerColor = serverState['winner'] as String?;

    final GameStatus status;
    if (serverStatus == 'finished' || winnerColor != null) {
      status = GameStatus.finished;
    } else if (serverPhase == 'awaiting_move' ||
        (dice != null && movableTokenIds.isNotEmpty)) {
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
      winner: winnerColor == null ? null : LudoColor.fromId(winnerColor),
      pendingMovableTokenIds: movableTokenIds,
    );
  }

  /// Build token ids (`'red_2'`) from the server's `legal_moves` for [color].
  /// Accepts either a list of token indexes (`[0,2]`) or a list of maps that
  /// carry a `token`/`index` field — whichever the API returns. A map-shaped
  /// list (PHP serializes a non-sequential array as an object) and stringly
  /// typed indexes are tolerated too, so a transport quirk can never silently
  /// strip a legal move.
  static List<String> movableIds(String color, dynamic legalMoves) {
    final entries = legalMoves is List
        ? legalMoves
        : (legalMoves is Map ? legalMoves.values.toList() : const []);
    final ids = <String>[];
    for (final m in entries) {
      int? idx;
      if (m is num) {
        idx = m.toInt();
      } else if (m is String) {
        idx = int.tryParse(m);
      } else if (m is Map) {
        final v = m['token'] ?? m['index'] ?? m['token_index'];
        if (v is num) {
          idx = v.toInt();
        } else if (v is String) {
          idx = int.tryParse(v);
        }
      }
      if (idx != null) ids.add('${color}_$idx');
    }
    return ids;
  }

  /// Recompute the movable token ids for the pending roll directly from the
  /// authoritative snapshot (`turn` + `dice` + `tokens`), mirroring the
  /// backend's `LudoRules::legalMoves` exactly (leave-base-on-six, no
  /// overshooting home, no landing on your own token; home may be shared).
  ///
  /// This is the safety net for a payload whose `legal_moves` was missing or
  /// unparseable: the phase says a move is pending, so the player must always
  /// be offered their legal tokens — a dice value of 1 included. The server
  /// still validates whichever token is actually picked.
  static List<String> movableFromState(
    Map<String, dynamic> serverState, {
    RuleConfig rules = const RuleConfig(),
  }) {
    if (serverState['phase'] != 'awaiting_move') return const [];
    final turn = serverState['turn'] as String?;
    final dice = (serverState['dice'] as num?)?.toInt();
    if (turn == null || dice == null) return const [];
    final tokensMap =
        (serverState['tokens'] as Map?)?.cast<String, dynamic>() ?? const {};
    final raw = tokensMap[turn];
    if (raw is! List) return const [];

    final positions = <int>[
      for (final p in raw)
        if (p is num) p.toInt()
    ];
    final ids = <String>[];
    for (var i = 0; i < positions.length; i++) {
      final rel = positions[i];
      if (!_canMoveRel(rel, dice, rules)) continue;
      final to = rel == RuleConfig.inBase ? 0 : rel + dice;
      // Own-token occupancy: the server disallows stacking on yourself
      // anywhere except the shared home slot (rel 56).
      if (to != RuleConfig.homeIndex) {
        var occupied = false;
        for (var j = 0; j < positions.length; j++) {
          if (j != i && positions[j] == to) {
            occupied = true;
            break;
          }
        }
        if (occupied) continue;
      }
      ids.add('${turn}_$i');
    }
    return ids;
  }

  static bool _canMoveRel(int rel, int dice, RuleConfig rules) {
    if (rel >= RuleConfig.homeIndex) return false; // finished — immovable.
    if (rel == RuleConfig.inBase) {
      return rules.leaveBaseOnlyOnSix ? dice == 6 : true;
    }
    return rel + dice <= RuleConfig.homeIndex; // must land exactly on home.
  }
}
