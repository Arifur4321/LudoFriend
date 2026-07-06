/// Free-spin availability + the wheel layout returned by the API.
class SpinStatus {
  const SpinStatus({
    required this.enabled,
    required this.canSpin,
    required this.rewards,
    this.nextAvailableAt,
    this.lastReward,
    this.intervalMinutes = 60,
  });

  final bool enabled;
  final bool canSpin;

  /// Reward value of each wheel segment, in display order.
  final List<int> rewards;
  final DateTime? nextAvailableAt;
  final int? lastReward;

  /// Cooldown between free spins, in minutes.
  final int intervalMinutes;

  factory SpinStatus.fromJson(Map<String, dynamic> j) {
    final segs = (j['segments'] ?? const []) as List;
    return SpinStatus(
      enabled: j['enabled'] as bool? ?? true,
      canSpin: j['can_spin'] as bool? ?? false,
      rewards: segs
          .whereType<Map>()
          .map((e) => (e['reward'] as num?)?.toInt() ?? 0)
          .toList(),
      nextAvailableAt: j['next_available_at'] != null
          ? DateTime.tryParse('${j['next_available_at']}')
          : null,
      lastReward: (j['last_reward'] as num?)?.toInt(),
      intervalMinutes: (j['interval_minutes'] as num?)?.toInt() ?? 60,
    );
  }

  SpinStatus copyWith({bool? canSpin, DateTime? nextAvailableAt, int? lastReward}) =>
      SpinStatus(
        enabled: enabled,
        canSpin: canSpin ?? this.canSpin,
        rewards: rewards,
        nextAvailableAt: nextAvailableAt ?? this.nextAvailableAt,
        lastReward: lastReward ?? this.lastReward,
        intervalMinutes: intervalMinutes,
      );
}

/// The server-decided outcome of a spin.
class SpinResult {
  const SpinResult({
    required this.reward,
    required this.segmentIndex,
    required this.balance,
    this.nextAvailableAt,
  });

  final int reward;
  final int segmentIndex;
  final int balance;

  /// When the next free spin unlocks (rolling cooldown).
  final DateTime? nextAvailableAt;

  factory SpinResult.fromJson(Map<String, dynamic> j) => SpinResult(
        reward: (j['reward'] as num?)?.toInt() ?? 0,
        segmentIndex: (j['segment_index'] as num?)?.toInt() ?? 0,
        balance: (j['balance'] as num?)?.toInt() ?? 0,
        nextAvailableAt: j['next_available_at'] != null
            ? DateTime.tryParse('${j['next_available_at']}')
            : null,
      );
}
