/// Aggregate player stats shown on the profile screen (mirrors the backend
/// `GET /profile/stats` payload).
class ProfileStats {
  const ProfileStats({
    this.matchesPlayed = 0,
    this.wins = 0,
    this.losses = 0,
    this.winRate = 0,
    this.bestStreak = 0,
    this.coins = 0,
  });

  final int matchesPlayed;
  final int wins;
  final int losses;
  final double winRate; // 0..1
  final int bestStreak;
  final int coins;

  static const empty = ProfileStats();

  factory ProfileStats.fromJson(Map<String, dynamic> j) => ProfileStats(
        matchesPlayed: (j['matches_played'] as num?)?.toInt() ?? 0,
        wins: (j['wins'] as num?)?.toInt() ?? 0,
        losses: (j['losses'] as num?)?.toInt() ?? 0,
        winRate: (j['win_rate'] as num?)?.toDouble() ?? 0,
        bestStreak: (j['best_streak'] as num?)?.toInt() ?? 0,
        coins: (j['coins'] as num?)?.toInt() ?? 0,
      );

  /// Display label, e.g. "50%" or "—" when no matches have been played.
  String get winRateLabel =>
      matchesPlayed > 0 ? '${(winRate * 100).round()}%' : '—';
}
