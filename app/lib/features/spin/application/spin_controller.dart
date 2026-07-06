import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_result.dart';
import '../../../core/storage/local_cache.dart';
import '../../wallet/application/wallet_controller.dart';
import '../data/spin_models.dart';
import '../data/spin_repository.dart';

/// Loads spin availability and performs the spin. On success it pushes the new
/// balance into the wallet so the whole app reflects the reward immediately.
class SpinController extends AsyncNotifier<SpinStatus?> {
  @override
  Future<SpinStatus?> build() => _fetch();

  Future<SpinStatus?> _fetch() async {
    final res = await ref.read(spinRepositoryProvider).status();
    return res.when(
      ok: (s) {
        // Persist the unlock time for an instant offline countdown.
        ref.read(localCacheProvider).setNextFreeSpinAt(s.nextAvailableAt);
        return s;
      },
      err: (f) => throw f,
    );
  }

  Future<void> refresh() async {
    state = await AsyncValue.guard(_fetch);
  }

  /// Returns the spin outcome (so the screen can animate to the segment), or a
  /// failure message. Updates wallet + status on success.
  Future<Result<SpinResult>> spin() async {
    final res = await ref.read(spinRepositoryProvider).spin();
    res.when(
      ok: (r) {
        ref.read(walletControllerProvider.notifier).setCoins(r.balance);
        final nextAt = r.nextAvailableAt ??
            DateTime.now().add(Duration(
                minutes: state.valueOrNull?.intervalMinutes ?? 60));
        ref.read(localCacheProvider).setNextFreeSpinAt(nextAt);
        final prev = state.valueOrNull;
        if (prev != null) {
          state = AsyncData(prev.copyWith(
            canSpin: false,
            lastReward: r.reward,
            nextAvailableAt: nextAt,
          ));
        }
      },
      err: (_) {},
    );
    return res;
  }
}

final spinControllerProvider =
    AsyncNotifierProvider<SpinController, SpinStatus?>(SpinController.new);
