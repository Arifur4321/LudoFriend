import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/config/app_config.dart';

/// A purchasable, cosmetic-only product (no gameplay advantage).
class ShopProduct {
  const ShopProduct({
    required this.id,
    required this.title,
    required this.description,
    required this.price,
  });
  final String id;
  final String title;
  final String description;
  final String price;
}

/// In-app purchase hook — **disabled by default**. Cosmetic items only to keep
/// gameplay fair. Replace with a real `in_app_purchase` implementation later.
class IapService {
  IapService({required this.enabled});
  final bool enabled;

  Future<List<ShopProduct>> products() async => const [];

  Future<bool> buy(String productId) async => false;

  Future<bool> restore() async => false;
}

final iapServiceProvider =
    Provider<IapService>((ref) => IapService(enabled: AppConfig.iapEnabled));
