import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/failures.dart';
import '../../../core/network/api_result.dart';
import '../../../services/iap/iap_service.dart';
import '../../wallet/application/wallet_controller.dart';
import '../data/store_models.dart';
import '../data/store_repository.dart';

/// Loads coin packs and performs purchases. The native store SDK (receipt) is
/// used when [IapService] is enabled; otherwise the backend records the intent
/// (credited in dev/testing, held pending in production until verification).
class StoreController extends AsyncNotifier<List<CoinPack>> {
  @override
  Future<List<CoinPack>> build() => _fetch();

  Future<List<CoinPack>> _fetch() async {
    final res = await ref.read(storeRepositoryProvider).packs();
    return res.when(ok: (p) => p, err: (f) => throw f);
  }

  Future<Result<PurchaseOutcome>> buy(CoinPack pack) async {
    // Obtain a store receipt if native IAP is enabled (stub returns none).
    String? receipt;
    final iap = ref.read(iapServiceProvider);
    if (iap.enabled) {
      final ok = await iap.buy(pack.productId);
      if (!ok) {
        // User cancelled or store unavailable — surface as a failure.
        return const Err(ServerFailure('Purchase cancelled.'));
      }
      receipt = null; // a real integration would return the platform receipt here
    }

    final res = await ref.read(storeRepositoryProvider).purchase(
          productId: pack.productId,
          platform: _platform,
          receipt: receipt,
        );

    res.when(
      ok: (o) => ref.read(walletControllerProvider.notifier).setCoins(o.coins),
      err: (_) {},
    );
    return res;
  }

  String get _platform {
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return 'android';
      case TargetPlatform.iOS:
        return 'ios';
      default:
        return 'web';
    }
  }
}

final storeControllerProvider =
    AsyncNotifierProvider<StoreController, List<CoinPack>>(StoreController.new);
