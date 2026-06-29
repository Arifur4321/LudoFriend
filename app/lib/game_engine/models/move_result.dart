import 'ludo_color.dart';

/// Rich description of a single applied move — everything the UI needs to
/// animate it cell-by-cell, and everything the backend needs to log it.
class MoveResult {
  const MoveResult({
    required this.movedTokenId,
    required this.fromPosition,
    required this.toPosition,
    required this.path,
    required this.capturedTokenIds,
    required this.reachedHome,
    required this.grantsExtraTurn,
    this.winner,
  });

  final String movedTokenId;
  final int fromPosition;
  final int toPosition;

  /// Relative positions stepped through (excludes the start), for cell-by-cell
  /// movement animation.
  final List<int> path;

  final List<String> capturedTokenIds;
  final bool reachedHome;
  final bool grantsExtraTurn;
  final LudoColor? winner;

  bool get didCapture => capturedTokenIds.isNotEmpty;

  Map<String, dynamic> toJson() => {
        'movedTokenId': movedTokenId,
        'fromPosition': fromPosition,
        'toPosition': toPosition,
        'path': path,
        'capturedTokenIds': capturedTokenIds,
        'reachedHome': reachedHome,
        'grantsExtraTurn': grantsExtraTurn,
        'winner': winner?.name,
      };
}

/// Outcome of a dice roll before any token is moved.
class RollOutcome {
  const RollOutcome({
    required this.state,
    required this.dice,
    this.forfeited = false,
    this.noMove = false,
    this.grantsExtraTurn = false,
    this.movableTokenIds = const [],
  });

  /// The new game state after the roll has been recorded.
  final dynamic state; // GameState — kept dynamic to avoid an import cycle.
  final int dice;

  /// True when this was a third consecutive six and the turn was forfeited.
  final bool forfeited;

  /// True when no token could legally move with this dice.
  final bool noMove;

  final bool grantsExtraTurn;
  final List<String> movableTokenIds;
}
