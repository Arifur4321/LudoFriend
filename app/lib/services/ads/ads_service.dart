import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/config/app_config.dart';

/// Ads integration hook — **disabled by default**.
///
/// This is a placeholder so monetization can be added later (e.g. AdMob)
/// without touching game code. Rewarded ads are opt-in and must never affect
/// fairness (no pay-to-win).
class AdsService {
  AdsService({required this.enabled});

  final bool enabled;

  Future<void> init() async {
    // No-op until an ad network is wired up.
  }

  /// Returns true if a reward should be granted. Always false while disabled.
  Future<bool> showRewarded() async => false;

  /// Optional banner widget; null while disabled.
  Widget? banner() => null;
}

final adsServiceProvider =
    Provider<AdsService>((ref) => AdsService(enabled: AppConfig.adsEnabled));
