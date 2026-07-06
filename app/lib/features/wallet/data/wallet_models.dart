/// A single coin-ledger entry as returned by the API.
class WalletTx {
  const WalletTx({
    required this.id,
    required this.type,
    required this.amount,
    required this.balanceAfter,
    this.description,
    this.createdAt,
  });

  final int id;
  final String type;
  final int amount; // signed: negative = debit
  final int balanceAfter;
  final String? description;
  final DateTime? createdAt;

  bool get isCredit => amount >= 0;

  factory WalletTx.fromJson(Map<String, dynamic> j) => WalletTx(
        id: (j['id'] as num?)?.toInt() ?? 0,
        type: j['type'] as String? ?? 'adjustment',
        amount: (j['amount'] as num?)?.toInt() ?? 0,
        balanceAfter: (j['balance_after'] as num?)?.toInt() ?? 0,
        description: j['description'] as String?,
        createdAt: j['created_at'] != null
            ? DateTime.tryParse('${j['created_at']}')
            : null,
      );
}

/// Balance + recent ledger rows.
class WalletSnapshot {
  const WalletSnapshot({required this.coins, this.recent = const []});

  final int coins;
  final List<WalletTx> recent;

  WalletSnapshot copyWith({int? coins, List<WalletTx>? recent}) =>
      WalletSnapshot(coins: coins ?? this.coins, recent: recent ?? this.recent);

  factory WalletSnapshot.fromJson(Map<String, dynamic> j) {
    final rows = (j['recent'] ?? j['transactions'] ?? const []) as List;
    return WalletSnapshot(
      coins: (j['coins'] as num?)?.toInt() ?? 0,
      recent: rows
          .whereType<Map>()
          .map((e) => WalletTx.fromJson(e.cast<String, dynamic>()))
          .toList(),
    );
  }
}
