import 'dart:math';

/// Seedable dice roller.
///
/// Kept deliberately separate from the (pure, deterministic) [LudoEngine] so
/// games can be made fully reproducible in tests by injecting a seed or by
/// feeding fixed dice values straight into the engine.
class DiceRoller {
  DiceRoller([int? seed]) : _rng = Random(seed);

  final Random _rng;

  /// Returns a value in 1..6 inclusive.
  int roll() => _rng.nextInt(6) + 1;
}
