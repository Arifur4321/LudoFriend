import 'package:flutter_test/flutter_test.dart';
import 'package:ludo_friends/features/boards/data/board_models.dart';
import 'package:ludo_friends/features/spin/data/spin_models.dart';
import 'package:ludo_friends/features/store/data/store_models.dart';
import 'package:ludo_friends/features/wallet/data/wallet_models.dart';

void main() {
  test('WalletSnapshot parses coins and rows', () {
    final snap = WalletSnapshot.fromJson({
      'coins': 700,
      'recent': [
        {'id': 1, 'type': 'prize', 'amount': 400, 'balance_after': 700, 'description': 'Match prize'},
        {'id': 2, 'type': 'stake', 'amount': -200, 'balance_after': 300},
      ],
    });
    expect(snap.coins, 700);
    expect(snap.recent.length, 2);
    expect(snap.recent.first.isCredit, isTrue);
    expect(snap.recent[1].isCredit, isFalse);
  });

  test('SpinStatus extracts wheel rewards from segments', () {
    final s = SpinStatus.fromJson({
      'enabled': true,
      'can_spin': true,
      'segments': [
        {'reward': 500, 'weight': 300},
        {'reward': 20000, 'weight': 5},
      ],
    });
    expect(s.rewards, [500, 20000]);
    expect(s.canSpin, isTrue);
  });

  test('SpinResult parses reward + segment + balance', () {
    final r = SpinResult.fromJson({'reward': 1000, 'segment_index': 2, 'balance': 1500});
    expect(r.reward, 1000);
    expect(r.segmentIndex, 2);
    expect(r.balance, 1500);
  });

  test('BoardsSnapshot.fallback marks affordability from balance', () {
    final snap = BoardsSnapshot.fallback(300);
    final byKey = {for (final t in snap.tiers) t.key: t};
    expect(byKey['classic']!.affordable, isTrue); // 300 >= 200
    expect(byKey['bronze']!.affordable, isFalse); // 300 < 500
    expect(snap.tiers.length, 6);
    // Ordered ascending by stake.
    expect(snap.tiers.first.key, 'classic');
    expect(snap.tiers.last.key, 'diamond');
  });

  test('CoinPack computes total coins with bonus', () {
    final p = CoinPack.fromJson({
      'product_id': 'com.ludofriends.coins.chest',
      'coins': 80000,
      'bonus': 12000,
      'price': '9.99',
      'popular': true,
    });
    expect(p.totalCoins, 92000);
    expect(p.popular, isTrue);
  });
}
