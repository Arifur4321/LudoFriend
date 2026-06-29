/// High-level phase of a match, used to drive the UI state machine.
enum GameStatus {
  /// Current player must roll the dice.
  waitingForRoll,

  /// Dice rolled; current player must pick a movable token.
  awaitingMove,

  /// An animation (dice or token movement) is playing.
  animating,

  /// A winner has been decided.
  finished,
}
