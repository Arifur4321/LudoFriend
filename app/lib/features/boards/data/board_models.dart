/// A staked board tier as surfaced to the client. When the API is unreachable
/// (offline / guest without a token) the [fallback] list keeps the six boards
/// visible and playable as themed practice.
class BoardTier {
  const BoardTier({
    required this.key,
    required this.name,
    required this.stake,
    required this.order,
    this.modes = const ['2p', '4p'],
    this.team = true,
    this.badge,
    this.description,
    this.affordable = true,
  });

  final String key;
  final String name;
  final int stake;
  final int order;
  final List<String> modes;
  final bool team;
  final String? badge;
  final String? description;
  final bool affordable;

  bool get supportsFour => modes.contains('4p');

  factory BoardTier.fromJson(Map<String, dynamic> j) => BoardTier(
        key: j['key'] as String? ?? 'classic',
        name: j['name'] as String? ?? 'Board',
        stake: (j['stake'] as num?)?.toInt() ?? 0,
        order: (j['order'] as num?)?.toInt() ?? 0,
        modes: ((j['modes'] ?? const ['2p', '4p']) as List).map((e) => '$e').toList(),
        team: j['team'] as bool? ?? false,
        badge: j['badge'] as String?,
        description: j['description'] as String?,
        affordable: j['affordable'] as bool? ?? true,
      );

  BoardTier copyWith({bool? affordable}) => BoardTier(
        key: key, name: name, stake: stake, order: order, modes: modes,
        team: team, badge: badge, description: description,
        affordable: affordable ?? this.affordable,
      );

  /// The canonical six staked tiers (mirrors backend config/economy.php).
  static const List<BoardTier> fallback = [
    BoardTier(key: 'classic', name: 'Classic Arena', stake: 200, order: 1, badge: 'Starter', description: 'Where every legend begins.'),
    BoardTier(key: 'bronze', name: 'Bronze Bazaar', stake: 500, order: 2, badge: 'Bronze', description: 'Warm up your wallet.'),
    BoardTier(key: 'silver', name: 'Silver Summit', stake: 1000, order: 3, badge: 'Silver', description: 'Sharper play, bigger pots.'),
    BoardTier(key: 'gold', name: 'Golden Colosseum', stake: 5000, order: 4, badge: 'Gold', description: 'For seasoned challengers.'),
    BoardTier(key: 'emerald', name: 'Emerald Empire', stake: 10000, order: 5, badge: 'Emerald', description: 'High rollers only.'),
    BoardTier(key: 'diamond', name: 'Diamond Throne', stake: 20000, order: 6, badge: 'Diamond', description: 'The ultimate table.'),
  ];
}

class BoardsSnapshot {
  const BoardsSnapshot({required this.coins, required this.tiers});

  final int coins;
  final List<BoardTier> tiers;

  factory BoardsSnapshot.fromJson(Map<String, dynamic> j) {
    final list = (j['tiers'] ?? const []) as List;
    return BoardsSnapshot(
      coins: (j['coins'] as num?)?.toInt() ?? 0,
      tiers: list
          .whereType<Map>()
          .map((e) => BoardTier.fromJson(e.cast<String, dynamic>()))
          .toList(),
    );
  }

  /// Offline snapshot: all six boards, affordability computed from [coins].
  factory BoardsSnapshot.fallback(int coins) => BoardsSnapshot(
        coins: coins,
        tiers: BoardTier.fallback
            .map((t) => t.copyWith(affordable: coins >= t.stake))
            .toList(),
      );
}
