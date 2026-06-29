import '../rules/rule_config.dart';
import 'game_player.dart';
import 'game_status.dart';
import 'ludo_color.dart';
import 'token.dart';

/// The complete, serializable state of a Ludo match.
///
/// Treated as immutable by the engine: every transition produces a new
/// [GameState] via [copyWith] with freshly-cloned tokens, which makes the
/// engine trivial to test and safe to diff/animate against in the UI.
class GameState {
  GameState({
    required this.players,
    required this.tokens,
    required this.currentPlayerIndex,
    this.rules = const RuleConfig(),
    this.lastDice,
    this.consecutiveSixes = 0,
    this.status = GameStatus.waitingForRoll,
    this.winner,
    this.pendingMovableTokenIds = const [],
    this.turnCount = 0,
  });

  final List<GamePlayer> players;
  final List<Token> tokens;
  final int currentPlayerIndex;
  final RuleConfig rules;
  final int? lastDice;
  final int consecutiveSixes;
  final GameStatus status;
  final LudoColor? winner;
  final List<String> pendingMovableTokenIds;
  final int turnCount;

  GamePlayer get currentPlayer => players[currentPlayerIndex];
  LudoColor get currentColor => currentPlayer.color;
  bool get isFinished => status == GameStatus.finished;

  List<Token> tokensOf(LudoColor c) =>
      tokens.where((t) => t.color == c).toList(growable: false);

  Token tokenById(String id) => tokens.firstWhere((t) => t.id == id);

  /// Deep copy of the token list so callers can mutate freely.
  List<Token> cloneTokens() =>
      tokens.map((t) => t.copy()).toList(growable: false);

  GameState copyWith({
    List<GamePlayer>? players,
    List<Token>? tokens,
    int? currentPlayerIndex,
    RuleConfig? rules,
    int? lastDice,
    bool clearDice = false,
    int? consecutiveSixes,
    GameStatus? status,
    LudoColor? winner,
    List<String>? pendingMovableTokenIds,
    int? turnCount,
  }) {
    return GameState(
      players: players ?? this.players,
      tokens: tokens ?? this.tokens,
      currentPlayerIndex: currentPlayerIndex ?? this.currentPlayerIndex,
      rules: rules ?? this.rules,
      lastDice: clearDice ? null : (lastDice ?? this.lastDice),
      consecutiveSixes: consecutiveSixes ?? this.consecutiveSixes,
      status: status ?? this.status,
      winner: winner ?? this.winner,
      pendingMovableTokenIds:
          pendingMovableTokenIds ?? this.pendingMovableTokenIds,
      turnCount: turnCount ?? this.turnCount,
    );
  }

  Map<String, dynamic> toJson() => {
        'players': players.map((p) => p.toJson()).toList(),
        'tokens': tokens.map((t) => t.toJson()).toList(),
        'currentPlayerIndex': currentPlayerIndex,
        'rules': rules.toJson(),
        'lastDice': lastDice,
        'consecutiveSixes': consecutiveSixes,
        'status': status.name,
        'winner': winner?.name,
        'pendingMovableTokenIds': pendingMovableTokenIds,
        'turnCount': turnCount,
      };

  factory GameState.fromJson(Map<String, dynamic> j) => GameState(
        players: (j['players'] as List)
            .map((e) => GamePlayer.fromJson(e as Map<String, dynamic>))
            .toList(),
        tokens: (j['tokens'] as List)
            .map((e) => Token.fromJson(e as Map<String, dynamic>))
            .toList(),
        currentPlayerIndex: j['currentPlayerIndex'] as int,
        rules: RuleConfig.fromJson(j['rules'] as Map<String, dynamic>),
        lastDice: j['lastDice'] as int?,
        consecutiveSixes: j['consecutiveSixes'] as int? ?? 0,
        status: GameStatus.values.firstWhere((s) => s.name == j['status'],
            orElse: () => GameStatus.waitingForRoll),
        winner: j['winner'] == null
            ? null
            : LudoColor.fromId(j['winner'] as String),
        pendingMovableTokenIds:
            (j['pendingMovableTokenIds'] as List?)?.cast<String>() ?? const [],
        turnCount: j['turnCount'] as int? ?? 0,
      );
}
