/// A purchasable coin pack (mirrors backend config/economy.php store.packs).
class CoinPack {
  const CoinPack({
    required this.productId,
    required this.coins,
    required this.bonus,
    required this.totalCoins,
    this.label,
    this.price,
    this.popular = false,
    this.bestValue = false,
  });

  final String productId;
  final int coins;
  final int bonus;
  final int totalCoins;
  final String? label;
  final String? price;
  final bool popular;
  final bool bestValue;

  factory CoinPack.fromJson(Map<String, dynamic> j) => CoinPack(
        productId: j['product_id'] as String? ?? '',
        coins: (j['coins'] as num?)?.toInt() ?? 0,
        bonus: (j['bonus'] as num?)?.toInt() ?? 0,
        totalCoins: (j['total_coins'] as num?)?.toInt() ??
            ((j['coins'] as num?)?.toInt() ?? 0) + ((j['bonus'] as num?)?.toInt() ?? 0),
        label: j['label'] as String?,
        price: j['price']?.toString(),
        popular: j['popular'] as bool? ?? false,
        bestValue: j['best_value'] as bool? ?? false,
      );
}

/// Result of a purchase attempt.
class PurchaseOutcome {
  const PurchaseOutcome({
    required this.status,
    required this.coinsAwarded,
    required this.coins,
    required this.pending,
  });

  final String status;
  final int coinsAwarded;
  final int coins;
  final bool pending;

  factory PurchaseOutcome.fromJson(Map<String, dynamic> j) => PurchaseOutcome(
        status: j['status'] as String? ?? 'pending',
        coinsAwarded: (j['coins_awarded'] as num?)?.toInt() ?? 0,
        coins: (j['coins'] as num?)?.toInt() ?? 0,
        pending: j['pending'] as bool? ?? true,
      );
}
