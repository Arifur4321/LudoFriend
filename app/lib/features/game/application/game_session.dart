import '../../../game_engine/models/game_state.dart';
import '../../../game_engine/models/move_result.dart';

/// UI-facing snapshot of a match: the pure [GameState] plus transient flags the
/// widgets need to drive animations (dice rolling, token moving, banners).
class GameSession {
  const GameSession({
    required this.game,
    this.isRolling = false,
    this.isMoving = false,
    this.diceFace,
    this.lastMove,
    this.banner,
  });

  final GameState game;
  final bool isRolling;
  final bool isMoving;
  final int? diceFace;
  final MoveResult? lastMove;

  /// Short transient message, e.g. "No moves" / "Captured!".
  final String? banner;

  bool get isBusy => isRolling || isMoving;

  /// The local human may tap the dice now.
  bool get canRoll =>
      !isBusy &&
      !game.isFinished &&
      game.status.name == 'waitingForRoll' &&
      game.currentPlayer.isHuman;

  GameSession copyWith({
    GameState? game,
    bool? isRolling,
    bool? isMoving,
    int? diceFace,
    Object? lastMove = _sentinel,
    Object? banner = _sentinel,
  }) {
    return GameSession(
      game: game ?? this.game,
      isRolling: isRolling ?? this.isRolling,
      isMoving: isMoving ?? this.isMoving,
      diceFace: diceFace ?? this.diceFace,
      lastMove: lastMove == _sentinel ? this.lastMove : lastMove as MoveResult?,
      banner: banner == _sentinel ? this.banner : banner as String?,
    );
  }

  static const Object _sentinel = Object();
}
