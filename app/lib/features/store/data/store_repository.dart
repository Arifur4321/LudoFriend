import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/di/providers.dart';
import '../../../core/network/api_endpoints.dart';
import '../../../core/network/api_result.dart';
import '../../../core/network/dio_client.dart';
import 'store_models.dart';

class StoreRepository {
  StoreRepository(this._dio);
  final Dio _dio;

  Future<Result<List<CoinPack>>> packs() async {
    try {
      final res = await _dio.get(ApiEndpoints.storePacks);
      final list = (res.data is Map && res.data['packs'] is List)
          ? res.data['packs'] as List
          : const [];
      final packs = list
          .whereType<Map>()
          .map((e) => CoinPack.fromJson(e.cast<String, dynamic>()))
          .toList();
      return Ok(packs);
    } catch (e) {
      return Err(DioClient.mapError(e));
    }
  }

  Future<Result<PurchaseOutcome>> purchase({
    required String productId,
    required String platform,
    String? receipt,
  }) async {
    try {
      final res = await _dio.post(ApiEndpoints.storePurchase, data: {
        'product_id': productId,
        'platform': platform,
        if (receipt != null) 'receipt': receipt,
      });
      final map = res.data is Map<String, dynamic>
          ? res.data as Map<String, dynamic>
          : <String, dynamic>{};
      return Ok(PurchaseOutcome.fromJson(map));
    } catch (e) {
      return Err(DioClient.mapError(e));
    }
  }
}

final storeRepositoryProvider =
    Provider<StoreRepository>((ref) => StoreRepository(ref.watch(dioProvider)));
