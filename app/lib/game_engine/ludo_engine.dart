import 'models/game_player.dart';
import 'models/game_state.dart';
import 'models/game_status.dart';
import 'models/ludo_color.dart';
import 'models/move_result.dart';
import 'models/token.dart';
import 'rules/rule_config.dart';

/// Typed return of [LudoEngine.applyRoll].
typedef RollResult = ({
  GameState state,
  int dice,
  bool forfeited,
  bool noMove,
  bool extraTurn,
  List<String> movable,
});

/// Typed return of [LudoEngine.applyMove].
typedef MoveApplication = ({GameState state, MoveResult result});

/// The pure, deterministic Ludo rules engine.
///
/// It contains **no** randomness, timers, or Flutter dependencies: every method
/// takes an immutable [GameState] and returns a new one. Dice values are fed in
/// from the outside ([DiceRoller] in the app, fixed values in tests, or the
/// server in online play). This is the exact logic verified before porting and
/// mirrored by the backend's `LudoRules` for server-authoritative validation.
class LudoEngine {
  const LudoEngine();

  /// Builds a fresh match for 2 or 4 [players].
  static GameState newGame({
    required List<GamePlayer> players,
    RuleConfig rules = const RuleConfig(),
  }) {
    assert(players.length == 2 || players.length == 4,
        'Ludo supports exactly 2 or 4 players');
    final tokens = <Token>[];
    for (final p in players) {
      for (var i = 0; i < RuleConfig.tokensPerPlayer; i++) {
        tokens.add(Token(color: p.color, index: i));
      }
    }
    return GameState(
      players: players,
      tokens: tokens,
      currentPlayerIndex: 0,
      rules: rules,
    );
  }

  /// Token ids of [color] that can legally move with [dice].
  List<String> movableTokens(GameState s, LudoColor color, int dice) {
    final out = <String>[];
    for (final t in s.tokensOf(color)) {
      if (_canMove(t, dice, s.rules)) out.add(t.id);
    }
    return out;
  }

  bool _canMove(Token t, int dice, RuleConfig rules) {
    if (t.isInBase) {
      return rules.leaveBaseOnlyOnSix ? dice == 6 : true;
    }
    if (t.isFinished) return false;
    final next = t.position + dice;
    // Must land exactly on home (no overshoot).
    return next <= RuleConfig.homeIndex;
  }

  /// Records a dice [dice] for the current player and computes what happens
  /// next: a forfeit (third six), no legal move, or a set of movable tokens.
  RollResult applyRoll(GameState s, int dice) {
    final rules = s.rules;
    var consec = s.consecutiveSixes;
    if (dice == 6) consec += 1;

    // Third consecutive six → forfeit this roll and pass the turn.
    if (dice == 6 &&
        rules.threeSixesForfeitsTurn &&
        consec >= rules.maxConsecutiveSixes) {
      final ns = _advanceTurn(s.copyWith(
        consecutiveSixes: 0,
        pendingMovableTokenIds: const [],
      ));
      return (
        state: ns,
        dice: dice,
        forfeited: true,
        noMove: false,
        extraTurn: false,
        movable: const <String>[]
      );
    }

    final movable = movableTokens(s, s.currentColor, dice);

    if (movable.isEmpty) {
      final extra = dice == 6 && rules.rollAgainOnSix;
      final ns = extra
          ? s.copyWith(
              consecutiveSixes: consec,
              status: GameStatus.waitingForRoll,
              clearDice: true,
              pendingMovableTokenIds: const [],
            )
          : _advanceTurn(s.copyWith(
              consecutiveSixes: 0,
              pendingMovableTokenIds: const [],
            ));
      return (
        state: ns,
        dice: dice,
        forfeited: false,
        noMove: true,
        extraTurn: extra,
        movable: const <String>[]
      );
    }

    final ns = s.copyWith(
      consecutiveSixes: consec,
      lastDice: dice,
      status: GameStatus.awaitingMove,
      pendingMovableTokenIds: movable,
    );
    return (
      state: ns,
      dice: dice,
      forfeited: false,
      noMove: false,
      extraTurn: false,
      movable: movable
    );
  }

  /// Applies the current dice to the token [tokenId]. The caller must ensure
  /// [tokenId] is in `state.pendingMovableTokenIds`.
  MoveApplication applyMove(GameState s, String tokenId) {
    final rules = s.rules;
    final dice = s.lastDice!;
    final tokens = s.cloneTokens().toList(growable: false);
    final t = tokens.firstWhere((x) => x.id == tokenId);
    final from = t.position;

    // Build the cell-by-cell path for the UI to animate.
    final path = <int>[];
    if (t.isInBase) {
      t.position = 0;
      path.add(0);
    } else {
      for (var p = from + 1; p <= from + dice; p++) {
        path.add(p);
      }
      t.position = from + dice;
    }

    // Capture: only on the shared ring and only off safe cells.
    final captured = <String>[];
    final capturedFrom = <String, int>{};
    final landedAbs = t.absoluteCell();
    if (landedAbs != null && !rules.safeCells.contains(landedAbs)) {
      for (final o in tokens) {
        if (o.color != t.color && o.isOnRing && o.absoluteCell() == landedAbs) {
          capturedFrom[o.id] = o.position;
          o.position = RuleConfig.inBase;
          captured.add(o.id);
        }
      }
    }

    final reachedHome = t.position == RuleConfig.homeIndex;
    final hasWon =
        tokens.where((x) => x.color == t.color).every((x) => x.isFinished);
    final winner = hasWon ? t.color : null;

    final extra = (dice == 6 && rules.rollAgainOnSix) ||
        (captured.isNotEmpty && rules.captureGrantsExtraTurn) ||
        (reachedHome && rules.reachingHomeGrantsExtraTurn);

    final GameState ns;
    if (winner != null) {
      ns = s.copyWith(
        tokens: tokens,
        status: GameStatus.finished,
        winner: winner,
        consecutiveSixes: 0,
        clearDice: true,
        pendingMovableTokenIds: const [],
      );
    } else if (extra) {
      ns = s.copyWith(
        tokens: tokens,
        status: GameStatus.waitingForRoll,
        // Keep the six-counter alive only when the extra turn came from a six.
        consecutiveSixes: dice == 6 ? s.consecutiveSixes : 0,
        clearDice: true,
        pendingMovableTokenIds: const [],
      );
    } else {
      ns = _advanceTurn(s.copyWith(
        tokens: tokens,
        consecutiveSixes: 0,
        pendingMovableTokenIds: const [],
      ));
    }

    final result = MoveResult(
      movedTokenId: tokenId,
      fromPosition: from,
      toPosition: t.position,
      path: path,
      capturedTokenIds: captured,
      capturedFromPositions: capturedFrom,
      reachedHome: reachedHome,
      grantsExtraTurn: winner == null && extra,
      winner: winner,
    );
    return (state: ns, result: result);
  }

  GameState _advanceTurn(GameState s) {
    final next = (s.currentPlayerIndex + 1) % s.players.length;
    return s.copyWith(
      currentPlayerIndex: next,
      status: GameStatus.waitingForRoll,
      clearDice: true,
      turnCount: s.turnCount + 1,
    );
  }

  bool isWinner(GameState s, LudoColor color) =>
      s.tokensOf(color).every((t) => t.isFinished);
}
