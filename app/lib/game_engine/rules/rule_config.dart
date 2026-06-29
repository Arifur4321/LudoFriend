/// Immutable, serializable rule configuration for a Ludo match.
///
/// Every gameplay constant lives here so the engine has a single source of
/// truth, and the exact same config can be sent to — and re-validated by — the
/// Laravel backend (`config/ludo.php`) for server-authoritative online play.
class RuleConfig {
  const RuleConfig({
    this.leaveBaseOnlyOnSix = true,
    this.rollAgainOnSix = true,
    this.captureGrantsExtraTurn = true,
    this.reachingHomeGrantsExtraTurn = true,
    this.threeSixesForfeitsTurn = true,
    this.mustLandExactlyOnHome = true,
    this.maxConsecutiveSixes = 3,
    this.turnTimerSeconds = 20,
    this.safeCells = defaultSafeCells,
  });

  final bool leaveBaseOnlyOnSix;
  final bool rollAgainOnSix;
  final bool captureGrantsExtraTurn;
  final bool reachingHomeGrantsExtraTurn;
  final bool threeSixesForfeitsTurn;
  final bool mustLandExactlyOnHome;
  final int maxConsecutiveSixes;
  final int turnTimerSeconds;

  /// Absolute ring indices that cannot be captured on.
  /// 4 colored start cells + 4 star cells.
  final Set<int> safeCells;

  // --- board geometry constants (do not change without re-verifying) ---

  /// Number of cells in the shared perimeter ring.
  static const int ringSize = 52;

  /// Relative position meaning "finished / reached home".
  static const int homeIndex = 56;

  /// Last relative position that still sits on the shared ring.
  static const int lastRingRel = 50;

  /// Relative position of a token still inside its base/yard.
  static const int inBase = -1;

  static const int tokensPerPlayer = 4;

  static const Set<int> defaultSafeCells = {0, 8, 13, 21, 26, 34, 39, 47};

  RuleConfig copyWith({
    bool? leaveBaseOnlyOnSix,
    bool? rollAgainOnSix,
    bool? captureGrantsExtraTurn,
    bool? reachingHomeGrantsExtraTurn,
    bool? threeSixesForfeitsTurn,
    bool? mustLandExactlyOnHome,
    int? maxConsecutiveSixes,
    int? turnTimerSeconds,
    Set<int>? safeCells,
  }) {
    return RuleConfig(
      leaveBaseOnlyOnSix: leaveBaseOnlyOnSix ?? this.leaveBaseOnlyOnSix,
      rollAgainOnSix: rollAgainOnSix ?? this.rollAgainOnSix,
      captureGrantsExtraTurn:
          captureGrantsExtraTurn ?? this.captureGrantsExtraTurn,
      reachingHomeGrantsExtraTurn:
          reachingHomeGrantsExtraTurn ?? this.reachingHomeGrantsExtraTurn,
      threeSixesForfeitsTurn:
          threeSixesForfeitsTurn ?? this.threeSixesForfeitsTurn,
      mustLandExactlyOnHome:
          mustLandExactlyOnHome ?? this.mustLandExactlyOnHome,
      maxConsecutiveSixes: maxConsecutiveSixes ?? this.maxConsecutiveSixes,
      turnTimerSeconds: turnTimerSeconds ?? this.turnTimerSeconds,
      safeCells: safeCells ?? this.safeCells,
    );
  }

  Map<String, dynamic> toJson() => {
        'leaveBaseOnlyOnSix': leaveBaseOnlyOnSix,
        'rollAgainOnSix': rollAgainOnSix,
        'captureGrantsExtraTurn': captureGrantsExtraTurn,
        'reachingHomeGrantsExtraTurn': reachingHomeGrantsExtraTurn,
        'threeSixesForfeitsTurn': threeSixesForfeitsTurn,
        'mustLandExactlyOnHome': mustLandExactlyOnHome,
        'maxConsecutiveSixes': maxConsecutiveSixes,
        'turnTimerSeconds': turnTimerSeconds,
        'safeCells': safeCells.toList()..sort(),
      };

  factory RuleConfig.fromJson(Map<String, dynamic> j) => RuleConfig(
        leaveBaseOnlyOnSix: j['leaveBaseOnlyOnSix'] as bool? ?? true,
        rollAgainOnSix: j['rollAgainOnSix'] as bool? ?? true,
        captureGrantsExtraTurn: j['captureGrantsExtraTurn'] as bool? ?? true,
        reachingHomeGrantsExtraTurn:
            j['reachingHomeGrantsExtraTurn'] as bool? ?? true,
        threeSixesForfeitsTurn: j['threeSixesForfeitsTurn'] as bool? ?? true,
        mustLandExactlyOnHome: j['mustLandExactlyOnHome'] as bool? ?? true,
        maxConsecutiveSixes: j['maxConsecutiveSixes'] as int? ?? 3,
        turnTimerSeconds: j['turnTimerSeconds'] as int? ?? 20,
        safeCells: (j['safeCells'] as List?)?.map((e) => e as int).toSet() ??
            defaultSafeCells,
      );
}
