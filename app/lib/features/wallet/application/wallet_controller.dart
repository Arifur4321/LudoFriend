import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/storage/local_cache.dart';
import '../../auth/application/auth_controller.dart';
import '../data/wallet_models.dart';
import '../data/wallet_repository.dart';

/// Holds the player's wallet. Screens watch [walletControllerProvider] for the
/// balance and refresh it after any coin-moving action (spin, match, purchase).
class WalletController extends AsyncNotifier<WalletSnapshot?> {
  @override
  Future<WalletSnapshot?> build() {
    // Re-fetch whenever the signed-in user changes (login / logout / guest).
    ref.watch(authControllerProvider);
    return _fetch();
  }

  Future<WalletSnapshot?> _fetch() async {
    // Not signed in yet — show an empty wallet instead of erroring on 401.
    final user = ref.read(authControllerProvider).valueOrNull;
    if (user == null) return const WalletSnapshot(coins: 0);

    final res = await ref.read(walletRepositoryProvider).fetch();
    return res.when(
      ok: (s) {
        // Persist last-known balance for an instant cold-start display.
        ref.read(localCacheProvider).cacheCoins(s.coins);
        return s;
      },
      err: (f) => throw f,
    );
  }

  Future<void> refresh() async {
    state = const AsyncLoading<WalletSnapshot?>().copyWithPrevious(state);
    state = await AsyncValue.guard(_fetch);
  }

  /// Optimistically set the balance (e.g. right after a spin/purchase response
  /// already carries the new total), keeping the last known history.
  void setCoins(int coins) {
    final prev = state.valueOrNull;
    state = AsyncData(WalletSnapshot(coins: coins, recent: prev?.recent ?? const []));
    ref.read(localCacheProvider).cacheCoins(coins);
  }
}

final walletControllerProvider =
    AsyncNotifierProvider<WalletController, WalletSnapshot?>(WalletController.new);

/// Convenience: current coin balance. Falls back to the last-known cached value
/// while the network request is in flight, so the chip is never blank on launch.
final coinsProvider = Provider<int>((ref) =>
    ref.watch(walletControllerProvider).valueOrNull?.coins ??
    ref.read(localCacheProvider).cachedCoins ??
    0);
